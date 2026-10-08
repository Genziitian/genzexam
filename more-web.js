/* Student More page: bring the mobile account and support actions to web. */
(function () {
  'use strict';

  var API_FALLBACK = 'https://labapi.genziitian.in/public/api';
  var MORE_ID = 'ql-web-more-actions';
  var PHOTO_ID = 'ql-web-profile-photo';
  var profileRequest = null;
  var profileToken = '';
  var injectedStyle = false;

  function runtime() { return window.QLStorefront || {}; }
  function token() {
    try { return localStorage.getItem('lab_token') || ''; } catch (_) { return ''; }
  }
  function apiBase() { return runtime().apiBase || API_FALLBACK; }
  function api(path, options) {
    options = options || {};
    var headers = Object.assign({ Accept: 'application/json', Authorization: 'Bearer ' + token() }, options.headers || {});
    return fetch(apiBase() + path, Object.assign({}, options, { headers: headers })).then(function (response) {
      return response.json().catch(function () { return {}; }).then(function (body) {
        if (!response.ok) throw new Error(body.error || body.message || 'Something went wrong. Please try again.');
        return body;
      });
    });
  }
  function escapeHtml(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c];
    });
  }
  function addStyles() {
    if (injectedStyle) return;
    injectedStyle = true;
    var style = document.createElement('style');
    style.id = 'ql-web-more-styles';
    style.textContent = [
      '.ql-more-card{border:1px solid #e2e8f0;border-radius:18px;background:#fff;padding:20px;box-shadow:0 2px 8px rgba(15,23,42,.04)}',
      '.ql-more-heading{margin:0;color:#0f172a;font-size:18px;font-weight:800;letter-spacing:-.02em}',
      '.ql-more-subtitle{margin:5px 0 0;color:#64748b;font-size:13px;line-height:1.5}',
      '.ql-more-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin-top:16px}',
      '.ql-more-link{display:flex;align-items:center;gap:12px;min-width:0;padding:13px;border:1px solid #e2e8f0;border-radius:13px;color:#0f172a;text-decoration:none;background:#fff;transition:border-color .15s,background .15s}',
      '.ql-more-link:hover{border-color:#86efac;background:#f0fdf4}',
      '.ql-more-link strong{display:block;font-size:13px;font-weight:700}',
      '.ql-more-link small{display:block;margin-top:3px;color:#64748b;font-size:11px;line-height:1.4}',
      '.ql-more-icon{display:grid;place-items:center;flex:0 0 38px;height:38px;border-radius:11px;background:#f0fdf4;color:#15803d;font-size:18px}',
      '.ql-more-row{display:flex;align-items:center;justify-content:space-between;gap:14px;padding:13px 0;border-top:1px solid #f1f5f9}',
      '.ql-more-row:first-of-type{border-top:0}',
      '.ql-more-row-copy{min-width:0}.ql-more-row-copy strong{display:block;color:#0f172a;font-size:13px}.ql-more-row-copy small{display:block;margin-top:3px;color:#64748b;font-size:11px;line-height:1.4}',
      '.ql-more-button{border:1px solid #dbe3ee;border-radius:10px;padding:9px 12px;background:#fff;color:#334155;font:inherit;font-size:12px;font-weight:600;cursor:pointer;white-space:nowrap}',
      '.ql-more-button:hover{border-color:#86efac;background:#f0fdf4}',
      '.ql-more-button.primary{border-color:#16a34a;background:#16a34a;color:#fff}',
      '.ql-more-button.danger{border-color:#fecaca;background:#fff;color:#b91c1c}',
      '.ql-more-theme-options{display:flex;gap:7px;flex-wrap:wrap}',
      '.ql-more-theme-options button[aria-pressed=true]{border-color:#16a34a;background:#f0fdf4;color:#15803d}',
      '.ql-more-photo{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-top:16px}',
      '.ql-more-avatar{display:grid;place-items:center;width:66px;height:66px;overflow:hidden;border-radius:50%;border:2px solid #bbf7d0;background:#ecfdf5;color:#15803d;font-size:20px;font-weight:800}',
      '.ql-more-avatar img{width:100%;height:100%;object-fit:cover}',
      '.ql-more-photo-tools{display:flex;align-items:center;gap:8px;flex-wrap:wrap}',
      '.ql-more-profile-summary{display:flex;align-items:center;gap:14px;margin-top:14px}',
      '.ql-more-profile-summary .ql-more-avatar{width:58px;height:58px;font-size:18px;flex:0 0 auto}',
      '.ql-more-profile-meta{min-width:0;flex:1}.ql-more-profile-meta strong{display:block;color:#0f172a;font-size:16px}.ql-more-profile-meta small{display:block;margin-top:3px;color:#64748b;font-size:12px;overflow-wrap:anywhere}',
      '.ql-more-profile-dialog{width:min(560px,calc(100vw - 28px));max-height:min(90vh,820px);padding:0;border:0;border-radius:24px;background:#fff;color:#0f172a;box-shadow:0 24px 80px rgba(15,23,42,.3)}',
      '.ql-more-profile-dialog::backdrop{background:rgba(15,23,42,.55);backdrop-filter:blur(3px)}',
      '.ql-more-profile-content{max-height:min(90vh,820px);overflow:auto;padding:24px}',
      '.ql-more-profile-preview{display:grid;place-items:center;margin:18px 0 24px}',
      '.ql-more-preset-grid{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:10px;margin:10px 0 22px}',
      '.ql-more-preset{display:grid;place-items:center;aspect-ratio:1;border:3px solid transparent;border-radius:50%;font-size:25px;cursor:pointer;box-shadow:0 5px 14px rgba(15,23,42,.12)}',
      '.ql-more-preset[aria-pressed=true]{border-color:#16a34a;box-shadow:0 0 0 3px rgba(22,163,74,.14)}',
      '.ql-more-profile-content input{box-sizing:border-box;width:100%;border:1px solid #dbe3ee;border-radius:14px;padding:14px;background:#f8fafc;color:#0f172a;font:inherit;font-size:15px}',
      '.ql-more-profile-content input:focus{outline:2px solid #16a34a;outline-offset:1px}',
      '.ql-more-message{min-height:18px;margin:10px 0 0;font-size:12px;color:#64748b}',
      '.ql-more-message.error{color:#b91c1c}.ql-more-message.success{color:#15803d}',
      '.ql-more-form{display:grid;gap:12px;margin-top:14px}',
      '.ql-more-form label{display:grid;gap:6px;color:#475569;font-size:12px;font-weight:600}',
      '.ql-more-form select,.ql-more-form textarea{width:100%;box-sizing:border-box;border:1px solid #dbe3ee;border-radius:10px;padding:10px 12px;background:#fff;color:#0f172a;font:inherit;font-size:13px}',
      '.ql-more-form textarea{min-height:90px;resize:vertical}',
      '.ql-more-badges-preview:not(.expanded)>:nth-child(n+4){display:none!important}',
      '.ql-more-view-all{display:block;margin:14px auto 0;border:0;background:transparent;color:#16a34a;font:inherit;font-size:13px;font-weight:700;cursor:pointer}',
      '.ql-more-faq{margin-top:12px}.ql-more-faq details{border-top:1px solid #f1f5f9;padding:12px 0}.ql-more-faq summary{cursor:pointer;color:#0f172a;font-size:13px;font-weight:650}.ql-more-faq p{margin:8px 0 0;color:#64748b;font-size:12px;line-height:1.6}',
      '.ql-more-status{margin:12px 0 0;color:#64748b;font-size:12px}',
      '.ql-more-rulebook-dialog{width:min(640px,calc(100vw - 32px));max-height:min(82vh,760px);padding:0;border:1px solid #e2e8f0;border-radius:20px;background:#fff;color:#0f172a;box-shadow:0 24px 80px rgba(15,23,42,.28)}',
      '.ql-more-rulebook-dialog::backdrop{background:rgba(15,23,42,.55);backdrop-filter:blur(3px)}',
      '.ql-more-rulebook-content{max-height:min(82vh,760px);overflow:auto;padding:24px}',
      '.ql-more-delete-dialog{width:min(560px,calc(100vw - 28px));max-height:min(88vh,760px);padding:0;border:1px solid #e2e8f0;border-radius:22px;background:#fff;color:#0f172a;box-shadow:0 24px 80px rgba(15,23,42,.3)}',
      '.ql-more-delete-dialog::backdrop{background:rgba(15,23,42,.56);backdrop-filter:blur(3px)}',
      '.ql-more-delete-content{max-height:min(88vh,760px);overflow:auto;padding:24px}',
      '.ql-more-delete-actions{display:flex;justify-content:flex-end;gap:8px;flex-wrap:wrap}',
      '.ql-more-rulebook-content h3{margin:20px 0 8px;color:#0f172a;font-size:15px;font-weight:750}',
      '.ql-more-rulebook-content ul{margin:8px 0;padding-left:22px;color:#475569;font-size:13px;line-height:1.7}',
      '.ql-more-rulebook-content p{color:#475569;font-size:13px;line-height:1.65}',
      ':root[data-theme=dark] .ql-more-rulebook-dialog{background:#151a25;border-color:#2e3b4c;color:#e2e8f0}',
      ':root[data-theme=dark] .ql-more-delete-dialog{background:#151a25;border-color:#2e3b4c;color:#e2e8f0}',
      ':root[data-theme=dark] .ql-more-delete-content .ql-more-heading,:root[data-theme=dark] .ql-more-delete-content label{color:#e2e8f0}',
      ':root[data-theme=dark] .ql-more-rulebook-content h3{color:#e2e8f0}',
      ':root[data-theme=dark] .ql-more-rulebook-content ul,:root[data-theme=dark] .ql-more-rulebook-content p{color:#aeb8c8}',
      ':root[data-theme=dark] .ql-more-card,:root[data-theme=dark] .ql-more-link{background:#151a25;border-color:#2e3b4c;color:#d6dae5}',
      ':root[data-theme=dark] .ql-more-heading,:root[data-theme=dark] .ql-more-row-copy strong,:root[data-theme=dark] .ql-more-faq summary{color:#e2e8f0}',
      ':root[data-theme=dark] .ql-more-subtitle,:root[data-theme=dark] .ql-more-link small,:root[data-theme=dark] .ql-more-row-copy small,:root[data-theme=dark] .ql-more-faq p{color:#9ea9b9}',
      ':root[data-theme=dark] .ql-more-form select,:root[data-theme=dark] .ql-more-form textarea,:root[data-theme=dark] .ql-more-button{background:#111722;border-color:#2e3b4c;color:#d6dae5}',
      ':root[data-theme=dark] .ql-more-theme-options button[aria-pressed=true]{background:#1f2e23;border-color:#16a34a;color:#59d78b}',
      '@media(max-width:640px){.ql-more-card{padding:16px;border-radius:16px}.ql-more-grid{grid-template-columns:1fr}.ql-more-row{align-items:flex-start;flex-direction:column}.ql-more-theme-options{width:100%}.ql-more-theme-options .ql-more-button{flex:1}.ql-more-profile-content{padding:20px}.ql-more-preset-grid{gap:8px}.ql-more-preset{font-size:22px}}'
    ].join('');
    document.head.appendChild(style);
  }

  function badgeGrid(page) {
    var headings = page.querySelectorAll('h2');
    for (var i = 0; i < headings.length; i++) {
      if (headings[i].textContent.trim().toLowerCase() !== 'badges') continue;
      var ancestor = headings[i];
      for (var depth = 0; depth < 6 && ancestor; depth++, ancestor = ancestor.parentElement) {
        var grids = ancestor.querySelectorAll('div.grid');
        for (var g = 0; g < grids.length; g++) if (grids[g].children.length > 3) return grids[g];
      }
    }
    return null;
  }
  function compactBadges(page) {
    var grid = badgeGrid(page);
    if (!grid) return;
    grid.classList.add('ql-more-badges-preview');
    var button = grid.nextElementSibling;
    if (!button || !button.classList.contains('ql-more-view-all')) {
      button = document.createElement('button');
      button.type = 'button';
      button.className = 'ql-more-view-all';
      button.textContent = 'View all badges';
      grid.insertAdjacentElement('afterend', button);
      button.addEventListener('click', function () {
        var expanded = grid.classList.toggle('expanded');
        button.textContent = expanded ? 'Show fewer badges' : 'View all badges';
      });
    }
  }
  function renameProfileNav() {
    document.querySelectorAll('#root a[href="/profile"],#root button').forEach(function (item) {
      if (!item.children.length && item.textContent.trim() === 'Profile') item.textContent = 'More';
      if (item.tagName === 'A' && item.getAttribute('href') === '/profile') {
        var last = item.lastElementChild;
        if (last && !last.children.length && last.textContent.trim() === 'Profile') last.textContent = 'More';
      }
    });
    document.querySelectorAll('#root h1').forEach(function (heading) {
      if (heading.textContent.trim() === 'My Profile') heading.textContent = 'More';
    });
  }
  function profilePage() {
    if (!/^\/profile\/?$/i.test(location.pathname)) return null;
    return document.querySelector('#root main .page-enter > div') || document.querySelector('#root main .page-enter');
  }
  function removeDuplicateProfileBlocks(page) {
    if (!page) return;
    var nameForms = page.querySelectorAll('form');
    nameForms.forEach(function (form) {
      if (!/Full Name/i.test(form.textContent || '')) return;
      var card = form.closest('.rounded-2xl');
      if (card && !card.id) card.remove();
    });
    page.querySelectorAll('.rounded-2xl').forEach(function (card) {
      if (card.id || !/\bEdit\b/.test(card.textContent || '')) return;
      var heading = card.querySelector('h1,h2,h3');
      var hasEmail = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i.test(card.textContent || '');
      if (heading && heading.textContent.trim() === 'Profile' && hasEmail) card.remove();
    });
    var oldPhotoCard = page.querySelector('#' + PHOTO_ID);
    if (oldPhotoCard) oldPhotoCard.remove();
  }
  function profileData() {
    var current = token();
    if (!current) return Promise.reject(new Error('Please sign in again to load your account details.'));
    if (!profileRequest || profileToken !== current) {
      profileToken = current;
      profileRequest = api('/student/profile').then(function (data) { return data || {}; }).catch(function (error) {
        profileRequest = null;
        throw error;
      });
    }
    return profileRequest;
  }
  function avatarUrl(value) {
    if (!value) return '';
    try { return new URL(value, new URL(apiBase()).origin).href; } catch (_) { return value; }
  }
  function renderAvatar(box, user) {
    if (!box) return;
    box.style.background = '';
    box.style.color = '';
    box.style.fontSize = '';
    box.replaceChildren();
    if (user && user.avatar) {
      var image = document.createElement('img');
      image.alt = 'Profile photo';
      image.src = avatarUrl(user.avatar);
      box.appendChild(image);
    } else {
      var initials = (user && user.name || 'Student').trim().split(/\s+/).map(function (part) { return part.charAt(0); }).join('').slice(0, 2).toUpperCase();
      box.textContent = initials || 'S';
    }
  }
  var avatarPresets = [
    ['🦊','#fdbA74','#ea580c'],['🐼','#e2e8f0','#64748b'],['🦁','#fde68a','#d97706'],['🐯','#fed7aa','#c2410c'],['🐸','#bbf7d0','#16a34a'],['🦉','#ddd6fe','#6d28d9'],['🐙','#fbcfe8','#db2777'],['🐬','#bae6fd','#0284c7'],['🚀','#c7d2fe','#4338ca'],['⚡','#fef08a','#ca8a04'],['🎯','#fecaca','#dc2626'],['🧠','#f5d0fe','#a21caf']
  ];
  function presetKey(user) { return 'ql_avatar_preset_' + String(user && (user.id || user.email) || 'student'); }
  function savedPreset(user) {
    try { var value = localStorage.getItem(presetKey(user)); return value === null ? null : Number(value); } catch (_) { return null; }
  }
  function applyPreset(box, user, preset) {
    if (!box) return;
    if (preset === null || !avatarPresets[preset]) { renderAvatar(box, user); return; }
    var item = avatarPresets[preset];
    box.replaceChildren();
    box.textContent = item[0];
    box.style.background = 'linear-gradient(145deg,' + item[1] + ',' + item[2] + ')';
    box.style.color = '#fff';
    box.style.fontSize = '34px';
  }
  function ensureProfileEditor(page) {
    if (document.getElementById('ql-web-profile-editor')) return;
    var card = document.createElement('section');
    card.id = 'ql-web-profile-editor';
    card.className = 'ql-more-card';
    card.innerHTML = '<h2 class="ql-more-heading">Profile</h2><div class="ql-more-profile-summary"><div class="ql-more-avatar" id="ql-web-profile-avatar"></div><div class="ql-more-profile-meta"><strong id="ql-web-profile-name">Loading profile…</strong><small id="ql-web-profile-email"></small></div><button type="button" class="ql-more-button" id="ql-web-profile-edit">Edit</button></div><p class="ql-more-message" id="ql-web-profile-message" role="status"></p>';
    page.prepend(card);
    var avatar = card.querySelector('#ql-web-profile-avatar');
    var name = card.querySelector('#ql-web-profile-name');
    var email = card.querySelector('#ql-web-profile-email');
    var message = card.querySelector('#ql-web-profile-message');
    var user = null;
    function show() {
      if (!user) return;
      name.textContent = user.name || 'Student';
      email.textContent = user.email || '';
      applyPreset(avatar, user, savedPreset(user));
    }
    profileData().then(function (data) { user = data.user || {}; show(); }).catch(function (error) { message.textContent = error.message || 'Could not load your profile.'; message.classList.add('error'); });
    card.querySelector('#ql-web-profile-edit').addEventListener('click', function () {
      if (!user) return;
      var choice = savedPreset(user);
      var dialog = document.createElement('dialog');
      dialog.className = 'ql-more-profile-dialog';
      var fullName = user.name || '';
      var initials = document.createElement('button');
      initials.type = 'button';
      initials.className = 'ql-more-preset';
      initials.style.cssText = 'background:#ecfdf5;color:#15803d;border-color:#86efac;font-size:17px;font-weight:800';
      initials.textContent = (fullName.trim().split(/\s+/).map(function (part) { return part.charAt(0); }).join('').slice(0,2) || 'S').toUpperCase();
      initials.dataset.index = 'initials';
      var options = [initials].concat(avatarPresets.map(function (item, index) {
        var button = document.createElement('button'); button.type = 'button'; button.className = 'ql-more-preset'; button.textContent = item[0]; button.dataset.index = String(index); button.style.background = 'linear-gradient(145deg,' + item[1] + ',' + item[2] + ')'; button.setAttribute('aria-label', item[0]); return button;
      }));
      dialog.innerHTML = '<div class="ql-more-profile-content"><button type="button" class="ql-more-button" data-close style="float:right">Close</button><h2 class="ql-more-heading">Edit profile</h2><div class="ql-more-profile-preview"><div class="ql-more-avatar" id="ql-edit-preview" style="width:84px;height:84px;font-size:34px"></div></div><label class="ql-more-subtitle" style="font-weight:700;letter-spacing:1.4px">CHOOSE AN AVATAR</label><div class="ql-more-preset-grid" id="ql-edit-presets"></div><label class="ql-more-subtitle" for="ql-edit-name" style="font-weight:700;letter-spacing:1.4px">YOUR NAME</label><input id="ql-edit-name" maxlength="120" autocomplete="name"><p class="ql-more-message" id="ql-edit-message" role="status"></p><button type="button" class="ql-more-button primary" id="ql-edit-save" style="width:100%;padding:14px;margin-top:14px">Save changes</button></div>';
      document.body.appendChild(dialog);
      var preview = dialog.querySelector('#ql-edit-preview');
      var input = dialog.querySelector('#ql-edit-name'); input.value = fullName;
      var grid = dialog.querySelector('#ql-edit-presets'); options.forEach(function (button) { grid.appendChild(button); });
      var status = dialog.querySelector('#ql-edit-message');
      function previewChoice() {
        options.forEach(function (button) { button.setAttribute('aria-pressed', String((choice === null && button.dataset.index === 'initials') || String(choice) === button.dataset.index)); });
        var selectedName = input.value.trim() || 'Student';
        if (choice === null) { renderAvatar(preview, { name: selectedName }); preview.style.width='84px'; preview.style.height='84px'; }
        else applyPreset(preview, { name: selectedName }, choice);
      }
      options.forEach(function (button) { button.addEventListener('click', function () { choice = button.dataset.index === 'initials' ? null : Number(button.dataset.index); previewChoice(); }); });
      input.addEventListener('input', previewChoice); previewChoice();
      dialog.querySelector('[data-close]').addEventListener('click', function () { dialog.close(); });
      dialog.addEventListener('click', function (event) { if (event.target === dialog) dialog.close(); });
      dialog.addEventListener('close', function () { dialog.remove(); });
      dialog.querySelector('#ql-edit-save').addEventListener('click', function () {
        var nextName = input.value.trim();
        if (!nextName) { status.textContent = 'Name cannot be empty.'; status.classList.add('error'); return; }
        var button = dialog.querySelector('#ql-edit-save'); button.disabled = true; button.textContent = 'Saving…';
        api('/student/profile', { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: nextName }) }).then(function (data) {
          user = Object.assign({}, user, data.user || {}, { name: nextName });
          try { if (choice === null) localStorage.removeItem(presetKey(user)); else localStorage.setItem(presetKey(user), String(choice)); } catch (_) {}
          try { var saved = JSON.parse(localStorage.getItem('lab_user') || '{}'); localStorage.setItem('lab_user', JSON.stringify(Object.assign(saved, user))); } catch (_) {}
          show(); message.textContent = 'Profile updated.'; message.className = 'ql-more-message success'; dialog.close();
        }).catch(function (error) { status.textContent = error.message || 'Could not save your profile.'; status.className = 'ql-more-message error'; button.disabled = false; button.textContent = 'Save changes'; });
      });
      dialog.showModal();
    });
  }
  function ensurePhotoCard(page) {
    var existing = document.getElementById(PHOTO_ID);
    if (existing) return;
    var card = document.createElement('section');
    card.id = PHOTO_ID;
    card.className = 'ql-more-card';
    card.innerHTML = '<h2 class="ql-more-heading">Profile photo</h2><p class="ql-more-subtitle">Use the same account photo across your Quiz LAB profile.</p><div class="ql-more-photo"><div class="ql-more-avatar" id="ql-more-avatar" aria-label="Profile photo"></div><div class="ql-more-photo-tools"><label class="ql-more-button" for="ql-more-photo-file">Choose photo</label><input id="ql-more-photo-file" type="file" accept="image/jpeg,image/png,image/webp" hidden><button class="ql-more-button danger" id="ql-more-photo-remove" type="button">Remove photo</button><button class="ql-more-button primary" id="ql-more-photo-save" type="button">Save photo</button></div></div><p class="ql-more-message" id="ql-more-photo-message" role="status"></p>';
    page.appendChild(card);
    var currentUser = null;
    var fileInput = card.querySelector('#ql-more-photo-file');
    var avatar = card.querySelector('#ql-more-avatar');
    var message = card.querySelector('#ql-more-photo-message');
    var selectedFile = null;
    var removePhoto = false;
    var saveButton = card.querySelector('#ql-more-photo-save');
    var removeButton = card.querySelector('#ql-more-photo-remove');
    function say(text, type) {
      message.textContent = text;
      message.className = 'ql-more-message' + (type ? ' ' + type : '');
    }
    fileInput.addEventListener('change', function () {
      selectedFile = fileInput.files && fileInput.files[0] || null;
      removePhoto = false;
      if (selectedFile && selectedFile.size > 2 * 1024 * 1024) {
        selectedFile = null;
        fileInput.value = '';
        say('Choose an image under 2 MB.', 'error');
        return;
      }
      if (selectedFile) {
        var preview = URL.createObjectURL(selectedFile);
        avatar.innerHTML = '<img alt="Selected profile photo">';
        avatar.querySelector('img').src = preview;
        say('Photo ready. Select Save photo to update your profile.');
      }
    });
    removeButton.addEventListener('click', function () {
      if (!currentUser || !currentUser.avatar) return say('There is no profile photo to remove.');
      selectedFile = null;
      fileInput.value = '';
      removePhoto = true;
      renderAvatar(avatar, Object.assign({}, currentUser, { avatar: null }));
      say('Photo will be removed when you save.');
    });
    saveButton.addEventListener('click', function () {
      if (!selectedFile && !removePhoto) return say('Choose a photo or select Remove photo first.');
      var form = new FormData();
      form.append('_method', 'PATCH');
      if (selectedFile) form.append('avatar', selectedFile);
      if (removePhoto) form.append('remove_avatar', '1');
      saveButton.disabled = true;
      say('Saving…');
      api('/student/profile', { method: 'POST', body: form }).then(function (data) {
        currentUser = data.user || currentUser || {};
        renderAvatar(avatar, currentUser);
        try {
          var saved = JSON.parse(localStorage.getItem('lab_user') || '{}');
          localStorage.setItem('lab_user', JSON.stringify(Object.assign(saved, currentUser)));
        } catch (_) {}
        selectedFile = null;
        removePhoto = false;
        fileInput.value = '';
        say('Profile photo updated.', 'success');
      }).catch(function (error) { say(error.message || 'Could not update your photo.', 'error'); }).finally(function () { saveButton.disabled = false; });
    });
    profileData().then(function (data) {
      currentUser = data.user || {};
      renderAvatar(avatar, currentUser);
      removeButton.disabled = !currentUser.avatar;
    }).catch(function (error) { say(error.message || 'Could not load your profile.', 'error'); });
  }
  function applyTheme(value) {
    try {
      if (value === 'system') {
        localStorage.removeItem('ql_theme');
        var system = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
        document.documentElement.setAttribute('data-theme', system);
        window.dispatchEvent(new CustomEvent('ql-theme', { detail: system }));
      } else if (window.qlTheme) window.qlTheme.set(value);
      else { localStorage.setItem('ql_theme', value); document.documentElement.setAttribute('data-theme', value); }
    } catch (_) {}
  }
  function actionMarkup() {
    var faqs = [
      ['How do I sign in?', 'Use Continue with Google or the email and password for your Quiz LAB account.'],
      ['I forgot my password. What do I do?', 'Use Forgot password on the sign-in page and follow the email OTP steps.'],
      ['How do I change my name or avatar?', 'Open the profile editor at the top of this page, enter your name, choose an avatar, and save your changes.'],
      ['Why did I get signed out?', 'Signing in on another device or browser can end an older session. Sign in again; your papers, scores, and XP remain on your account.'],
      ['How do I request account deletion?', 'Choose Delete Account & Data below, select a reason, and submit the request for manager review. Your account remains active until the request is processed.'],
      ['Where do my attempted papers appear?', 'Papers you bought or attempted appear in My Papers with your latest score and attempt status.'],
      ['Do I need to claim free papers?', 'No. Free papers open from Practice. Once you start one, it appears in My Papers.'],
      ['Can I attempt a paper more than once?', 'Yes. Retakes earn half the XP of a first attempt.'],
      ['What happens if I leave a paper in progress?', 'Your attempt is saved to your account and you can return to it from My Papers. Timed papers keep their timer running.'],
      ['How do XP, levels and badges work?', 'Your total XP sets your level, and your level unlocks badges. Open the progress guide below for XP rules and badge levels.'],
      ['How is the leaderboard ranked?', 'Students are ranked by total XP. Open Ranks to see your current place.'],
      ['What is the weekly goal?', 'It is your target number of quizzes to finish from Monday through Sunday. Update it in Settings.'],
      ['What are Video Solutions?', 'Step-by-step answers for selected papers. Some videos require Pro access.'],
      ['How do I turn on dark mode?', 'Choose System, Light, or Dark under Theme / Appearance on this page.'],
      ['How do I contact support?', 'Email admin@genziitian.org, call +91 72549 26179, or message us on WhatsApp.']
    ];
    return '<div id="' + MORE_ID + '" class="space-y-4">' +
      '<section class="ql-more-card"><h2 class="ql-more-heading">XP, levels and badges</h2><p class="ql-more-subtitle">See how your learning activity builds XP and unlocks badges.</p><button type="button" id="ql-more-rulebook" class="ql-more-button" style="margin-top:14px">How do XP, levels and badges work?</button></section>' +
      '<section class="ql-more-card"><h2 class="ql-more-heading">Account &amp; preferences</h2><p class="ql-more-subtitle">Personalize the app and manage your account.</p>' +
      '<div class="ql-more-row"><div class="ql-more-row-copy"><strong>Theme / Appearance</strong><small>Choose System, Light, or Dark mode.</small></div><div class="ql-more-theme-options" role="group" aria-label="Theme"><button type="button" class="ql-more-button" data-ql-more-theme="system">System</button><button type="button" class="ql-more-button" data-ql-more-theme="light">Light</button><button type="button" class="ql-more-button" data-ql-more-theme="dark">Dark</button></div></div>' +
      '<a class="ql-more-link" href="/settings"><span class="ql-more-icon">⚙</span><span><strong>Password &amp; weekly goal</strong><small>Open Settings to update account security and your goal.</small></span></a>' +
      '<div class="ql-more-row"><div class="ql-more-row-copy"><strong>Help &amp; Support Desk</strong><small>Email admin@genziitian.org or call +91 72549 26179.</small></div><div class="ql-more-theme-options"><a class="ql-more-button" href="mailto:admin@genziitian.org?subject=Quiz%20Lab%20app%3A%20help%20needed">Email us</a><a class="ql-more-button" href="https://wa.me/917254926179" target="_blank" rel="noopener">WhatsApp</a><a class="ql-more-button" href="tel:+917254926179">Call</a></div></div>' +
      '<div class="ql-more-faq"><h3 class="ql-more-heading" style="font-size:15px">FAQs</h3><label class="ql-more-form" style="margin-top:10px"><span>Search FAQs</span><input id="ql-more-faq-search" type="search" placeholder="Search a question" style="width:100%;box-sizing:border-box;border:1px solid #dbe3ee;border-radius:10px;padding:10px 12px;background:#fff;color:#0f172a;font:inherit"></label>' + faqs.map(function (item) { return '<details data-ql-more-faq><summary>' + escapeHtml(item[0]) + '</summary><p>' + escapeHtml(item[1]) + '</p></details>'; }).join('') + '</div></section>' +
      '<section class="ql-more-card"><h2 class="ql-more-heading">Account &amp; data</h2><p class="ql-more-subtitle">Manage your account data and deletion requests.</p>' +
      '<div class="ql-more-row"><div class="ql-more-row-copy"><strong>Delete Account &amp; Data</strong><small>Send a deletion request for manager review. Your account stays active until processed.</small></div><button type="button" id="ql-more-delete-toggle" class="ql-more-button danger">Request deletion</button></div></section>' +
      '<section class="ql-more-card"><div class="ql-more-row" style="padding:0;border:0"><div class="ql-more-row-copy"><strong>Sign Out</strong><small>You’ll be asked to confirm before your session ends.</small></div><button type="button" id="ql-more-signout" class="ql-more-button danger">Sign Out</button></div></section>' +
      '<p class="ql-more-subtitle" style="text-align:center;padding:4px 0 16px">QUIZ LAB · v1.0.0 · Android package in.genziitian.quizlab</p></div>';
  }
  function bindMore(card) {
    card.querySelectorAll('[data-ql-more-theme]').forEach(function (button) {
      var theme = button.getAttribute('data-ql-more-theme');
      var current = localStorage.getItem('ql_theme') || 'system';
      button.setAttribute('aria-pressed', String(theme === current));
      button.addEventListener('click', function () {
        applyTheme(theme);
        card.querySelectorAll('[data-ql-more-theme]').forEach(function (other) { other.setAttribute('aria-pressed', String(other === button)); });
      });
    });
    var faqSearch = card.querySelector('#ql-more-faq-search');
    faqSearch.addEventListener('input', function () {
      var query = faqSearch.value.trim().toLowerCase();
      card.querySelectorAll('[data-ql-more-faq]').forEach(function (faq) {
        faq.hidden = query && faq.textContent.toLowerCase().indexOf(query) < 0;
      });
    });
    card.querySelector('#ql-more-rulebook').addEventListener('click', function () {
      var dialog = document.createElement('dialog');
      dialog.className = 'ql-more-rulebook-dialog';
      dialog.innerHTML = '<div class="ql-more-rulebook-content"><button type="button" class="ql-more-button" data-close style="float:right">Close</button><h2 class="ql-more-heading">How XP, levels and badges work</h2><p class="ql-more-subtitle">Your total XP sets your level. Your level unlocks badges automatically.</p><h3>How you earn XP</h3><ul><li>Finish a paper for the first time: 5–25 XP. You get 5 XP for finishing, plus 1 XP for every 5% scored.</li><li>Repeat the same paper: half the XP the same score would earn on the first attempt, minimum 1 XP.</li><li>Daily bonus: +10 XP for your first finished paper or accepted coding solution of the day.</li><li>Accepted coding solution: Easy 20 XP, Medium 40 XP, Hard 80 XP, counted the first time accepted.</li><li>Accepted discussion answer: +50 XP. Each upvote you receive: +2 XP.</li></ul><h3>How levels and badges work</h3><p>There are 50 levels. To reach a level, you need 50 × level × level total XP. Badges unlock at levels 1, 5, 10, 15, 20, 25, 30, 35, 40, 45 and 50. Everyone starts with Newcomer; badges cannot be bought.</p><h3>When XP is taken back</h3><p>Removed upvotes take back their 2 XP. If an accepted answer changes or is unaccepted, its 50 XP is removed. XP from completed papers and coding problems is never taken back.</p></div>';
      document.body.appendChild(dialog);
      dialog.addEventListener('click', function (event) { if (event.target === dialog || event.target.closest('[data-close]')) dialog.close(); });
      dialog.addEventListener('close', function () { dialog.remove(); });
      dialog.showModal();
    });
    var toggle = card.querySelector('#ql-more-delete-toggle');
    var sent = false;
    toggle.addEventListener('click', function () {
      var dialog = document.createElement('dialog');
      dialog.className = 'ql-more-delete-dialog';
      dialog.innerHTML = '<div class="ql-more-delete-content"><div class="ql-more-row" style="padding-top:0;border:0"><h2 class="ql-more-heading">Request account deletion</h2><button type="button" class="ql-more-button" data-close>Close</button></div><p class="ql-more-subtitle" id="ql-more-delete-identity">Loading your account details…</p><form id="ql-more-delete-form" class="ql-more-form"><label>Reason for leaving<select id="ql-more-delete-reason" required><option value="">Choose a reason</option><option value="no_longer_needed">I no longer need the account</option><option value="privacy_concerns">Privacy concerns</option><option value="another_account">I am using another account</option><option value="app_issue">I had an issue with the app</option><option value="other">Other</option></select></label><label>Anything else you want us to know (optional)<textarea id="ql-more-delete-details" maxlength="1200"></textarea></label><p class="ql-more-subtitle">Your account stays active while the manager reviews your request.</p><div class="ql-more-delete-actions"><button type="button" class="ql-more-button" data-close>Cancel</button><button type="submit" class="ql-more-button danger">Send deletion request</button></div><p id="ql-more-delete-message" class="ql-more-message" role="status" aria-live="polite"></p></form></div>';
      document.body.appendChild(dialog);
      var identity = dialog.querySelector('#ql-more-delete-identity');
      profileData().then(function (data) {
        var user = data.user || {};
        identity.textContent = 'Request for ' + (user.name || 'your account') + ' · ' + (user.email || '');
      }).catch(function (error) { identity.textContent = error.message || 'Could not load your account details.'; });
      dialog.querySelectorAll('[data-close]').forEach(function (button) { button.addEventListener('click', function () { dialog.close(); }); });
      dialog.addEventListener('click', function (event) { if (event.target === dialog) dialog.close(); });
      dialog.addEventListener('close', function () { dialog.remove(); });
      var form = dialog.querySelector('#ql-more-delete-form');
      form.addEventListener('submit', function (event) {
        event.preventDefault();
        var reason = dialog.querySelector('#ql-more-delete-reason').value;
        var details = dialog.querySelector('#ql-more-delete-details').value.trim();
        var message = dialog.querySelector('#ql-more-delete-message');
        var submit = form.querySelector('[type=submit]');
        if (!reason) { message.textContent = 'Choose a reason before sending.'; message.className = 'ql-more-message error'; return; }
        submit.disabled = true;
        message.textContent = 'Sending request…';
        api('/auth/account-deletion-requests', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ reason: reason, details: details }) }).then(function (data) {
          sent = true;
          message.textContent = data.message || 'Your request was sent to the manager for review.';
          message.className = 'ql-more-message success';
          form.querySelectorAll('select,textarea,button').forEach(function (field) { field.disabled = true; });
          toggle.textContent = 'Request sent';
          toggle.disabled = true;
        }).catch(function (error) { message.textContent = error.message || 'Could not send the request. Please try again.'; message.className = 'ql-more-message error'; }).finally(function () { submit.disabled = sent; });
      });
      dialog.showModal();
    });
    card.querySelector('#ql-more-signout').addEventListener('click', function () { signOut(); });
  }
  function signOut() {
    if (!window.confirm('Sign out of Quiz LAB?')) return;
    if (!window.confirm('Confirm sign out. Are you sure you want to sign out now?')) return;
    var bearer = token();
    fetch(apiBase() + '/auth/logout', { method: 'POST', headers: { Accept: 'application/json', Authorization: 'Bearer ' + bearer } }).catch(function () {}).finally(function () {
      try { localStorage.removeItem('lab_token'); localStorage.removeItem('lab_user'); } catch (_) {}
      location.assign('/login');
    });
  }
  function interceptSignOut(event) {
    var button = event.target && event.target.closest && event.target.closest('button');
    if (!button || button.id === 'ql-more-signout') return;
    if (!/^sign\s*out$/i.test(button.textContent.trim())) return;
    event.preventDefault();
    event.stopPropagation();
    if (event.stopImmediatePropagation) event.stopImmediatePropagation();
    signOut();
  }
  function ensureMore() {
    if (!/^\/profile\/?$/i.test(location.pathname)) return;
    addStyles();
    renameProfileNav();
    var page = profilePage();
    if (!page) return;
    compactBadges(page);
    removeDuplicateProfileBlocks(page);
    ensureProfileEditor(page);
    if (document.getElementById(MORE_ID)) return;
    var host = document.createElement('div');
    host.innerHTML = actionMarkup();
    var actions = host.firstElementChild;
    page.appendChild(actions);
    bindMore(actions);
  }
  document.addEventListener('click', interceptSignOut, true);
  var scheduled = false;
  function schedule() {
    if (scheduled) return;
    scheduled = true;
    setTimeout(function () { scheduled = false; ensureMore(); }, 120);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', schedule);
  else schedule();
  new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
  window.addEventListener('popstate', schedule);
  var lastPath = location.pathname;
  setInterval(function () { if (location.pathname !== lastPath) { lastPath = location.pathname; schedule(); } }, 500);
})();
