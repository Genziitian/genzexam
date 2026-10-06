(function () {
  'use strict';
  const API = window.QLStorefront?.apiBase || 'https://labapi.genziitian.in/public/api';
  const byId = id => document.getElementById(id);
  const search = byId('search'), level = byId('level-filter'), type = byId('type-filter'), price = byId('price-filter');
  const grid = byId('paper-grid'), libraryGrid = byId('library-grid'), dialog = byId('paper-details');
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
  function getLabel(p, owned) { const free = Number(p.price_paise || 0) === 0; return owned && !p.expired ? 'Open paper' : p.expired ? (free ? 'Renew free' : 'Renew in '+shortPrice(p.price_paise)) : free ? 'Get in Free' : 'Get in '+shortPrice(p.price_paise); }
  function card(p, owned) {
    const free = Number(p.price_paise || 0) === 0;
    return `<article class="card"><div class="cardtop"><span class="pill ${free ? '' : 'paid'}">${p.available === false ? 'UNAVAILABLE' : p.expired ? 'ACCESS EXPIRED' : owned ? 'IN YOUR LIBRARY' : free ? 'FREE' : 'PAID'}</span><span class="price">${esc(money(p.price_paise))}</span></div><h3>${esc(p.title)}</h3><div class="sub">${esc(p.course?.name || 'Course')}${p.year ? ' · '+esc(p.year) : ''}</div><p class="card-description">${esc(p.description || 'View the paper details and access options before you start.')}</p><div class="meta"><span>${esc(sectionLabel(p.section))}</span>${p.question_count != null ? `<span>${esc(p.question_count)} questions</span>` : ''}${p.time_limit_minutes ? `<span>${esc(p.time_limit_minutes)} min</span>` : ''}</div><div class="card-actions"><button class="btn" data-paper="${esc(p.id)}">View details</button>${p.available === false ? '' : `<button class="btn primary" data-get="${esc(p.id)}">${esc(getLabel(p, owned))}</button>`}</div></article>`;
  }
  function renderCatalog() {
    const query = search.value.trim().toLowerCase();
    const rows = papers.filter(p => p.available !== false && (!query || [p.title,p.description,p.course?.name,p.year,sectionLabel(p.section)].join(' ').toLowerCase().includes(query)) && (!level.value || String(p.course?.level || '') === level.value) && (!type.value || p.section === type.value) && (!price.value || (price.value === 'free' ? Number(p.price_paise || 0) === 0 : Number(p.price_paise || 0) > 0)));
    byId('result-count').textContent = `${rows.length} ${rows.length === 1 ? 'paper' : 'papers'}`;
    grid.innerHTML = rows.length ? rows.map(p => card(p,ownedIds.has(String(p.id)))).join('') : '<div class="empty">No papers match these filters. Try another level or paper type.<br><button class="btn" data-reset>Clear filters</button></div>';
  }
  async function loadCatalog() {
    grid.innerHTML = '<div class="loading">Loading the paper catalog…</div>';
    try {
      const data = await api('/storefront/papers'); papers = Array.isArray(data.papers) ? data.papers : [];
      level.innerHTML = '<option value="">All levels</option>';
      [...new Set(papers.map(p => p.course?.level).filter(Boolean))].sort().forEach(value => { const option = document.createElement('option'); option.value = value; option.textContent = value; level.appendChild(option); });
      if (token()) { try { const library = await api('/storefront/my-papers'); ownedIds = new Set((library.papers || []).filter(p => p.has_access !== false && !p.expired && p.available !== false).map(p => String(p.id))); (library.papers || []).forEach(p => { const index = papers.findIndex(row => String(row.id) === String(p.id)); if (index >= 0) papers[index] = {...papers[index], ...p}; }); } catch { /* Catalog remains available if library cannot load. */ } }
      renderCatalog();
      const requested = new URLSearchParams(location.search).get('paper');
      if (requested) { const paper = papers.find(p => String(p.id) === requested); if (paper) showDetails(paper); else toast('This paper is currently unavailable. Browse the available papers below.'); }
    } catch (error) { grid.innerHTML = `<div class="error">${esc(error.message)}<br><button class="btn" data-retry>Try again</button></div>`; }
  }
  function showDetails(paper) {
    selected = paper; const owned = ownedIds.has(String(paper.id));
    byId('details-content').innerHTML = `<h2 id="details-title">${esc(paper.title)}</h2><p class="sub">${esc(paper.course?.name || '')}${paper.course?.level ? ' · '+esc(paper.course.level) : ''}</p><p class="detail-description">${esc(paper.description || 'Practice this paper and review your progress from your student dashboard.')}</p><dl class="detail-facts"><div><dt>Paper type</dt><dd>${esc(sectionLabel(paper.section))}</dd></div><div><dt>Price</dt><dd>${esc(money(paper.price_paise))}</dd></div><div><dt>Questions</dt><dd>${esc(paper.question_count ?? 'See paper')}</dd></div><div><dt>Time limit</dt><dd>${paper.time_limit_minutes ? esc(paper.time_limit_minutes)+' minutes' : 'No time limit listed'}</dd></div><div><dt>Access period</dt><dd>${paper.access_days ? esc(paper.access_days)+' days from access being granted' : 'No expiry'}</dd></div>${paper.year ? `<div><dt>Year</dt><dd>${esc(paper.year)}</dd></div>` : ''}</dl><p class="library-note">${paper.available === false ? 'This paper is currently unavailable. Please contact support if you purchased it.' : paper.expired ? 'Your access has expired. Claim or purchase this paper again to renew access.' : owned ? 'This paper is already in your library.' : Number(paper.price_paise || 0) ? 'One-time purchase. Your paper is added to My Papers after payment is confirmed.' : 'Add this free paper to your library to access it with your account.'}</p>`;
    byId('details-status').textContent = paper.expires_at ? 'Access expires: '+new Date(paper.expires_at).toLocaleString() : ''; updateAction(); if (!dialog.open) dialog.showModal();
  }
  function updateAction() { const button = byId('details-action'); button.disabled = busy || selected?.available === false; button.textContent = selected?.available === false ? 'Currently unavailable' : busy ? 'Please wait…' : ownedIds.has(String(selected?.id)) ? 'Open paper' : !token() ? 'Sign in to '+(Number(selected?.price_paise || 0) ? 'buy' : 'claim free paper') : Number(selected?.price_paise || 0) ? 'Buy for '+money(selected.price_paise) : 'Add to My Papers — free'; }
  let cardButton = null;
  function restoreCard() { if (cardButton) { cardButton.el.disabled = false; cardButton.el.textContent = cardButton.label; cardButton = null; } }
  function report(message) { byId('details-status').textContent = message; if (!dialog.open) toast(message); }
  async function takeAction(fromCard) {
    if (!selected || busy || selected.available === false) return;
    const paper = selected;
    if (ownedIds.has(String(paper.id))) { location.assign('/paper/'+encodeURIComponent(paper.id)); return; }
    if (!token()) { signIn(paper.id); return; }
    busy = true; updateAction(); byId('details-status').textContent = '';
    if (Number(paper.price_paise || 0) > 0) { await checkout(paper); return; }
    try { await api('/storefront/papers/'+encodeURIComponent(paper.id)+'/claim', {}); ownedIds.add(String(paper.id)); paper.expired = false; paper.has_access = true; if (fromCard === true) { location.assign('/paper/'+encodeURIComponent(paper.id)); return; } renderCatalog(); toast('Added to My Papers. Your paper is ready.'); byId('details-status').textContent = 'Added to your library. You can open your paper now.'; }
    catch (error) { report(error.message); restoreCard(); }
    finally { busy = false; updateAction(); }
  }
  async function checkout(paper) {
    const release = () => { busy = false; updateAction(); restoreCard(); };
    try {
      if (!window.Razorpay) throw new Error('Secure checkout is still loading. Please try again in a moment.');
      const order = await api('/storefront/papers/'+encodeURIComponent(paper.id)+'/orders', {});
      const checkout = new window.Razorpay({key:order.key_id,amount:order.amount,currency:order.currency,name:order.name,description:order.description,order_id:order.order_id,prefill:order.prefill,theme:{color:'#1f3d22'},handler:async result => {
        try { await api('/storefront/payments/verify',result); location.assign('/dashboard?payment=success'); }
        catch (error) { toast(error.message+' If you were charged, check My Papers for confirmation before trying again.'); release(); }
      },modal:{ondismiss:() => { toast('Checkout closed. You can try again when you are ready.'); release(); }}});
      if (checkout.on) checkout.on('payment.failed', () => { toast('Payment was not completed. You can retry from the paper details.'); release(); });
      dialog.close(); checkout.open();
    } catch (error) { byId('details-status').textContent = error.message; toast(error.message); release(); }
  }
  async function openLibrary() {
    byId('catalog-view').hidden = true; byId('library-view').classList.add('show');
    history.replaceState(null,'','/papers?library=1');
    if (!token()) { libraryGrid.innerHTML = '<div class="empty">Sign in to see your free and purchased papers.<br><button class="btn primary" data-login>Sign in</button></div>'; return; }
    libraryGrid.innerHTML = '<div class="loading">Loading your papers…</div>';
    try { const data = await api('/storefront/my-papers'); const owned = data.papers || []; owned.forEach(p => { if (p.has_access !== false && !p.expired && p.available !== false) ownedIds.add(String(p.id)); else ownedIds.delete(String(p.id)); const index = papers.findIndex(row => String(row.id) === String(p.id)); if (index >= 0) papers[index] = {...papers[index], ...p}; else papers.push(p); }); libraryGrid.innerHTML = owned.length ? owned.map(p => card(p,ownedIds.has(String(p.id)))).join('') : '<div class="empty">Your library is empty. Browse the catalog to claim a free paper or choose a paid paper.</div>'; }
    catch (error) { libraryGrid.innerHTML = `<div class="error">${esc(error.message)}<br><button class="btn" data-library-retry>Try again</button></div>`; }
  }
  function showCatalog() { byId('library-view').classList.remove('show'); byId('catalog-view').hidden = false; history.replaceState(null,'','/papers'); renderCatalog(); }
  document.addEventListener('click',event => {
    const button = event.target.closest('button'); if (!button) return;
    if (button.dataset.paper) { const paper = papers.find(p => String(p.id) === button.dataset.paper); if (paper) showDetails(paper); }
    if (button.dataset.get && !busy) { const paper = papers.find(p => String(p.id) === button.dataset.get); if (paper) { selected = paper; if (token() && !(ownedIds.has(String(paper.id)) && !paper.expired)) { cardButton = {el: button, label: button.textContent}; button.disabled = true; button.textContent = 'Please wait…'; } takeAction(true); } }
    if (button.hasAttribute('data-retry')) loadCatalog();
    if (button.hasAttribute('data-library-retry')) openLibrary();
    if (button.hasAttribute('data-login')) signIn();
    if (button.hasAttribute('data-reset')) { [search,level,type,price].forEach(el => el.value = ''); renderCatalog(); }
  });
  [search,level,type,price].forEach(el => el.addEventListener('input',renderCatalog));
  byId('close-details').onclick = () => dialog.close(); byId('details-action').onclick = () => takeAction();
  byId('back-catalog').onclick = showCatalog;
  // The paper library lives in the student dashboard (My Papers); prices and sales in the manager console.
  if (new URLSearchParams(location.search).get('library') === '1') { location.replace('/my-papers'); return; }
  loadCatalog();
  const script = document.createElement('script'); script.src = 'https://checkout.razorpay.com/v1/checkout.js'; script.async = true; script.onerror = () => toast('Checkout could not load. Check your connection and refresh before buying.'); document.head.appendChild(script);
})();
