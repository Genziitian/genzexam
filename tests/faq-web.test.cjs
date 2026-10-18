const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../more-web.js'), 'utf8');

function extractFn(name) {
  const start = source.indexOf(`function ${name}(`);
  assert.ok(start !== -1, `Could not find function ${name}`);
  let depth = 0;
  let i = source.indexOf('{', start);
  for (; i < source.length; i++) {
    if (source[i] === '{') depth++;
    else if (source[i] === '}') {
      depth--;
      if (depth === 0) return source.slice(start, i + 1);
    }
  }
  throw new Error(`Unmatched braces for ${name}`);
}

const actionMarkupSrc = extractFn('actionMarkup');
const bindMoreSrc = extractFn('bindMore');

class MockElement {
  constructor(tagName = 'div', attributes = {}) {
    this.tagName = tagName;
    this.attributes = { ...attributes };
    this.hidden = attributes.hidden !== undefined;
    this.value = attributes.value || '';
    this.textContent = '';
    this.listeners = {};
    this.style = { display: '' };
    this.children = [];
    this.parentElement = null;
  }
  setAttribute(k, v) { this.attributes[k] = String(v); }
  getAttribute(k) { return this.attributes[k] ?? null; }
  addEventListener(event, fn) {
    if (!this.listeners[event]) this.listeners[event] = [];
    this.listeners[event].push(fn);
  }
  dispatchEvent(event) {
    const list = this.listeners[event.type || event] || [];
    for (const fn of list) fn(event);
  }
  querySelectorAll(sel) {
    const results = [];
    function walk(el) {
      for (const child of el.children) {
        if (sel === '[data-ql-more-faq]' && child.attributes['data-ql-more-faq'] !== undefined) results.push(child);
        else if (sel === '[data-ql-more-theme]' && child.attributes['data-ql-more-theme'] !== undefined) results.push(child);
        walk(child);
      }
    }
    walk(this);
    return results;
  }
  querySelector(sel) {
    if (sel.startsWith('#')) {
      const id = sel.slice(1);
      const findId = (el) => {
        if (el.attributes.id === id) return el;
        for (const child of el.children) {
          const found = findId(child);
          if (found) return found;
        }
        return null;
      };
      const match = findId(this);
      return match || new MockElement('div', { id });
    }
    return new MockElement('div');
  }
}

// Simple HTML parser for testing the generated FAQ markup
function parseFaqCard(html) {
  const card = new MockElement('div');
  const searchMatch = html.match(/<input id="ql-more-faq-search"[^>]*>/);
  const searchInput = new MockElement('input', { id: 'ql-more-faq-search', type: 'search' });
  card.children.push(searchInput);

  const toggleMatch = html.match(/<button[^>]*id="ql-more-faq-toggle"[^>]*aria-expanded="([^"]*)"[^>]*>/);
  const toggleWrap = new MockElement('div', { id: 'ql-more-faq-toggle-wrap' });
  const toggleBtn = new MockElement('button', { id: 'ql-more-faq-toggle', 'aria-expanded': toggleMatch ? toggleMatch[1] : 'false' });
  toggleBtn.textContent = 'View more';
  toggleBtn.parentElement = toggleWrap;
  toggleWrap.children.push(toggleBtn);

  const emptyMsg = new MockElement('p', { id: 'ql-more-faq-empty' });
  emptyMsg.style.display = 'none';
  card.children.push(emptyMsg);

  const regex = /<details data-ql-more-faq( hidden)?><summary>([\s\S]*?)<\/summary><p>([\s\S]*?)<\/p><\/details>/g;
  let m;
  while ((m = regex.exec(html)) !== null) {
    const item = new MockElement('details', { 'data-ql-more-faq': '', ...(m[1] ? { hidden: '' } : {}) });
    item.textContent = m[2] + ' ' + m[3];
    item.hidden = !!m[1];
    item.parentElement = card;
    card.children.push(item);
  }
  card.children.push(toggleWrap);
  return { card, searchInput, toggleBtn, toggleWrap, emptyMsg };
}

// 1. Verify actionMarkup renders first 3 items visible, remaining hidden
const sandbox = {
  MORE_ID: 'ql-web-more-actions',
  escapeHtml: s => String(s || ''),
};
vm.runInNewContext(actionMarkupSrc + '; this.markup = actionMarkup();', sandbox);
const markup = sandbox.markup;

const { card, searchInput, toggleBtn, toggleWrap, emptyMsg } = parseFaqCard(markup);
const faqs = card.querySelectorAll('[data-ql-more-faq]');
assert.equal(faqs.length, 15, 'Should render 15 FAQs in total');
assert.equal(faqs[0].hidden, false, 'First FAQ is visible');
assert.equal(faqs[1].hidden, false, 'Second FAQ is visible');
assert.equal(faqs[2].hidden, false, 'Third FAQ is visible');
assert.equal(faqs[3].hidden, true, 'Fourth FAQ is hidden initially');
assert.equal(faqs[14].hidden, true, 'Last FAQ is hidden initially');

// 2. Bind card and test interactivity
const bindContext = {
  localStorage: { getItem: () => null, setItem: () => {} },
  applyTheme: () => {},
  document: { body: { appendChild() {} }, createElement: () => new MockElement('dialog') },
  profileData: async () => ({ user: {} }),
  renderAvatar: () => {},
  api: async () => ({}),
  signOut: () => {},
};
vm.runInNewContext(bindMoreSrc + '; bindMore(this.card);', { ...bindContext, card });

// 3. Test View More toggle
assert.equal(toggleBtn.textContent, 'View more');
assert.equal(toggleBtn.attributes['aria-expanded'], 'false');

// Click View more
toggleBtn.dispatchEvent({ type: 'click' });
assert.equal(faqs.every(f => !f.hidden), true, 'All 15 FAQs should be visible after clicking View more');
assert.equal(toggleBtn.textContent, 'View less');
assert.equal(toggleBtn.attributes['aria-expanded'], 'true');

// Click View less
toggleBtn.dispatchEvent({ type: 'click' });
assert.equal(faqs.slice(0, 3).every(f => !f.hidden), true, 'First 3 are visible');
assert.equal(faqs.slice(3).every(f => f.hidden), true, 'Items 4+ are hidden');
assert.equal(toggleBtn.textContent, 'View more');

// 4. Test Search
// Search for "sign in" (matches 3 FAQs: sign in question, forgot password on sign-in page, why signed out / sign in again)
searchInput.value = 'sign in';
searchInput.dispatchEvent({ type: 'input' });
assert.equal(faqs[0].hidden, false, '"How do I sign in?" should match');
assert.equal(faqs.filter(f => !f.hidden).length, 3, 'All 3 FAQs mentioning sign in should be visible');
assert.equal(toggleWrap.style.display, 'none', 'Toggle wrap should be hidden while searching');
assert.equal(emptyMsg.style.display, 'none', 'Empty message should be hidden when results match');

// Search for single unique FAQ "weekly goal"
searchInput.value = 'weekly goal';
searchInput.dispatchEvent({ type: 'input' });
assert.equal(faqs.filter(f => !f.hidden).length, 1, 'Only weekly goal FAQ matches');
assert.equal(faqs[11].hidden, false);

// Search for initially hidden FAQ "leaderboard" (item 10)
searchInput.value = 'leaderboard';
searchInput.dispatchEvent({ type: 'input' });
assert.equal(faqs[10].hidden, false, '"How is the leaderboard ranked?" should be visible');
assert.equal(faqs.filter(f => !f.hidden).length, 1);

// Search for multi-word non-adjacent "change avatar" (item 2)
searchInput.value = 'change avatar';
searchInput.dispatchEvent({ type: 'input' });
assert.equal(faqs[2].hidden, false, '"How do I change my name or avatar?" should match');

// Search for non-matching query
searchInput.value = 'nonexistentxyz';
searchInput.dispatchEvent({ type: 'input' });
assert.equal(faqs.every(f => f.hidden), true, 'No FAQs should match');
assert.equal(emptyMsg.style.display, 'block', 'Empty message should be displayed');

// Clear search
searchInput.value = '';
searchInput.dispatchEvent({ type: 'input' });
assert.equal(emptyMsg.style.display, 'none', 'Empty message should be hidden');
assert.equal(faqs.slice(0, 3).every(f => !f.hidden), true, 'First 3 items restored');
assert.equal(faqs.slice(3).every(f => f.hidden), true, 'Remaining items hidden');
assert.equal(toggleWrap.style.display, 'block', 'Toggle button restored');
assert.equal(toggleBtn.textContent, 'View more');

// Press Escape to clear
searchInput.value = 'dark mode';
searchInput.dispatchEvent({ type: 'input' });
assert.equal(faqs.filter(f => !f.hidden).length, 1);
searchInput.dispatchEvent({ type: 'keydown', key: 'Escape' });
assert.equal(searchInput.value, '', 'Escape clears input');
assert.equal(faqs.slice(0, 3).every(f => !f.hidden), true, 'Restored after escape');

console.log('PASS: FAQ initial limit (first 3), View more/less expansion, multi-term search, and empty state.');
