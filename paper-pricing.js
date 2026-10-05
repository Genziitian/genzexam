(function () {
  'use strict';
  const API = window.QLStorefront?.apiBase || 'https://labapi.genziitian.in/public/api';
  const list = document.getElementById('list');
  let timer;
  function token() { try { return localStorage.getItem('lab_token') || ''; } catch { return ''; } }
  function role() { try { return JSON.parse(localStorage.getItem('lab_user') || '{}').role || ''; } catch { return ''; } }
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
    list.innerHTML = rows.length ? rows.map(p => `<form class="row" data-id="${esc(p.id)}"><div class="paper-summary"><strong>${esc(p.title)}</strong><small>${esc(p.course?.name || '')}${p.year ? ' · '+esc(p.year) : ''} · ${esc(p.section)}</small></div><label><span>Price (₹)</span><input type="number" min="0" step="0.01" value="${Number(p.price_paise || 0)/100}" name="price" required inputmode="decimal"></label><label><span>Access days</span><input type="number" min="1" max="3650" step="1" value="${p.access_days || ''}" name="days" placeholder="No expiry" inputmode="numeric"></label><button class="save" type="submit">Save</button><p class="row-status" role="status" aria-live="polite"></p></form>`).join('') : '<div class="notice">No published papers available yet. Publish a paper in the quiz manager to list it here.</div>';
  }
  async function load() {
    list.innerHTML = '<div class="notice">Loading published papers…</div>';
    try { const data = await api('/storefront/papers'); render(data.papers || []); }
    catch (error) { list.innerHTML = `<div class="notice">${esc(error.message)} <button class="save" id="retry">Try again</button></div>`; document.getElementById('retry').onclick = load; }
  }
  list.addEventListener('submit',async event => {
    const form = event.target.closest('form[data-id]'); if (!form) return; event.preventDefault();
    const button = form.querySelector('button'); if (button.disabled || !form.reportValidity()) return;
    const price = Math.round(Number(form.elements.price.value)*100), days = form.elements.days.value;
    if (!Number.isSafeInteger(price) || price < 0 || (days && (!Number.isInteger(Number(days)) || Number(days) < 1 || Number(days) > 3650))) { toast('Enter a valid price and an access period from 1 to 3650 days.'); return; }
    button.disabled = true; button.textContent = 'Saving…'; const status = form.querySelector('.row-status'); status.textContent = '';
    try { await api('/admin/storefront/papers/'+encodeURIComponent(form.dataset.id),{price_paise:price,access_days:days ? Number(days) : null}); status.textContent = 'Saved. New purchases will use these settings.'; toast('Paper pricing saved.'); }
    catch (error) { status.textContent = error.message; }
    finally { button.disabled = false; button.textContent = 'Save'; }
  });
  if (!token()) { list.innerHTML = '<div class="notice">Sign in with a manager account to set paper prices. <a href="/login">Sign in</a></div>'; return; }
  if (role() !== 'manager') { list.innerHTML = '<div class="notice">Only a manager can change paper prices. <a href="/dashboard">Return to dashboard</a></div>'; return; }
  load();
})();
