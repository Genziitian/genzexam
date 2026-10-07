(function () {
  'use strict';
  const API = window.QLStorefront?.apiBase || 'https://labapi.genziitian.in/public/api';
  const byId = id => document.getElementById(id);
  const search = byId('search'), level = byId('level-filter'), type = byId('type-filter'), price = byId('price-filter');
  const grid = byId('paper-grid'), dialog = byId('paper-details');
  let papers = [], ownedIds = new Set(), selected = null, busy = false, toastTimer;
  function token() { try { return localStorage.getItem('lab_token') || ''; } catch { return ''; } }
  function esc(value) { return String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char])); }
  function signIn(id) { if (window.QLStorefront?.signIn) window.QLStorefront.signIn(id); else location.assign('/login'); }
  async function api(path, body) {
    const headers = {Accept:'application/json'};
    if (token()) headers.Authorization = 'Bearer ' + token();
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    const response = await fetch(API + path, {method:body === undefined ? 'GET' : 'POST', headers, body:body === undefined ? undefined : JSON.stringify(body)});
    const data = await response.json().catch(() => ({}));
    if (response.status === 401) { try { localStorage.removeItem('lab_token'); localStorage.removeItem('lab_user'); } catch {} signIn(selected?.id); throw new Error('Please sign in again to continue.'); }
    if (!response.ok) throw new Error(data.message || data.error || 'Unable to complete this request. Please try again.');
    return data;
  }
  function toast(message) { const el = byId('toast'); el.textContent = message; el.classList.add('show'); clearTimeout(toastTimer); toastTimer = setTimeout(() => el.classList.remove('show'), 6000); }
  function money(paise) { return Number(paise) ? new Intl.NumberFormat('en-IN', {style:'currency', currency:'INR', maximumFractionDigits:2}).format(Number(paise)/100) : 'Free'; }
  function sectionLabel(section) { return ({quiz1:'Quiz 1',quiz2:'Quiz 2',endterm:'End Term',mock_test:'Mock test',practice:'Practice',practice_graded:'Graded practice'})[section] || section || 'Practice paper'; }
  function shortPrice(paise) { return money(paise).replace(/\.00$/, ''); }
  // Free papers open for everyone; a paid paper opens once it is purchased (ownedIds).
  function isFree(p) { return Number(p.price_paise || 0) === 0; }
  function isOwned(p) { return !isFree(p) && ownedIds.has(String(p.id)); }
  function isExpired(p) { return !isFree(p) && !!p.expired; }
  function canOpen(p) { return p.available !== false && (isFree(p) || isOwned(p)); }
  function getLabel(p) { return canOpen(p) ? (p.in_progress ? 'Continue' : Number(p.attempt_count) > 0 ? 'Attempt again' : isFree(p) ? 'Start free' : 'Start') : isExpired(p) ? 'Renew for '+shortPrice(p.price_paise) : 'Buy for '+shortPrice(p.price_paise); }
  function progress(p) { return p.in_progress ? 'In progress' : Number(p.attempt_count) > 0 && p.last_total_marks != null ? 'Last score '+Number(p.last_score || 0)+'/'+Number(p.last_total_marks) : ''; }
  function card(p) {
    const free = isFree(p), owned = isOwned(p);
    const pill = p.available === false ? 'UNAVAILABLE' : isExpired(p) ? 'ACCESS EXPIRED' : owned ? 'PURCHASED ✓' : free ? 'FREE' : 'PAID';
    return `<article class="card${owned ? ' is-owned' : ''}"><div class="cardtop"><span class="pill ${owned ? 'owned' : free ? '' : 'paid'}">${pill}</span>${owned ? '' : `<span class="price">${esc(money(p.price_paise))}</span>`}</div><h3>${esc(p.title)}</h3><div class="sub">${esc(p.course?.name || 'Course')}${p.year ? ' · '+esc(p.year) : ''}</div><p class="card-description">${esc(p.description || 'View the paper details and access options before you start.')}</p><div class="meta"><span>${esc(sectionLabel(p.section))}</span>${p.question_count != null ? `<span>${esc(p.question_count)} questions</span>` : ''}${p.time_limit_minutes ? `<span>${esc(p.time_limit_minutes)} min</span>` : ''}${progress(p) ? `<span class="done">${esc(progress(p))}</span>` : ''}</div><div class="card-actions"><button class="btn" data-paper="${esc(p.id)}">View details</button>${p.available === false ? '' : `<button class="btn primary" data-get="${esc(p.id)}">${esc(getLabel(p))}</button>`}</div></article>`;
  }
  function renderCatalog() {
    const query = search.value.trim().toLowerCase();
    const rows = papers.filter(p => p.available !== false && (!query || [p.title,p.description,p.course?.name,p.year,sectionLabel(p.section)].join(' ').toLowerCase().includes(query)) && (!level.value || String(p.course?.level || '') === level.value) && (!type.value || p.section === type.value) && (!price.value || (price.value === 'free' ? Number(p.price_paise || 0) === 0 : Number(p.price_paise || 0) > 0)));
    byId('result-count').textContent = `${rows.length} ${rows.length === 1 ? 'paper' : 'papers'}`;
    grid.innerHTML = rows.length ? rows.map(card).join('') : '<div class="empty">No papers match these filters. Try another level or paper type.<br><button class="btn" data-reset>Clear filters</button></div>';
  }
  async function loadCatalog() {
    grid.innerHTML = '<div class="loading">Loading the paper catalog…</div>';
    try {
      const data = await api('/storefront/papers'); papers = Array.isArray(data.papers) ? data.papers : [];
      level.innerHTML = '<option value="">All levels</option>';
      [...new Set(papers.map(p => p.course?.level).filter(Boolean))].sort().forEach(value => { const option = document.createElement('option'); option.value = value; option.textContent = value; level.appendChild(option); });
      if (token()) { try { const library = await api('/storefront/my-papers'); ownedIds = new Set((library.papers || []).filter(p => Number(p.price_paise || 0) > 0 && p.has_access !== false && !p.expired && p.available !== false).map(p => String(p.id))); (library.papers || []).forEach(p => { const index = papers.findIndex(row => String(row.id) === String(p.id)); if (index >= 0) papers[index] = {...papers[index], ...p}; }); } catch { /* Catalog remains available if library cannot load. */ } }
      renderCatalog();
      const requested = new URLSearchParams(location.search).get('paper');
      if (requested) { const paper = papers.find(p => String(p.id) === requested); if (paper) showDetails(paper); else toast('This paper is currently unavailable. Browse the available papers below.'); }
    } catch (error) { grid.innerHTML = `<div class="error">${esc(error.message)}<br><button class="btn" data-retry>Try again</button></div>`; }
  }
  function showDetails(paper) {
    selected = paper; const owned = isOwned(paper);
    byId('details-content').innerHTML = `<h2 id="details-title">${esc(paper.title)}</h2><p class="sub">${esc(paper.course?.name || '')}${paper.course?.level ? ' · '+esc(paper.course.level) : ''}</p><p class="detail-description">${esc(paper.description || 'Practice this paper and review your progress from your student dashboard.')}</p><dl class="detail-facts"><div><dt>Paper type</dt><dd>${esc(sectionLabel(paper.section))}</dd></div><div><dt>Price</dt><dd>${owned ? 'Purchased ✓' : esc(money(paper.price_paise))}</dd></div><div><dt>Questions</dt><dd>${esc(paper.question_count ?? 'See paper')}</dd></div><div><dt>Time limit</dt><dd>${paper.time_limit_minutes ? esc(paper.time_limit_minutes)+' minutes' : 'No time limit listed'}</dd></div><div><dt>Access period</dt><dd>${isFree(paper) ? 'Always open' : paper.access_days ? esc(paper.access_days)+' days from purchase' : 'No expiry'}</dd></div>${paper.year ? `<div><dt>Year</dt><dd>${esc(paper.year)}</dd></div>` : ''}</dl><p class="library-note">${paper.available === false ? 'This paper is currently unavailable. Please contact support if you purchased it.' : isExpired(paper) ? 'Your access has expired. Buy this paper again to renew access.' : owned ? 'You have purchased this paper. It is in My Papers.' : !isFree(paper) ? 'One-time purchase. Your paper is added to My Papers after payment is confirmed.' : 'Free paper. Start it any time; your score and progress are saved in My Papers.'}</p>`;
    byId('details-status').textContent = paper.expires_at && !isFree(paper) ? 'Access expires: '+new Date(paper.expires_at).toLocaleString() : ''; updateAction(); if (!dialog.open) dialog.showModal();
  }
  function updateAction() { const button = byId('details-action'); button.disabled = busy || selected?.available === false; button.textContent = selected?.available === false ? 'Currently unavailable' : busy ? 'Please wait…' : !selected ? '' : canOpen(selected) ? getLabel(selected) : !token() ? 'Sign in to buy' : getLabel(selected); }
  let cardButton = null;
  function restoreCard() { if (cardButton) { cardButton.el.disabled = false; cardButton.el.textContent = cardButton.label; cardButton = null; } }
  function report(message) { byId('details-status').textContent = message; if (!dialog.open) toast(message); }
  async function takeAction() {
    if (!selected || busy || selected.available === false) return;
    const paper = selected;
    if (canOpen(paper)) { if (token()) location.assign('/paper/'+encodeURIComponent(paper.id)); else if (window.QLStorefront?.signIn) window.QLStorefront.signIn(paper.id, true); else location.assign('/login'); return; }
    if (!token()) { signIn(paper.id); return; }
    busy = true; updateAction(); byId('details-status').textContent = '';
    await checkout(paper);
  }
  async function checkout(paper) {
    const release = () => { busy = false; updateAction(); restoreCard(); };
    try {
      if (!window.Razorpay) throw new Error('Secure checkout is still loading. Please try again in a moment.');
      const order = await api('/storefront/papers/'+encodeURIComponent(paper.id)+'/orders', {});
      const checkout = new window.Razorpay({key:order.key_id,amount:order.amount,currency:order.currency,name:order.name,description:order.description,order_id:order.order_id,prefill:order.prefill,theme:{color:'#1f3d22'},handler:async result => {
        try { await api('/storefront/payments/verify',result); location.assign('/my-papers?payment=success'); }
        catch (error) { toast(error.message+' If you were charged, check My Papers for confirmation before trying again.'); release(); }
      },modal:{ondismiss:() => { toast('Checkout closed. You can try again when you are ready.'); release(); }}});
      if (checkout.on) checkout.on('payment.failed', () => { toast('Payment was not completed. You can retry from the paper details.'); release(); });
      dialog.close(); checkout.open();
    } catch (error) { byId('details-status').textContent = error.message; toast(error.message); release(); }
  }
  document.addEventListener('click',event => {
    const button = event.target.closest('button'); if (!button) return;
    if (button.dataset.paper) { const paper = papers.find(p => String(p.id) === button.dataset.paper); if (paper) showDetails(paper); }
    if (button.dataset.get && !busy) { const paper = papers.find(p => String(p.id) === button.dataset.get); if (paper) { selected = paper; if (token() && !canOpen(paper)) { cardButton = {el: button, label: button.textContent}; button.disabled = true; button.textContent = 'Please wait…'; } takeAction(); } }
    if (button.hasAttribute('data-retry')) loadCatalog();
    if (button.hasAttribute('data-login')) signIn();
    if (button.hasAttribute('data-reset')) { [search,level,type,price].forEach(el => el.value = ''); renderCatalog(); }
  });
  [search,level,type,price].forEach(el => el.addEventListener('input',renderCatalog));
  byId('close-details').onclick = () => dialog.close(); byId('details-action').onclick = () => takeAction();
  // The paper library lives in the student dashboard (My Papers); prices and sales in the manager console.
  if (new URLSearchParams(location.search).get('library') === '1') { location.replace('/my-papers'); return; }
  loadCatalog();
  // Search box: type course names into the placeholder until the student starts searching.
  (function typePlaceholder() {
    const rest = 'Search papers or courses';
    if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    let word = 0, pos = 0, hold = 8, erasing = false;
    const words = () => { const names = [...new Set(papers.map(p => p.course?.name).filter(Boolean))].slice(0, 6); return names.concat(['Quiz 1', 'End Term', 'Mock test']); };
    setInterval(() => {
      if (document.activeElement === search || search.value) { if (search.placeholder !== rest) search.placeholder = rest; pos = 0; erasing = false; hold = 0; return; }
      if (hold > 0) { hold--; return; }
      const list = words(), text = list[word % list.length];
      if (!erasing) { pos++; if (pos >= text.length) { pos = text.length; erasing = true; hold = 16; } }
      else { pos -= 2; if (pos <= 0) { pos = 0; erasing = false; word++; hold = 3; } }
      search.placeholder = 'Search \u201c' + text.slice(0, pos) + '\u201d';
    }, 85);
  })();
  const script = document.createElement('script'); script.src = 'https://checkout.razorpay.com/v1/checkout.js'; script.async = true; script.onerror = () => toast('Checkout could not load. Check your connection and refresh before buying.'); document.head.appendChild(script);
})();
