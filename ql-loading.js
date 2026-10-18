/* Shared waiting feedback for the public pages, student app and manager tools. */
(function () {
  'use strict';
  if (window.QLLoading) return;
  var tasks = new Map(), sequence = 0, modal, activity, style, previousFocus;
  var delay = 180;

  function mount() {
    if (!document.body) return false;
    if (!style) {
      style = document.getElementById('ql-loading-styles');
      if (!style) {
        style = document.createElement('link'); style.id = 'ql-loading-styles';
        style.rel = 'stylesheet'; style.href = '/ql-loading.css?v=20261017b';
        document.head.appendChild(style);
      }
    }
    if (!modal) {
      modal = document.createElement('dialog');
      modal.id = 'ql-loading-modal';
      modal.setAttribute('aria-labelledby', 'ql-loading-title');
      modal.setAttribute('aria-describedby', 'ql-loading-description');
      modal.innerHTML = '<span class="ql-loading-spinner" aria-hidden="true"></span><h2 id="ql-loading-title" role="status" aria-live="polite"></h2><p id="ql-loading-description"></p><button type="button">Keep browsing</button>';
      modal.addEventListener('cancel', function (event) { event.preventDefault(); minimize(); });
      modal.querySelector('button').addEventListener('click', minimize);
      document.body.appendChild(modal);
      activity = document.createElement('div');
      activity.id = 'ql-loading-activity'; activity.hidden = true;
      activity.setAttribute('role', 'status'); activity.setAttribute('aria-live', 'polite');
      activity.innerHTML = '<span class="ql-loading-spinner" aria-hidden="true"></span><span></span>';
      document.body.appendChild(activity);
    }
    return true;
  }
  function minimize() {
    tasks.forEach(function (task) { task.minimized = true; });
    render();
  }
  function closeModal() {
    if (!modal || !modal.open) return;
    modal.close();
    if (previousFocus && previousFocus.isConnected && typeof previousFocus.focus === 'function') previousFocus.focus({preventScroll:true});
    previousFocus = null;
  }
  function render() {
    var ready = Array.from(tasks.values()).filter(function (task) { return task.ready; });
    if (!ready.length) {
      closeModal();
      if (activity) activity.hidden = true;
      return;
    }
    if (!mount()) return;
    var blocking = ready.filter(function (task) { return task.blocking && !task.minimized; });
    var task = (blocking.length ? blocking : ready).slice(-1)[0];
    var label = task.label;
    if (ready.length > 1) label += ' (' + ready.length + ' tasks)';
    if (blocking.length && typeof modal.showModal === 'function') {
      activity.hidden = true;
      modal.querySelector('h2').textContent = label;
      modal.querySelector('p').textContent = task.slow ? 'This is taking longer than usual. We are still waiting for it to finish.' : 'Please wait while we finish this step.';
      if (!modal.open) { previousFocus = document.activeElement; modal.showModal(); }
    } else {
      closeModal();
      activity.querySelector('span:last-child').textContent = label + (task.slow ? ' — still working…' : '');
      activity.hidden = false;
    }
  }
  function begin(label, options) {
    options = options || {};
    var id = ++sequence;
    var task = {label:label || 'Working…', blocking:options.blocking !== false, ready:false, slow:false, minimized:false};
    tasks.set(id, task);
    var showTimer = setTimeout(function () { task.ready = true; render(); }, options.immediate ? 0 : delay);
    var slowTimer = setTimeout(function () { task.slow = true; render(); }, 12000);
    var ended = false;
    return function () {
      if (ended) return;
      ended = true; clearTimeout(showTimer); clearTimeout(slowTimer); tasks.delete(id); render();
    };
  }
  async function run(label, action, options) {
    var finish = begin(label, options);
    try { return await action(); } finally { finish(); }
  }
  function requestDetails(url, method) {
    var parsed;
    try { parsed = new URL(url, location.href); } catch (_) { return null; }
    if (parsed.origin !== location.origin && parsed.origin !== 'https://labapi.genziitian.in') return null;
    if (!/^\/(?:public\/)?api\//.test(parsed.pathname)) return null;
    var path = parsed.pathname.replace(/^\/(?:public\/)?api/, '');
    var read = /^(GET|HEAD|OPTIONS)$/.test(method);
    if (path === '/student/spin-practice') return {label:'Creating your practice paper…', blocking:false};
    var background = /\/(?:answers|events|state|heartbeat|presence|seen|read|notifications)(?:\/|$)/.test(path) || /\/auth\/google\/handoff$/.test(path);
    var label = read ? 'Loading…' : method === 'DELETE' ? 'Deleting…' : 'Saving changes…';
    if (/\/auth\//.test(path)) label = read ? 'Checking your account…' : /logout/.test(path) ? 'Signing out…' : /login|google/.test(path) ? 'Signing in…' : /register/.test(path) ? 'Creating your account…' : 'Updating your account…';
    else if (/uploaded-papers/.test(path)) label = read ? 'Loading your uploads…' : 'Uploading and preparing your paper…';
    else if (/import/.test(path)) label = 'Importing questions…';
    else if (/\/orders|razorpay|checkout/.test(path)) label = /verify/.test(path) ? 'Confirming your payment…' : 'Preparing secure checkout…';
    else if (/\/submit(?:\/|$)/.test(path)) label = 'Submitting your answers…';
    else if (/\/answers(?:\/|$)/.test(path)) label = 'Saving answers…';
    else if (/\/attempts$/.test(path)) label = 'Starting your paper…';
    else if (/export|download/.test(path)) label = 'Preparing your download…';
    else if (/dashboard|stats/.test(path)) label = 'Loading your dashboard…';
    else if (/profile/.test(path)) label = read ? 'Loading your profile…' : 'Saving your profile…';
    else if (/leaderboard/.test(path)) label = 'Loading rankings…';
    else if (/discussions/.test(path)) label = read ? 'Loading discussions…' : 'Updating discussion…';
    else if (/papers|quizzes|courses|exam-platform/.test(path)) label = read ? 'Loading papers and courses…' : 'Updating your paper…';
    return {label:label, blocking:!background && (!read || /export|offline-download/.test(path))};
  }
  window.QLLoading = {begin:begin, run:run, requestDetails:requestDetails};

  // Cover fetch callers without changing their responses, credentials or errors.
  var nativeFetch = window.fetch;
  if (nativeFetch) window.fetch = function (input, options) {
    var details = requestDetails(typeof input === 'string' || input instanceof URL ? String(input) : input.url, String(options && options.method || input && input.method || 'GET').toUpperCase());
    if (!details) return nativeFetch.apply(this, arguments);
    var finish = begin(details.label, details), result;
    try { result = nativeFetch.apply(this, arguments); } catch (error) { finish(); throw error; }
    return result.then(function (response) {
      // Keep feedback through JSON decoding, downloads and other body reads.
      // Unconsumed responses (e.g. HEAD) must not leave a permanent spinner.
      var cleanup = setTimeout(finish, 0);
      ['json','text','blob','arrayBuffer','formData','bytes'].forEach(function (name) {
        var readBody = response[name];
        if (typeof readBody !== 'function') return;
        try {
          Object.defineProperty(response, name, {configurable:true, value:function () {
            clearTimeout(cleanup);
            try { return Promise.resolve(readBody.apply(this, arguments)).finally(finish); }
            catch (error) { finish(); throw error; }
          }});
        } catch (_) { /* Some embedded browsers expose non-extensible responses. */ }
      });
      return response;
    }, function (error) { finish(); throw error; });
  };
  // The compiled student/manager React app uses Axios' XMLHttpRequest adapter.
  if (window.XMLHttpRequest) {
    var xhrOpen = XMLHttpRequest.prototype.open, xhrSend = XMLHttpRequest.prototype.send;
    var requests = new WeakMap();
    XMLHttpRequest.prototype.open = function (method, url) {
      var old = requests.get(this); if (old && old.finish) old.finish();
      var result = xhrOpen.apply(this, arguments);
      requests.set(this, {details:requestDetails(String(url), String(method).toUpperCase())});
      return result;
    };
    XMLHttpRequest.prototype.send = function () {
      var request = requests.get(this);
      if (!request || !request.details) return xhrSend.apply(this, arguments);
      request.finish = begin(request.details.label, request.details);
      this.addEventListener('loadend', request.finish, {once:true});
      try { return xhrSend.apply(this, arguments); } catch (error) { request.finish(); throw error; }
    };
  }
  // Local file reads can precede a long JSON import or image upload.
  if (window.FileReader) ['readAsText','readAsArrayBuffer','readAsDataURL'].forEach(function (name) {
    var nativeRead = FileReader.prototype[name];
    FileReader.prototype[name] = function () {
      var finish = begin('Reading your file…', {blocking:true});
      this.addEventListener('loadend', finish, {once:true});
      try { return nativeRead.apply(this, arguments); } catch (error) { finish(); throw error; }
    };
  });
  if (document.readyState === 'loading') {
    var finishOpening = begin('Opening Quiz LAB…', {blocking:false});
    document.addEventListener('DOMContentLoaded', finishOpening, {once:true});
  }
  document.addEventListener('DOMContentLoaded', render);
  window.addEventListener('pageshow', render);
})();
