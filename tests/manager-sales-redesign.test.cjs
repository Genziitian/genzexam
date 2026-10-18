const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(path.join(__dirname, '../manager-sales.html'), 'utf8');
const js = fs.readFileSync(path.join(__dirname, '../manager-sales.js'), 'utf8');
const css = fs.readFileSync(path.join(__dirname, '../manager-sales.css'), 'utf8');
const darkCss = fs.readFileSync(path.join(__dirname, '../ql-dark-sales.css'), 'utf8');

// 1. Verify manager-sales.html has all required IDs for the pro panel
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
  'next-pro'
];

for (const id of requiredIds) {
  assert.ok(html.includes(`id="${id}"`), `Missing ID in manager-sales.html: ${id}`);
}

// 2. Verify manager-sales.js contains initialsOf and metric note handling
assert.ok(js.includes('initialsOf'), 'manager-sales.js must include initialsOf helper');
assert.ok(js.includes('metric-live-dot'), 'manager-sales.js metric must include live indicator support');
assert.ok(js.includes('metric-note'), 'manager-sales.js metric must include metric note support');
assert.ok(js.includes('pro-user-cell'), 'manager-sales.js must render pro-user-cell with avatar');
assert.ok(js.includes('pro-history-banner'), 'manager-sales.js must handle pro-history-banner');

// 3. Verify CSS styling contains the redesigned pro dashboard classes
assert.ok(css.includes('.pro-dashboard'), 'manager-sales.css must include .pro-dashboard');
assert.ok(css.includes('.pro-metrics-grid'), 'manager-sales.css must include .pro-metrics-grid');
assert.ok(css.includes('.pro-spotlight-banner'), 'manager-sales.css must include .pro-spotlight-banner');
assert.ok(css.includes('.pro-controls-grid'), 'manager-sales.css must include .pro-controls-grid');
assert.ok(css.includes('.pro-table-wrap'), 'manager-sales.css must include .pro-table-wrap');

// 4. Verify dark CSS contains obsidian dark mode rules
assert.ok(darkCss.includes('.pro-metrics-grid'), 'ql-dark-sales.css must include .pro-metrics-grid');
assert.ok(darkCss.includes('.pro-spotlight-banner'), 'ql-dark-sales.css must include .pro-spotlight-banner');
assert.ok(darkCss.includes('.pro-table-wrap'), 'ql-dark-sales.css must include .pro-table-wrap');

console.log('PASS: manager sales memberships & transactions redesign verified successfully.');
