(function () {
  'use strict';
  const API = window.QLStorefront?.apiBase || 'https://labapi.genziitian.in/public/api';
  const list = document.getElementById('list');
  let timer;
  let papers = [];
  let verifiedManager = false;
  function token() { try { return localStorage.getItem('lab_token') || ''; } catch { return ''; } }
  function esc(value) { return String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char])); }
  function toast(message) { const el = document.getElementById('toast'); el.textContent = message; el.classList.add('show'); clearTimeout(timer); timer = setTimeout(() => el.classList.remove('show'),5000); }
  async function api(path, body) {
    const response = await fetch(API + path, {method:body ? 'PATCH' : 'GET', headers:{Accept:'application/json','Content-Type':'application/json',Authorization:'Bearer '+token()},body:body ? JSON.stringify(body) : undefined});
    const data = await response.json().catch(() => ({}));
    if (response.status === 401) { try { localStorage.removeItem('lab_token'); localStorage.removeItem('lab_user'); } catch {} if (window.QLStorefront?.signIn) window.QLStorefront.signIn(); }
    if (!response.ok) throw new Error(response.status === 401 ? 'Your session expired. Please sign in again.' : data.message || data.error || 'Unable to save. Please try again.');
    return data;
  }
  function render(rows) {
    list.innerHTML = rows.length ? rows.map(p => `<form class="row" data-id="${esc(p.id)}"><div class="paper-summary"><strong>${esc(p.title)}</strong><small>${esc(p.course_name || '')}${p.year ? ' · '+esc(p.year) : ''} · ${esc(p.section)}</small></div><label><span>Price (₹)</span><input type="number" min="0" step="0.01" value="${Number(p.price_paise || 0)/100}" name="price" required inputmode="decimal"></label><label><span>Access days</span><input type="number" min="1" max="3650" step="1" value="${p.access_days || ''}" name="days" placeholder="No expiry" inputmode="numeric"></label><div class="paper-controls"><button class="save" type="submit">Save price</button><button class="save activation" type="button" data-toggle="${esc(p.id)}" ${p.approval_status !== 'approved' ? 'disabled' : ''}>${p.is_active ? 'Deactivate' : 'Activate'}</button><small>${p.approval_status !== 'approved' ? 'Awaiting manager approval' : p.is_active ? 'Active' : 'Inactive'}</small></div><p class="row-status" role="status" aria-live="polite"></p></form>`).join('') : '<div class="notice">No papers available yet. Create a paper in the quiz manager to list it here.</div>';
  }
  async function load() {
    list.innerHTML = '<div class="notice">Loading published papers…</div>';
    try { const data = await api('/admin/quizzes'); papers = data; render(papers); }
    catch (error) { list.innerHTML = `<div class="notice">${esc(error.message)} <button class="save" id="retry">Try again</button></div>`; document.getElementById('retry').onclick = load; }
  }
  list.addEventListener('click', async event => {
    const button = event.target.closest('[data-toggle]');
    if (!button || button.disabled || !verifiedManager) return;
    const paper = papers.find(p => String(p.id) === button.dataset.toggle);
    if (!paper) return;
    button.disabled = true;
    const status = button.closest('form').querySelector('.row-status');
    try { const result = await api('/admin/quizzes/'+encodeURIComponent(paper.id)+'/toggle', {}); paper.is_active = Boolean(result.is_active); button.textContent = paper.is_active ? 'Deactivate' : 'Activate'; button.parentElement.querySelector('small').textContent = paper.is_active ? 'Active' : 'Inactive'; status.textContent = paper.is_active ? 'Activated. Listed when its course is active.' : 'Deactivated. Hidden from the catalog; purchase records are kept.'; }
    catch (error) { status.textContent = error.message; }
    finally { button.disabled = false; }
  });
  list.addEventListener('submit',async event => {
    const form = event.target.closest('form[data-id]'); if (!form) return; event.preventDefault(); if (!verifiedManager) return;
    const button = form.querySelector('button[type="submit"]'); if (button.disabled || !form.reportValidity()) return;
    const price = Math.round(Number(form.elements.price.value)*100), days = form.elements.days.value;
    if (!Number.isSafeInteger(price) || price < 0 || (price > 0 && price < 100) || (days && (!Number.isInteger(Number(days)) || Number(days) < 1 || Number(days) > 3650))) { toast('Enter a valid price and an access period from 1 to 3650 days.'); return; }
    button.disabled = true; button.textContent = 'Saving…'; const status = form.querySelector('.row-status'); status.textContent = '';
    try { await api('/admin/storefront/papers/'+encodeURIComponent(form.dataset.id),{price_paise:price,access_days:days ? Number(days) : null}); status.textContent = 'Saved. New purchases will use these settings.'; toast('Paper pricing saved.'); }
    catch (error) { status.textContent = error.message; }
    finally { button.disabled = false; button.textContent = 'Save'; }
  });
  if (!token()) { list.innerHTML = '<div class="notice">Sign in with a manager account to set paper prices. <a href="/login">Sign in</a></div>'; return; }
  api('/auth/me').then(data => {
    if (data.user?.role !== 'manager') { list.innerHTML = '<div class="notice">Only a manager can price, activate or deactivate papers. <a href="/dashboard">Return to dashboard</a></div>'; return; }
    verifiedManager = true; load();
  }).catch(error => { list.innerHTML = '<div class="notice">'+esc(error.message)+'</div>'; });
})();
