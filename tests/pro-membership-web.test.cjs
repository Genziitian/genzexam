const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../more-web.js'), 'utf8');
const membershipSource = source.slice(source.indexOf('  function ensureMembership('), source.indexOf('  function removeDuplicateProfileBlocks('));

function setup(initial) {
  let membership = initial;
  const parts = new Map();
  const element = () => ({hidden: false, disabled: false, textContent: '', listeners: {},
    addEventListener(event, fn) { this.listeners[event] = fn; }});
  const card = {querySelector(selector) {
    if (!parts.has(selector)) parts.set(selector, element());
    return parts.get(selector);
  }};
  const context = {
    MEMBERSHIP_ID: 'membership',
    document: {getElementById: () => null, createElement: () => card},
    api: async () => membership,
    apiBase: () => 'https://example.test/api', token: () => 'fixture',
    window: {confirm: () => true},
    location: {assign() {}},
    fetch: async () => {
      membership = {...membership, subscription: {...membership.subscription, cancel_at_period_end: true}};
      return {ok: true, json: async () => ({message: 'Renewal cancelled; access remains.'})};
    },
  };
  vm.runInNewContext(membershipSource + '\nensureMembership({appendChild() {}});', context);
  return {part: name => parts.get('#ql-web-pro-' + name)};
}

const settle = async () => { for (let i = 0; i < 12; i++) await Promise.resolve(); };
const initial = () => ({is_pro: false, trial_available: true, plan: {price_paise: 9900, trial_days: 7, enabled: true}, payment_setup: {web: true}});

(async () => {
  let app = setup(initial()); await settle();
  assert.equal(app.part('buy').textContent, 'Start 7-day trial');

  app = setup({...initial(), trial_available: false}); await settle();
  assert.equal(app.part('buy').textContent, 'Subscribe to Pro');
  assert.doesNotMatch(app.part('dates').textContent, /trial/);

  app = setup({...initial(), plan: {enabled: false}}); await settle();
  assert.equal(app.part('buy').hidden, true);

  app = setup({...initial(), plan: {trial_days: 0}}); await settle();
  assert.equal(app.part('buy').textContent, 'Subscribe to Pro');

  app = setup({...initial(), is_pro: true, subscription: {id: 1, provider: 'google_play', status: 'active', started_at: '2026-10-01T00:00:00Z', current_period_ends_at: '2026-11-01T00:00:00Z'}});
  await settle();
  await app.part('cancel').listeners.click(); await settle();
  assert.equal(app.part('status').textContent, 'Pro active');
  assert.match(app.part('dates').textContent, /Access ends/);
  assert.equal(app.part('cancel').hidden, true);

  app = setup({...initial(), is_pro: true, subscription: {id: 1, provider: 'manual', status: 'active'}}); await settle();
  assert.equal(app.part('cancel').hidden, true);
  console.log('PASS: web trial eligibility, disabled sales, zero-day trial, cancellation access dates, and complimentary membership.');
})().catch(error => { console.error(error); process.exitCode = 1; });
