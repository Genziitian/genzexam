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
    localStorage: { getItem: k => k === 'lab_token' ? token : null },
    navigator: {},
    document: { addEventListener() {} },
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

app = run();
app.api.signIn(42, true);
assert.equal(JSON.parse(app.storage.get('ql_storefront_return')).open, true);
app = run({pathname:'/dashboard', token:'mock', pending:{paperId:42, open:true, at:Date.now()}});
assert.deepEqual(app.navigations, ['/paper/42']);
app = run({pathname:'/dashboard', token:'mock', pending:{paperId:'x', open:true, at:Date.now()}});
assert.deepEqual(app.navigations, ['/papers?library=1']);

for (const filename of ['papers.js','paper-pricing.js','storefront-runtime.js','app-enhancements.js']) {
  new vm.Script(fs.readFileSync(path.join(__dirname, '..', filename), 'utf8'), {filename});
}

// Pro icon switching test
{
  const links = {
    'link[rel="icon"][sizes="32x32"]': { href: '/favicon-32x32.png' },
    'link[rel="icon"][sizes="16x16"]': { href: '/favicon-16x16.png' },
    'link[rel="apple-touch-icon"]': { href: '/apple-touch-icon.png' },
    'link[rel="manifest"]': { href: '/site.webmanifest' },
  };
  const ctx = {
    window: { addEventListener() {} },
    localStorage: { getItem: k => k === 'lab_user' ? JSON.stringify({ is_pro: true }) : null },
    navigator: {},
    document: {
      addEventListener() {},
      querySelector: sel => links[sel] || null,
    },
    sessionStorage: { getItem: () => null, setItem() {}, removeItem() {} },
    location: { pathname: '/' },
    setInterval: () => 1, clearInterval() {},
  };
  vm.runInNewContext(source, ctx);
  assert.equal(links['link[rel="icon"][sizes="32x32"]'].href, '/favicon-pro-32x32.png');
  assert.equal(links['link[rel="manifest"]'].href, '/site-pro.webmanifest');
  assert.equal(links['link[rel="apple-touch-icon"]'].href, '/apple-touch-icon-pro.png');
}
console.log('PASS: nine sign-in/resume cases and syntax checks for four storefront integration scripts.');
