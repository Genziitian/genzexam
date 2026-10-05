// Offline checks: no browser, API requests, credentials or real payments.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname, '../storefront-runtime.js'), 'utf8');
function run({ pathname = '/papers', token = '', pending = null } = {}) {
  const storage = new Map(pending ? [['ql_storefront_return', JSON.stringify(pending)]] : []);
  const navigations = [];
  const context = {
    window: { addEventListener() {} },
    localStorage: { getItem: () => token },
    sessionStorage: { getItem: k => storage.get(k), setItem: (k,v) => storage.set(k,v), removeItem: k => storage.delete(k) },
    location: { pathname, assign: url => navigations.push(url), replace: url => navigations.push(url) },
    setInterval: () => 1, clearInterval() {},
  };
  vm.runInNewContext(source, context);
  return { api: context.window.QLStorefront, storage, navigations };
}
let app = run();
app.api.signIn(42);
assert.deepEqual(app.navigations, ['/login']);
assert.equal(JSON.parse(app.storage.get('ql_storefront_return')).paperId, 42);

app = run({pathname:'/dashboard', token:'mock', pending:{paperId:42, at:Date.now()}});
assert.deepEqual(app.navigations, ['/papers?paper=42']);
assert.equal(app.storage.has('ql_storefront_return'), false);

app = run({pathname:'/dashboard', pending:{paperId:42, at:Date.now()}});
assert.deepEqual(app.navigations, []);
assert.equal(app.storage.has('ql_storefront_return'), true);

app = run({pathname:'/login', token:'mock', pending:{paperId:42, at:Date.now()}});
assert.deepEqual(app.navigations, []);

app = run({pathname:'/dashboard', token:'mock', pending:{paperId:42, at:Date.now()-31*60*1000}});
assert.deepEqual(app.navigations, []);
assert.equal(app.storage.has('ql_storefront_return'), false);

app = run({pathname:'/dashboard', token:'mock', pending:{paperId:'https://attacker.invalid', at:Date.now()}});
assert.deepEqual(app.navigations, ['/papers?library=1']);

for (const filename of ['papers.js','paper-pricing.js','storefront-runtime.js','app-enhancements.js']) {
  new vm.Script(fs.readFileSync(path.join(__dirname, '..', filename), 'utf8'), {filename});
}
console.log('PASS: six sign-in/resume cases and syntax checks for four storefront integration scripts.');
