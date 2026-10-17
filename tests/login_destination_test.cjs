// Run the shipped login handlers offline; no credentials or network requests.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.join(__dirname, '..');
const bundlePath = fs.readFileSync(path.join(root, 'index.html'), 'utf8').match(/src="\/(assets\/index-[^"?]+\.js)/)[1];
const bundle = fs.readFileSync(path.join(root, bundlePath), 'utf8');
const runtime = fs.readFileSync(path.join(root, 'storefront-runtime.js'), 'utf8');

function between(source, start, end) {
  const at = source.indexOf(start);
  assert.notEqual(at, -1, `Missing handler start: ${start}`);
  const stop = source.indexOf(end, at + start.length);
  assert.notEqual(stop, -1, `Missing handler end: ${end}`);
  return source.slice(at + start.length, stop);
}
function component(name) {
  const at = bundle.lastIndexOf(`function ${name}(){`);
  assert.notEqual(at, -1);
  return bundle.slice(at, bundle.indexOf('function ', at + 10));
}
const emailHandler = between(component('Kc'), 'onSubmit:', ',className:');
const otpHandler = between(component('Xc'), 'let h=', ',g=(e,t)=>');
const googleHandler = between(component('Qc'), '(async()=>{', '})()},[])');

async function checkLogin(role, kind) {
  const user = { name: 'Test User', role, is_admin: role !== 'student' };
  const nav = [], saved = [];
  const login = (token, profile) => saved.push({token, profile});
  const navigate = url => nav.push(url);
  const response = async () => ({data: {token: 'test-token', user}});
  const context = {
    e: navigate, t: login, n: login, a() {}, s() {}, i() {}, c: {}, m: 'test@example.invalid',
    ys: response, vs: response, ws: response,
    j: {success() {}, error(message) {throw Error(message);}}, Mc: String, Yc: String,
    window: {location: {replace: navigate}},
    localStorage: {setItem() {}, removeItem() {}},
  };
  if (kind === 'email') await vm.runInNewContext(`(${emailHandler})`, context)({preventDefault() {}});
  if (kind === 'otp') await vm.runInNewContext(`(${otpHandler})`, {...context, c() {}})('123456');
  if (kind.startsWith('google')) {
    context.n = new URLSearchParams({token: 'test-token', user: 'encoded-profile'});
    context.Zc = () => kind === 'google-profile' ? user : null;
    await vm.runInNewContext(`(async()=>{${googleHandler}})()`, context);
  }
  assert.deepEqual(nav, ['/dashboard'], `${role}: ${kind}`);
  assert.equal(saved.length, 1);
  assert.equal(saved[0].profile, user, 'Login must preserve the original role and user');
}

async function checkHandoff(role) {
  const user = {role, is_admin: role !== 'student'};
  const storage = new Map([['ql_google_handoff', JSON.stringify({id:'test-handoff', at:Date.now()})]]);
  const nav = [];
  vm.runInNewContext(runtime, {
    window: {addEventListener() {}}, navigator: {}, document: {addEventListener() {}},
    localStorage: {getItem:k=>storage.get(k), setItem:(k,v)=>storage.set(k,v), removeItem:k=>storage.delete(k)},
    sessionStorage: {getItem:()=>null},
    location: {pathname:'/login', replace:url=>nav.push(url)},
    setInterval() {}, clearInterval() {},
    fetch: async () => ({status:200, json:async()=>({token:'test-token', user})}),
  });
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(nav, ['/dashboard'], `${role}: app handoff`);
  assert.equal(JSON.parse(storage.get('lab_user')).role, role);
  assert.equal(storage.has('ql_google_handoff'), false);
}

(async () => {
  for (const role of ['student', 'admin', 'manager']) {
    for (const kind of ['email', 'otp', 'google-profile', 'google-fetch']) await checkLogin(role, kind);
    await checkHandoff(role);
  }
  const landing = fs.readFileSync(path.join(root, 'landing.html'), 'utf8');
  const destination = between(landing, 'var dest=', ';');
  for (const role of ['student', 'admin', 'manager']) {
    assert.equal(vm.runInNewContext(destination, {u:{role, is_admin:role !== 'student'}}), '/dashboard');
  }
  console.log('PASS: all 15 login paths and three landing Dashboard links open /dashboard; roles preserved.');
})().catch(error => {console.error(error); process.exitCode = 1;});
