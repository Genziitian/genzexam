const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../app-enhancements.js'), 'utf8');
const animationSource = source.slice(source.indexOf('    function animateSpin() {'), source.indexOf('    function showPaperReady('));
function setup(reduced = false) {
  let clock = 0, queue = [], frames = [];
  const host = {isConnected: true};
  const context = {document: {documentElement: {classList: {remove() {}}}}, host, currentAngle: 0, window: {matchMedia: () => ({matches: reduced})}, performance: {now: () => clock},
    requestAnimationFrame: callback => queue.push(callback), drawWheel: angle => frames.push(angle)};
  vm.runInNewContext(animationSource + '\nvar animation = animateSpin();', context);
  return {host, frames, animation: context.animation, pending: () => queue.length,
    advance(to) { while (clock < to) { clock = Math.min(to, clock + 16); const callbacks = queue; queue = []; callbacks.forEach(callback => callback(clock)); } }};
}
(async () => {
  const app = setup();
  app.advance(12000);
  assert.ok(app.frames.length > 600, 'Wheel must keep moving beyond the former 2.8-second animation while the paper request is pending');
  assert.equal(app.pending(), 1);
  let completed = false;
  const finishing = app.animation.finish().then(() => {completed = true;});
  app.advance(12500); await Promise.resolve();
  assert.equal(completed, false, 'The wheel should ease to a stop after the response');
  app.advance(13200); await finishing;
  assert.equal(completed, true);
  assert.equal(app.pending(), 0, 'No animation frames should continue after settling');
  await app.animation.finish();
  const fast = setup(); let fastComplete = false;
  const fastFinishing = fast.animation.finish().then(() => {fastComplete = true;});
  fast.advance(3900); await Promise.resolve(); assert.equal(fastComplete, false, 'Fast requests should still get the longer minimum spin');
  fast.advance(5300); await fastFinishing; assert.equal(fast.pending(), 0);
  const detached = setup(); detached.advance(1000); detached.host.isConnected = false; detached.advance(1100);
  await detached.animation.finish();
  assert.equal(detached.pending(), 0, 'Leaving the page must stop the animation');
  const reduced = setup(true); await reduced.animation.finish();
  assert.equal(reduced.frames.length, 0); assert.equal(reduced.pending(), 0, 'Reduced motion must not animate');
  console.log('PASS: pending-request spinning, eased completion, page removal cleanup, and reduced motion.');
})().catch(error => {console.error(error); process.exitCode = 1;});
