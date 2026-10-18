'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const bundle = fs.readFileSync(path.join(root, 'assets/index-fad00dd6r.js'), 'utf8');
const component = bundle.slice(bundle.indexOf('function Nl(){'), bundle.indexOf('var Pl=', bundle.indexOf('function Nl(){')));
const flush = async () => { for (let i=0; i<12; i++) await Promise.resolve(); };
const dashboard = {streak:{days:4},accuracy:{value:75},rank:{current:12}};
function mount(responders) {
  const values=[],effects=[],counts=[0,0,0,0]; let cursor=0,changed=0;
  const jsx=(type,props)=>({type,props});
  const context={Promise,Map,Date,Boolean,Error,Ms:()=>({user:{name:'Fixture'}}),F:{jsx,jsxs:jsx},v:{
    useState(value){ const index=cursor++; if(!(index in values))values[index]=value; return [values[index],next=>{changed++;values[index]=typeof next==='function'?next(values[index]):next;}]; },
    useEffect(effect){effects.push(effect);},useMemo(fn){return fn();}
  }};
  ['Sl','Cl','Tl','El','Dl','Al','jl','Ml','pl'].forEach(name=>context[name]=name);
  context.P={get:async(route,options)=>{const index=['/student/dashboard','/courses','/student/progress','/leaderboard'].indexOf(route);assert.equal(options.timeout,15000);counts[index]++;return {data:await responders[index]()};}};
  vm.createContext(context);vm.runInContext(component+';this.renderDashboard=Nl;',context);
  return {values,counts,render(){cursor=0;return context.renderDashboard();},start(){return effects.shift()();},get changed(){return changed;}};
}
function nodes(tree,predicate) {
  if(!tree||typeof tree!=='object')return [];
  let found=predicate(tree)?[tree]:[];
  const children=tree.props?.children;
  for(const child of Array.isArray(children)?children:[children])found.push(...nodes(child,predicate));
  return found;
}
(async()=>{
  let coursesFail=true;
  const app=mount([()=>dashboard,()=>{if(coursesFail)throw Error('Load failed');return [{id:3}];},()=>({course_progress:[]}),()=>{throw Error('Optional leaderboard failure');}]);
  app.render();app.start();await flush();
  assert.equal(app.values[1],dashboard,'Course or progress failures must not discard confirmed dashboard statistics');
  assert.deepEqual(Array.from(app.values[5]),['Courses']);
  let view=app.render();
  assert.equal(nodes(view,n=>n.type==='Tl').length,1);
  assert.equal(nodes(view,n=>n.type==='Al').length,0,'A failed courses request must not look like no courses are available');
  let retry=nodes(view,n=>n.type==='button'&&n.props.children==='Try again')[0];
  assert.ok(retry,'A failed section needs an in-page retry');
  coursesFail=false;retry.props.onClick();app.start();await flush();
  assert.equal(app.values[5].length,0);assert.equal(app.values[2][0].id,3);

  const failed=()=>{throw Error('Network error');};
  const disconnected=mount([failed,()=>[{id:8}],()=>({course_progress:[]}),()=>({leaderboard:[]})]);
  disconnected.render();disconnected.start();await flush();view=disconnected.render();
  assert.equal(disconnected.values[2][0].id,8,'Successful courses must survive a dashboard API failure');
  assert.equal(nodes(view,n=>n.type==='Tl'||n.type==='El'||n.type==='Dl').length,0,'Unavailable statistics must not render fabricated zero metrics or charts');
  assert.equal(nodes(view,n=>n.props?.['data-ql-dashboard-status']).length,1);

  let resolve;const pending=new Promise(r=>resolve=r);
  const left=mount([()=>pending,()=>[],()=>({}),()=>({leaderboard:[]})]);left.render();const cleanup=left.start();await flush();cleanup();const before=left.changed;resolve(dashboard);await flush();
  assert.equal(left.changed,before,'A completed request must not update an unmounted dashboard');

  const start=bundle.indexOf('P.interceptors.response.use('),end=bundle.indexOf(');var _s=',start)+1;
  let rejectHandler;const retried=[],removed=[];
  vm.runInNewContext(bundle.slice(start,end),{P:{interceptors:{response:{use(ok,fail){rejectHandler=fail;}}},request(config){retried.push(config);return Promise.resolve({data:{}});}},localStorage:{removeItem(key){removed.push(key);}},window:{location:{pathname:'/login'}},Promise,Number,setTimeout(fn){fn();}});
  for(const code of ['ERR_NETWORK','ECONNABORTED','ETIMEDOUT'])await rejectHandler({code,config:{method:'get'}});
  assert.equal(retried.length,3,'Mobile connection and timeout failures on reads can retry');
  for(const error of [
    {code:'ERR_NETWORK',config:{method:'post'}},
    {code:'ERR_CANCELED',config:{method:'get'}},
    {code:'ERR_NETWORK',config:{method:'get',__qlRetry:2}},
    {response:{status:403},config:{method:'get'}},
    {response:{status:401},config:{method:'get'}}
  ])await assert.rejects(rejectHandler(error));
  assert.equal(retried.length,3,'Writes, cancellation, authorization denial and exhausted retries must never repeat');
  assert.deepEqual(removed,['lab_token','lab_user']);
  console.log('PASS: independent dashboard data, visible retry, no fake zero metrics, unmount cleanup, bounded mobile read retries and unchanged write/auth handling.');
})().catch(error=>{console.error(error);process.exitCode=1;});
