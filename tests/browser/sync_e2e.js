// Real-browser cross-device sync e2e for the Super Productivity Railway template.
//
//   APP_URL=https://<domain> OWNER_PASSWORD_FILE=/path/to/pw node tests/browser/sync_e2e.js
//
// Device A (fresh browser profile): passes the front door, creates a task, enables WebDAV sync to
// <APP_URL>/webdav/ with the owner credential and syncs. Device B (another fresh profile): sets up
// the same sync and must receive the task. The password is read from a file and never printed.
'use strict';
const fs = require('fs');
const { chromium } = require('playwright');

const APP_URL = (process.env.APP_URL || 'http://127.0.0.1:18190').replace(/\/$/, '');
const USER = process.env.OWNER_USERNAME || 'owner';
const PASSWORD = process.env.OWNER_PASSWORD_FILE
  ? fs.readFileSync(process.env.OWNER_PASSWORD_FILE, 'utf8').trim()
  : process.env.SP_TEST_OWNER_PASSWORD || 'localTestOnlyOwnerPw1';
const FOLDER = process.env.SYNC_FOLDER || `e2e-${Date.now()}`;
const TASK = process.env.TASK_TITLE || `Railway sync check ${Date.now()}`;
const SHOTS = process.env.SHOT_DIR || '';

let failed = 0;
const pass = (m) => console.log(`  PASS  ${m}`);
const fail = (m) => { failed++; console.log(`  FAIL  ${m}`); };

async function newDevice(browser) {
  const ctx = await browser.newContext({
    httpCredentials: { username: USER, password: PASSWORD },
    viewport: { width: 1400, height: 900 },
  });
  const page = await ctx.newPage();
  await page.goto(`${APP_URL}/`, { waitUntil: 'networkidle' });
  return { ctx, page };
}

async function configureWebDav(page) {
  const dlg = page.locator('mat-dialog-container');
  await dlg.locator('mat-select').first().click();
  await page.getByRole('option', { name: /WebDAV/ }).click();
  await dlg.locator('input[id*="baseUrl"]').waitFor();
  await page.waitForTimeout(500);
  await dlg.locator('input[id*="baseUrl"]').fill(`${APP_URL}/webdav/`);
  await dlg.locator('input[id*="userName"]').fill(USER);
  await dlg.locator('input[id*="password"]').fill(PASSWORD);
  await dlg.locator('input[id*="syncFolderPath"]').fill(FOLDER);
  await dlg.getByRole('button', { name: /Save & Enable Sync/ }).click();
  // Optional end-to-end encryption prompt: skip it so the server-side check can read the data.
  const skip = page.getByRole('button', { name: /^Skip$/ });
  try { await skip.waitFor({ timeout: 8000 }); await skip.click(); } catch { /* not shown */ }
}

async function waitForSyncFile(page) {
  const auth = 'Basic ' + Buffer.from(`${USER}:${PASSWORD}`).toString('base64');
  for (let i = 0; i < 30; i++) {
    const r = await fetch(`${APP_URL}/webdav/${FOLDER}/sync-data.json`, { headers: { Authorization: auth } });
    if (r.status === 200 && (await r.text()).includes(TASK)) return true;
    await page.waitForTimeout(2000);
  }
  return false;
}

async function shot(page, name) { if (SHOTS) await page.screenshot({ path: `${SHOTS}/${name}.png` }); }

(async () => {
  const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : {});
  try {
    console.log('\n== device A: create a task and sync it up ==');
    const a = await newDevice(browser);
    await a.page.getByText('Simple Todo List').click();
    await a.page.waitForTimeout(1500);
    await a.page.keyboard.press('Shift+A');
    const input = a.page.locator('add-task-bar textarea, add-task-bar input').first();
    await input.waitFor({ timeout: 15000 });
    await input.fill(TASK);
    await input.press('Enter');
    await a.page.waitForTimeout(800);
    await a.page.keyboard.press('Escape');
    await a.page.waitForTimeout(800);
    await shot(a.page, 'a1');
    (await a.page.innerText('body')).includes(TASK) ? pass('task created in the web app') : fail('task not visible after creating it');
    await a.page.locator('button:has(mat-icon:text-is("sync_disabled"))').first().click();
    await a.page.locator('mat-dialog-container').waitFor();
    await configureWebDav(a.page);
    await waitForSyncFile(a.page);
    await shot(a.page, 'a2');

    console.log('\n== server side: the sync file is on the WebDAV store ==');
    const auth = 'Basic ' + Buffer.from(`${USER}:${PASSWORD}`).toString('base64');
    const res = await fetch(`${APP_URL}/webdav/${FOLDER}/sync-data.json`, { headers: { Authorization: auth } });
    res.status === 200 ? pass('sync-data.json exists in the WebDAV folder') : fail(`sync-data.json GET -> ${res.status}`);
    (await res.text()).includes(TASK) ? pass('the uploaded sync data contains the task') : fail('task missing from sync data');
    const anon = await fetch(`${APP_URL}/webdav/${FOLDER}/sync-data.json`);
    anon.status === 401 ? pass('the sync data is not readable without credentials') : fail(`anonymous GET -> ${anon.status}`);
    await a.ctx.close();

    console.log('\n== device B: a fresh browser downloads the task ==');
    const b = await newDevice(browser);
    await b.page.getByRole('button', { name: 'Set up sync' }).click();
    await b.page.locator('mat-dialog-container').waitFor();
    await configureWebDav(b.page);
    let seen = false;
    for (let i = 0; i < 30 && !seen; i++) {
      await b.page.waitForTimeout(2000);
      // Dismiss any leftover onboarding so the task list is visible.
      const todo = b.page.getByText('Simple Todo List');
      if (await todo.isVisible().catch(() => false)) await todo.click().catch(() => {});
      seen = (await b.page.innerText('body')).includes(TASK);
    }
    await shot(b.page, 'b1');
    seen ? pass('device B received the task through WebDAV sync') : fail('device B never showed the synced task');
    await b.ctx.close();
  } finally {
    await browser.close();
  }
  console.log(`\n${failed ? 'FAILED' : 'OK'}`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
