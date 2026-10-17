/* Navigation shared by standalone manager pages and the exam management view. */
(function () {
  'use strict';
  if (window.QLManagerShell) return;
  var sidebar, toggle, scrim, verifiedUser;
  var examPage = /^\/exams?(?:\/|$)/.test(location.pathname);
  var managerPage = /^\/manager\/(sales|discussions|announcements|reports|uploads)\/?$/.test(location.pathname);
  var links = [
    ['/manager','Dashboard','home'], ['/manager/analytics','Analytics','trend'],
    ['/manager/users','Users','users'], ['/manager/courses','Courses','book'],
    ['/manager/quizzes','Quizzes','paper'], ['/exams','Online Exams','test'],
    ['/manager/discussions','Discussions','chat'], ['/manager/sales','Paper Sales','inbox'],
    ['/manager/announcements','Announcements','bell'], ['/manager/reports','Reported questions','flag'],
    ['/manager/uploads','Student uploads','inbox'], ['/manager/ide-problems','IDE Problems','code'],
    ['/manager/video-solutions','Video Solutions','book'], ['/manager/settings','Settings','settings']
  ];
  var paths = {
    home:'m3 10 9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z',
    trend:'m3 17 6-6 4 4 8-11M15 4h6v6',
    users:'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M16 3a4 4 0 0 1 0 8M22 21v-2a4 4 0 0 0-3-3.9',
    book:'M12 5v16M3 3h5a4 4 0 0 1 4 2 4 4 0 0 1 4-2h5v16h-5a4 4 0 0 0-4 2 4 4 0 0 0-4-2H3z',
    paper:'M14 2H6v20h14V8zM14 2v6h6M9 12h8M9 16h6',
    test:'M9 3h6M10 3v6l-6 10a2 2 0 0 0 2 3h12a2 2 0 0 0 2-3L14 9V3',
    chat:'M21 3H3v15h5l4 4v-4h9z', inbox:'M3 4h18v16H3zM3 13h5l2 3h4l2-3h5',
    bell:'M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4',
    flag:'M5 22V3c5-4 9 4 14 0v12c-5 4-9-4-14 0',
    code:'m8 6-6 6 6 6m8-12 6 6-6 6m-3-15-2 18',
    settings:'M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1m8.6 8.6 2.1 2.1M5.6 18.4l2.1-2.1m8.6-8.6 2.1-2.1'
  };
  function icon(name) { return '<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="'+paths[name]+'"/>'+(name==='users'?'<circle cx="9" cy="7" r="4"/>':name==='settings'?'<circle cx="12" cy="12" r="5"/>':'')+'</svg>'; }
  function setOpen(open) {
    document.body.classList.toggle('ql-manager-drawer-open', open);
    if (toggle) toggle.setAttribute('aria-expanded', String(open));
    if (toggle) toggle.setAttribute('aria-label', open ? 'Close manager navigation' : 'Open manager navigation');
    if (sidebar) sidebar.inert = !open && matchMedia('(max-width: 1000px)').matches;
  }
  function mount() {
    if (sidebar || !document.body) return;
    sidebar = document.createElement('aside'); sidebar.id = 'ql-manager-sidebar';
    sidebar.setAttribute('aria-label','Manager sidebar');
    sidebar.innerHTML = '<a class="qm-brand" href="/manager"><img src="/assets/quiz-lab-icon.png" width="40" height="40" alt=""><span><strong>Quiz LAB</strong><small>by GenZ IITian</small></span></a><div class="qm-role">MANAGER</div><nav aria-label="Manager sections"></nav><div class="qm-bottom"><a class="qm-student" href="/dashboard">'+icon('users')+'<span>View as Student</span></a><a class="qm-home" href="/">'+icon('home')+'<span>Home page</span></a><div class="qm-account"><span class="qm-initial" aria-hidden="true"></span><span class="qm-name">Your account</span></div></div>';
    var nav = sidebar.querySelector('nav');
    links.forEach(function (item) {
      var link = document.createElement('a'); link.href = item[0];
      link.innerHTML = icon(item[2])+'<span>'+item[1]+'</span>';
      var active = item[0] === '/exams' ? examPage : location.pathname.replace(/\/$/,'') === item[0];
      if (active) link.setAttribute('aria-current','page');
      nav.appendChild(link);
    });
    scrim = document.createElement('button'); scrim.id='ql-manager-scrim'; scrim.type='button';
    scrim.setAttribute('aria-label','Close manager navigation'); scrim.tabIndex=-1;
    scrim.addEventListener('click', function () { setOpen(false); toggle.focus(); });
    toggle = document.createElement('button'); toggle.id='ql-manager-toggle'; toggle.type='button';
    toggle.setAttribute('aria-label','Open manager navigation'); toggle.setAttribute('aria-controls',sidebar.id); toggle.setAttribute('aria-expanded','false');
    toggle.innerHTML='<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16"/></svg>';
    toggle.addEventListener('click', function () { setOpen(!document.body.classList.contains('ql-manager-drawer-open')); });
    sidebar.addEventListener('click', function (event) { if (event.target.closest('a')) setOpen(false); });
    document.body.append(sidebar,scrim,toggle);
    document.addEventListener('keydown', function (event) {
      if (!document.body.classList.contains('ql-manager-drawer-open')) return;
      if (event.key==='Escape') { setOpen(false); toggle.focus(); }
      if (event.key==='Tab') {
        var controls=Array.from(sidebar.querySelectorAll('a')).concat([toggle]);
        var first=controls[0], last=controls[controls.length-1];
        if (event.shiftKey && (document.activeElement===first || !controls.includes(document.activeElement))) { event.preventDefault(); last.focus(); }
        else if (!event.shiftKey && (document.activeElement===last || !controls.includes(document.activeElement))) { event.preventDefault(); first.focus(); }
      }
    });
    window.addEventListener('resize', function () { setOpen(false); });
    setOpen(false);
    var user = verifiedUser;
    if (!user) { try { user=JSON.parse(localStorage.getItem('lab_user')||'null'); } catch (_) {} }
    var name = user && user.name || 'Your account';
    sidebar.querySelector('.qm-name').textContent=name;
    sidebar.querySelector('.qm-initial').textContent=name.trim().charAt(0).toUpperCase();
  }
  function update(user, screen) {
    if (user) verifiedUser=user;
    var enabled = managerPage || (examPage && user && user.role==='manager' && screen!=='room' && screen!=='rules');
    if (enabled) mount();
    document.body.classList.toggle('ql-manager-layout',!!enabled);
    if (sidebar) sidebar.hidden=!enabled;
    if (toggle) toggle.hidden=!enabled;
    if (!enabled) setOpen(false);
  }
  window.QLManagerShell = {update:update};
  function init() { update(verifiedUser || (document.body.dataset.qlExamRole==='manager'?{role:'manager'}:null), document.body.dataset.qlExamScreen); }
  if (document.readyState==='loading') document.addEventListener('DOMContentLoaded',init); else init();
})();
