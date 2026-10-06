'use strict';
const assert=require('node:assert/strict');
const http=require('node:http');
const {chromium}=require('playwright');
const {handler}=require('../server.js');
(async()=>{
  const server=http.createServer(handler);
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH?{executablePath:process.env.CHROME_PATH}:{})});
  const base=`http://127.0.0.1:${server.address().port}`;
  try{
    const phone=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1'});
    const page=await phone.newPage();let apiCalls=0;page.on('request',r=>{if(r.url().includes('/public/api/'))apiCalls++;});
    await page.goto(`${base}/exams`);await page.getByRole('heading',{name:'Use a laptop or desktop'}).waitFor();
    assert.equal(apiCalls,0);assert.equal(await page.locator('[data-action=join], [data-action=new]').count(),0);await phone.close();
    const tablet=await browser.newContext({viewport:{width:1180,height:820},hasTouch:true,userAgent:'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15'});
    await tablet.addInitScript(()=>{Object.defineProperty(navigator,'platform',{get:()=> 'MacIntel'});Object.defineProperty(navigator,'maxTouchPoints',{get:()=>5});});
    const ipad=await tablet.newPage();await ipad.goto(`${base}/exams`);await ipad.getByRole('heading',{name:'Use a laptop or desktop'}).waitFor();await tablet.close();
    const desktop=await browser.newContext({viewport:{width:1440,height:900}});
    await desktop.addInitScript(()=>localStorage.setItem('lab_token','local-test-token'));
    const laptop=await desktop.newPage();await laptop.goto(`${base}/exams`);await laptop.locator('#ep-content').waitFor();
    assert.equal(await laptop.getByRole('heading',{name:'Use a laptop or desktop'}).count(),0);
    await desktop.close();
    console.log('PASS: phone and desktop-mode tablet see desktop-only page with no exam API calls; desktop enters exam UI.');
  }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e);process.exitCode=1;});
