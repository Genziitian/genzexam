const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../ql-loading.js'), 'utf8');
function deferred() { let resolve, reject; const promise = new Promise((a,b)=>{resolve=a;reject=b;}); return {promise,resolve,reject}; }
function setup() {
  const nodes = new Map(), timers = new Map(), queue = []; let now=0, serial=0;
  class Node {
    constructor() { this.hidden=false; this.open=false; this.parts=new Map(); this.listeners={}; this.isConnected=true; }
    setAttribute(k,v) { this[k]=v; }
    addEventListener(k,fn) { this.listeners[k]=fn; }
    appendChild(child) { if(child.id) nodes.set(child.id,child); }
    querySelector(selector) { if(!this.parts.has(selector))this.parts.set(selector,new Node());return this.parts.get(selector); }
    showModal() { this.open=true; }
    close() { this.open=false; }
    focus() {}
  }
  class XHR {
    constructor() { this.listeners={}; }
    open(method,url) { this.method=method;this.url=url; }
    send(body) { this.body=body; }
    addEventListener(name,fn) { this.listeners[name]=fn; }
    complete() { this.listeners.loadend?.(); }
  }
  const document={body:new Node(),head:new Node(),activeElement:new Node(),createElement:()=>new Node(),getElementById:id=>nodes.get(id),addEventListener(){}};
  const context={document,URL,Map,WeakMap,Promise,Array,Object,String,XMLHttpRequest:XHR,
    location:{href:'https://quiz.genziitian.in/profile',origin:'https://quiz.genziitian.in'},
    setTimeout(fn,ms){const id=++serial;timers.set(id,{fn,at:now+ms});return id;},clearTimeout:id=>timers.delete(id),
    addEventListener(){},fetch(...args){const d=deferred();queue.push({...d,args});return d.promise;},
  };
  context.window=context;
  vm.runInNewContext(source,context);
  function tick(ms) { now+=ms;for(const [id,t] of [...timers])if(t.at<=now){timers.delete(id);t.fn();} }
  return {context,queue,tick,nodes,modal:()=>nodes.get('ql-loading-modal'),activity:()=>nodes.get('ql-loading-activity')};
}
const jsonResponse = () => ({json:async()=>({ok:true}),status:200});
(async()=>{
  let app=setup(),url='https://labapi.genziitian.in/public/api/student/profile';
  let request=app.context.fetch(url);
  app.tick(200);assert.equal(app.activity().hidden,false);assert.equal(app.modal().open,false);
  app.queue[0].resolve(jsonResponse());await (await request).json();assert.equal(app.activity().hidden,true);

  app=setup();const data={method:'PATCH',body:'original body',headers:{'Content-Type':'application/json'}};
  request=app.context.fetch(url,data);app.tick(200);assert.equal(app.modal().open,true);
  assert.equal(app.queue[0].args[1],data,'request options must pass through unchanged');
  const body=deferred();app.queue[0].resolve({json:()=>body.promise});const response=await request;const reading=response.json();
  app.tick(1);assert.equal(app.modal().open,true,'wait through body decoding');
  body.resolve({saved:true});assert.deepEqual(await reading,{saved:true});assert.equal(app.modal().open,false);

  app=setup();let endA=app.context.QLLoading.begin('First'),endB=app.context.QLLoading.begin('Second');
  app.tick(200);endB();assert.equal(app.modal().open,true);endB();endA();assert.equal(app.modal().open,false);
  const failed=app.context.QLLoading.run('Saving',async()=>{throw Error('failed');});
  await assert.rejects(failed,/failed/);app.tick(200);assert.equal(app.modal().open,false);

  app=setup();request=app.context.fetch(url,{method:'POST'});const failure=assert.rejects(request,/offline/);
  app.tick(200);app.queue[0].reject(Error('offline'));await failure;assert.equal(app.modal().open,false);
  let xhr=new app.context.XMLHttpRequest();xhr.open('DELETE',url);xhr.send();app.tick(200);assert.equal(app.modal().open,true);
  xhr.complete();assert.equal(app.modal().open,false,'XHR abort/error/loadend must release feedback');

  app=setup();request=app.context.fetch('https://labapi.genziitian.in/public/api/exam-platform/exams/1/answers',{method:'PATCH'});
  app.tick(200);assert.equal(app.modal().open,false);assert.equal(app.activity().hidden,false);
  app.queue[0].resolve(jsonResponse());await (await request).json();
  const finish=app.context.QLLoading.begin('Long task');app.tick(13000);
  assert.match(app.modal().querySelector('p').textContent,/longer/);
  app.modal().querySelector('button').listeners.click();assert.equal(app.modal().open,false);assert.equal(app.activity().hidden,false);
  finish();assert.equal(app.activity().hidden,true);

  assert.equal(app.context.QLLoading.requestDetails('https://labapi.genziitian.in/public/api/student/spin-practice','POST').blocking,false,'The wheel owns its progress feedback; a modal must not cover it');
  app=setup();const quick=app.context.QLLoading.begin('Quick');quick();app.tick(200);assert.equal(app.modal(),undefined);
  for(const file of fs.readdirSync(path.join(__dirname,'..')).filter(f=>f.endsWith('.html'))){
    assert.match(fs.readFileSync(path.join(__dirname,'..',file),'utf8'),/ql-loading\.js/,'Missing loading feedback: '+file);
  }
  console.log('PASS: fetch/XHR lifecycle, body decoding, concurrency, failures, autosave, long waits, fast requests and all HTML entry points.');
})().catch(error=>{console.error(error);process.exitCode=1;});
