const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(path.join(__dirname, '../manager-sales.html'), 'utf8');
const js = fs.readFileSync(path.join(__dirname, '../manager-sales.js'), 'utf8');
const css = fs.readFileSync(path.join(__dirname, '../manager-sales.css'), 'utf8');
const darkCss = fs.readFileSync(path.join(__dirname, '../ql-dark-sales.css'), 'utf8');

// 1. Verify manager-sales.html has all required IDs for the pro panel and details modal
const requiredIds = [
  'pro-panel',
  'refresh-pro',
  'pro-metrics',
  'pro-history-banner',
  'pro-history-avatar',
  'pro-history-name',
  'pro-history-badge',
  'pro-history-user',
  'pro-history-membership-strip',
  'pro-clear-history',
  'pro-transaction-search',
  'pro-transaction-search-button',
  'pro-transactions',
  'pro-transactions-prev',
  'pro-transactions-page',
  'pro-transactions-next',
  'pro-plan-form',
  'google-play-price-note',
  'pro-plan-status',
  'pro-grant-form',
  'pro-grant-status',
  'pro-status-filter',
  'pro-search',
  'pro-list',
  'previous-pro',
  'pro-page',
  'next-pro',
  'pro-details-modal',
  'pro-modal-avatar',
  'pro-modal-name',
  'pro-modal-email',
  'pro-modal-user-id',
  'pro-modal-status',
  'pro-modal-provider',
  'pro-modal-price',
  'pro-modal-product',
  'pro-modal-sub-id',
  'pro-modal-started',
  'pro-modal-trial',
  'pro-modal-paid',
  'pro-modal-charge',
  'pro-modal-history-btn',
  'pro-modal-manage-actions'
];

for (const id of requiredIds) {
  assert.ok(html.includes(`id="${id}"`), `Missing ID in manager-sales.html: ${id}`);
}

// 2. Verify all 7 requested text strings are completely removed
const removedStrings = [
  'Real-time ledger synchronized with Razorpay & Google Play Billing webhooks.',
  'Showing all transactions and paper receipts across students.',
  'Paper orders and verified subscription receipts synchronize automatically via Google Play & Razorpay webhooks.',
  'Paper orders and verified subscription receipts are shown',
  'Monthly Pro subscription pricing and free trial',
  'Manual access grant override without payment gate',
  'Registered subscriber entitlements and access status across cohorts.'
];

for (const text of removedStrings) {
  assert.ok(!html.includes(text), `Text should be removed from manager-sales.html: "${text}"`);
  assert.ok(!js.includes(text), `Text should be removed from manager-sales.js: "${text}"`);
}

// 3. Verify directory table is simplified from 9 columns to 5 essential columns (Student, Status, Provider, Price, Actions)
assert.ok(!html.includes('<th>Trial ends</th>'), 'Table header should not contain Trial ends');
assert.ok(!html.includes('<th>Next charge / access end</th>'), 'Table header should not contain Next charge');
assert.ok(js.includes('data-pro-view'), 'manager-sales.js should render data-pro-view action');

// 4. Verify manager-sales.js contains modal and helper logic
assert.ok(js.includes('initialsOf'), 'manager-sales.js must include initialsOf helper');
assert.ok(js.includes('metric-live-dot'), 'manager-sales.js metric must include live indicator support');
assert.ok(js.includes('metric-note'), 'manager-sales.js metric must include metric note support');
assert.ok(js.includes('pro-user-cell'), 'manager-sales.js must render pro-user-cell with avatar');
assert.ok(js.includes('pro-history-banner'), 'manager-sales.js must handle pro-history-banner');
assert.ok(js.includes('openProModal'), 'manager-sales.js must include openProModal');
assert.ok(js.includes('data-pro-view'), 'manager-sales.js must bind data-pro-view');

// 5. Verify CSS styling contains redesigned classes and modal
assert.ok(css.includes('.pro-dashboard'), 'manager-sales.css must include .pro-dashboard');
assert.ok(css.includes('.pro-metrics-grid'), 'manager-sales.css must include .pro-metrics-grid');
assert.ok(css.includes('.pro-spotlight-banner'), 'manager-sales.css must include .pro-spotlight-banner');
assert.ok(css.includes('.pro-controls-grid'), 'manager-sales.css must include .pro-controls-grid');
assert.ok(css.includes('.pro-table-wrap'), 'manager-sales.css must include .pro-table-wrap');
assert.ok(css.includes('.pro-modal'), 'manager-sales.css must include .pro-modal');

// 6. Verify dark CSS contains obsidian dark mode rules and modal styles
assert.ok(darkCss.includes('.pro-metrics-grid'), 'ql-dark-sales.css must include .pro-metrics-grid');
assert.ok(darkCss.includes('.pro-spotlight-banner'), 'ql-dark-sales.css must include .pro-spotlight-banner');
assert.ok(darkCss.includes('.pro-table-wrap'), 'ql-dark-sales.css must include .pro-table-wrap');
assert.ok(darkCss.includes('.pro-modal'), 'ql-dark-sales.css must include .pro-modal');

console.log('PASS: manager sales memberships & transactions redesign verified successfully.');

