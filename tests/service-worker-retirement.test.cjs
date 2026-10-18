'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const worker = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
const runtime = fs.readFileSync(path.join(root, 'storefront-runtime.js'), 'utf8');

async function lifecycle(claimFails = false) {
  const events = {}, calls = [];
  vm.runInNewContext(worker, { self: {
    addEventListener: (name, fn) => { events[name] = fn; },
    skipWaiting: async () => { calls.push('skip'); },
    clients: { claim: async () => { calls.push('claim'); if (claimFails) throw Error('Unavailable'); } },
    registration: { unregister: async () => { calls.push('unregister'); return true; } },
  } });
  assert.equal(events.fetch, undefined, 'Existing installs must stop intercepting navigation, assets, API calls and writes');
  let pending;
  events.install({ waitUntil(promise) { pending = promise; } });
  await pending;
  events.activate({ waitUntil(promise) { pending = promise; } });
  await pending;
  assert.deepEqual(calls, ['skip', 'claim', 'unregister']);
}

async function page({ script = 'https://quiz.genziitian.in/sw.js?v=2', standalone = false, updateFails = false, lookupFails = false, noRegistration = false } = {}) {
  const calls = [];
  const saved = new Map([['lab_token', 'existing-session'], ['lab_user', '{"name":"Existing user"}']]);
  const registration = {
    active: { scriptURL: script },
    update: async () => { calls.push('update'); if (updateFails) throw Error('Network unavailable'); },
    unregister: async () => { calls.push('unregister'); return true; },
  };
  const context = {
    URL, window: { addEventListener() {} },
    navigator: { standalone, serviceWorker: {
      register() { calls.push('register'); throw Error('Must not reinstall the guard'); },
      getRegistration: async scope => {
        calls.push('lookup:'+scope);
        if (lookupFails) throw Error('Storage unavailable');
        return noRegistration ? undefined : registration;
      },
    } },
    document: { addEventListener() {}, querySelector() { return null; } },
    location: { pathname: '/dashboard', origin: 'https://quiz.genziitian.in', protocol: 'https:', replace() { calls.push('navigate'); } },
    localStorage: { getItem: key => saved.get(key), setItem: (key, value) => saved.set(key, value), removeItem: key => saved.delete(key) },
    sessionStorage: { getItem() { return null; } },
    setInterval() {}, clearInterval() {},
    fetch() { throw Error('No pending sign-in: migration must not make API requests'); },
  };
  vm.runInNewContext(runtime, context);
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(typeof context.window.QLStorefront.signIn, 'function', 'Existing page setup survives migration failures');
  assert.equal(saved.get('lab_token'), 'existing-session');
  assert.equal(saved.get('lab_user'), '{"name":"Existing user"}');
  assert.equal(calls.includes('navigate'), false, 'Do not reload an open exam or page');
  assert.equal(calls.includes('register'), false);
  return calls;
}

(async () => {
  await lifecycle();
  await lifecycle(true);
  for (const standalone of [false, true]) {
    assert.deepEqual(await page({ standalone }), ['lookup:/', 'update']);
    assert.deepEqual(await page({ standalone, updateFails: true }), ['lookup:/', 'update', 'unregister']);
  }
  for (const script of ['https://quiz.genziitian.in/push/sw.js', 'https://other.invalid/sw.js']) {
    assert.deepEqual(await page({ script }), ['lookup:/'], 'Do not update or remove unrelated workers');
  }
  assert.deepEqual(await page({ noRegistration: true }), ['lookup:/']);
  assert.deepEqual(await page({ lookupFails: true }), ['lookup:/']);
  let entries = 0;
  for (const name of fs.readdirSync(root).filter(name => name.endsWith('.html'))) {
    const html = fs.readFileSync(path.join(root, name), 'utf8');
    if (!html.includes('/storefront-runtime.js?v=')) continue;
    entries++;
    assert.ok(html.includes('/storefront-runtime.js?v=20261018swfix'), name+' must request the updated runtime');
  }
  assert.ok(entries >= 12);
  console.log('PASS: 10 migration/lifecycle cases; session preservation, no forced navigation, no new guard registration, and '+entries+' updated entry points.');
})().catch(error => { console.error(error); process.exitCode = 1; });
