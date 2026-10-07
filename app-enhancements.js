/*
 * Quiz Lab — UI enhancements layered over the built React app.
 *
 * The React source for the student app no longer exists, only the compiled
 * bundle, so changes that need new component behaviour are applied here
 * against the rendered DOM instead of by editing minified JavaScript.
 *
 * Everything in this file is defensive: if the markup it expects is not
 * found it simply does nothing, leaving the app exactly as it was.
 */
(function () {
  "use strict";

  /* ---------------------------------------------------------------
   * Discussions: turn the long SUBJECT / COURSE chip rows into selects.
   * The select drives the original chips, so React still owns the state.
   * ------------------------------------------------------------- */

  var ROWS = ["SUBJECT", "COURSE"];

  function injectStyles() {
    if (document.getElementById("ql-enhance-styles")) return;
    var css = document.createElement("style");
    css.id = "ql-enhance-styles";
    css.textContent =
      ".ql-filter-select{appearance:none;-webkit-appearance:none;background-color:#fff;" +
      "background-image:url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 24 24' fill='none' stroke='%2364748b' stroke-width='2.5' stroke-linecap='round'%3E%3Cpath d='M6 9l6 6 6-6'/%3E%3C/svg%3E\");" +
      "background-repeat:no-repeat;background-position:right 11px center;" +
      "border:1px solid #e2e8f0;border-radius:9px;color:#0f172a;cursor:pointer;" +
      "font:500 13px/1 Inter,system-ui,-apple-system,sans-serif;" +
      "padding:9px 32px 9px 12px;min-width:170px;transition:border-color .15s ease,box-shadow .15s ease}" +
      ".ql-filter-select:hover{border-color:#cbd5e1}" +
      ".ql-filter-select:focus{outline:none;border-color:#16a34a;box-shadow:0 0 0 3px rgba(22,163,74,.12)}" +
      ".ql-chips-hidden{display:none!important}" +
      ".ql-discussion-sort-row>button{display:none!important}" +
      ".ql-discussion-sort-select{min-width:150px}" +
      ".ql-discussion-owner-select{min-width:140px}";
    document.head.appendChild(css);
  }

  function luminance(rgb) {
    var m = /rgba?\((\d+),\s*(\d+),\s*(\d+)/.exec(rgb || "");
    if (!m) return 255;
    return 0.299 * +m[1] + 0.587 * +m[2] + 0.114 * +m[3];
  }

  /** The selected chip is the visually darkest one in the row. */
  function activeChip(chips) {
    var best = null, bestLum = 1e9;
    chips.forEach(function (c) {
      var lum = luminance(getComputedStyle(c).backgroundColor);
      if (lum < bestLum) { bestLum = lum; best = c; }
    });
    return bestLum < 160 ? best : null;
  }

  function findLabel(text) {
    var nodes = document.querySelectorAll("span,p,div,label");
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      if (el.children.length === 0 && el.textContent.trim().toUpperCase() === text) return el;
    }
    return null;
  }

  function convertRow(labelText) {
    var label = findLabel(labelText);
    if (!label || !label.parentElement) return;

    var row = label.parentElement;
    var chips = Array.prototype.filter.call(row.querySelectorAll("button"), function (b) {
      return b.textContent.trim().length > 0 && !b.classList.contains("ql-skip");
    });
    if (chips.length < 3) return; // not the row we are looking for

    var existing = row.querySelector(".ql-filter-select");
    var current = activeChip(chips);
    var currentText = current ? current.textContent.trim() : chips[0].textContent.trim();

    if (existing) {
      // React re-rendered: keep the select in step rather than rebuilding it.
      if (existing.value !== currentText) existing.value = currentText;
      chips.forEach(function (c) { c.classList.add("ql-chips-hidden"); });
      return;
    }

    var select = document.createElement("select");
    select.className = "ql-filter-select";
    select.setAttribute("aria-label", labelText.toLowerCase() + " filter");

    chips.forEach(function (c) {
      var t = c.textContent.trim();
      var opt = document.createElement("option");
      opt.value = t;
      opt.textContent = t === "All" ? "All " + labelText.toLowerCase() + "s" : t;
      select.appendChild(opt);
    });
    select.value = currentText;

    select.addEventListener("change", function () {
      var want = select.value;
      var target = chips.filter(function (c) { return c.textContent.trim() === want; })[0];
      if (target) {
        target.classList.remove("ql-chips-hidden");
        target.click();
        target.classList.add("ql-chips-hidden");
      }
    });

    chips.forEach(function (c) { c.classList.add("ql-chips-hidden"); });
    row.appendChild(select);
  }

  function convertDiscussionSortRow() {
    var wanted = ["Newest", "Trending", "Unsolved", "Solved", "My threads"];
    var buttons = document.querySelectorAll("#root button");
    var row = null;

    for (var i = 0; i < buttons.length && !row; i++) {
      var label = buttons[i].textContent.trim().toLowerCase();
      if (label !== "newest" && label !== "trending" && label !== "unsolved" && label !== "solved" && label !== "my threads") continue;
      var candidate = buttons[i].parentElement;
      var candidateButtons = candidate ? Array.prototype.filter.call(candidate.querySelectorAll("button"), function (button) {
        return wanted.indexOf(button.textContent.trim()) !== -1;
      }) : [];
      if (candidateButtons.length === wanted.length) row = candidate;
    }
    if (!row) return;

    row.classList.add("ql-discussion-sort-row");
    var sortSelect = row.querySelector(".ql-discussion-sort-select");
    var ownerSelect = row.querySelector(".ql-discussion-owner-select");
    var rowButtons = Array.prototype.filter.call(row.querySelectorAll("button"), function (button) {
      return wanted.indexOf(button.textContent.trim()) !== -1;
    });
    var query = new URLSearchParams(window.location.search);

    if (!sortSelect) {
      sortSelect = document.createElement("select");
      sortSelect.className = "ql-filter-select ql-discussion-sort-select";
      sortSelect.setAttribute("aria-label", "Discussion sort and status");
      wanted.slice(0, 4).forEach(function (label) {
        var option = document.createElement("option");
        option.value = label.toLowerCase();
        option.textContent = label;
        sortSelect.appendChild(option);
      });
      sortSelect.addEventListener("change", function () {
        var target = rowButtons.filter(function (button) {
          return button.textContent.trim().toLowerCase() === sortSelect.value;
        })[0];
        if (target) target.click();
      });
      row.appendChild(sortSelect);
    }
    sortSelect.value = query.get("sort") || "newest";

    if (!ownerSelect) {
      ownerSelect = document.createElement("select");
      ownerSelect.className = "ql-filter-select ql-discussion-owner-select";
      ownerSelect.setAttribute("aria-label", "Thread ownership filter");
      [{ value: "all", label: "All threads" }, { value: "mine", label: "My threads" }].forEach(function (item) {
        var option = document.createElement("option");
        option.value = item.value;
        option.textContent = item.label;
        ownerSelect.appendChild(option);
      });
      ownerSelect.addEventListener("change", function () {
        var target = rowButtons.filter(function (button) { return button.textContent.trim() === "My threads"; })[0];
        var isMine = new URLSearchParams(window.location.search).get("mine") === "1";
        if (target && ((ownerSelect.value === "mine") !== isMine)) target.click();
      });
      row.appendChild(ownerSelect);
    }
    ownerSelect.value = query.get("mine") === "1" ? "mine" : "all";
  }

  function syncAdminShell() {
    var isAdminRoute = /^\/admin(?:\/|$)/i.test(window.location.pathname);
    document.body.classList.toggle("ep-admin-layout", isAdminRoute);

    if (!isAdminRoute) return;
    var role = document.body.dataset.epVerifiedRole;
    if (role !== "admin" && role !== "manager") return;
    hideAdminStudentTotal();
    if (role === "admin" && (/^\/admin\/?$/i.test(window.location.pathname) || /^\/admin\/analytics\/?$/i.test(window.location.pathname))) {
      window.location.replace("/admin/quizzes");
      return;
    }
    var badgeText = role === "manager" ? "Manager" : "Admin";
    document.querySelectorAll("#root aside h1 > span:last-child, #root header h1 > span:last-child").forEach(function (badge) {
      if (badge.textContent.trim() !== badgeText) badge.textContent = badgeText;
    });

    if (role === "admin") {
      document.querySelectorAll('#root a[href="/admin"], #root a[href="/admin/analytics"], #root a[href="/admin/users"]').forEach(function (link) {
        var item = link.closest("li") || link;
        item.style.display = "none";
      });
      document.querySelectorAll("#root aside a, #root nav a").forEach(function (link) {
        if (/^users$/i.test(link.textContent.trim())) (link.closest("li") || link).style.display = "none";
      });
      if (/^\/admin\/courses\/?$/i.test(window.location.pathname)) {
        document.querySelectorAll("#root button").forEach(function (button) {
          if (/^(\+\s*)?(add|new) course$/i.test(button.textContent.trim()) || /^(edit|delete)$/i.test(button.textContent.trim())) button.style.display = "none";
        });
      }
      addQuizReviewState(role);
    }

    if (role === "manager" && /^\/admin\/settings\/?$/i.test(window.location.pathname)) {
      document.querySelectorAll("#root h1").forEach(function (heading) {
        if (heading.textContent.trim() === "Admin Settings") heading.textContent = "Manager Settings";
      });
      document.querySelectorAll("#root p").forEach(function (description) {
        if (description.textContent.trim() === "Update your admin account security settings.") {
          description.textContent = "Update your manager account security settings.";
        }
      });
      ensureManagerProfile();
      ensureManagerCourseAssignments();
    }
    if (role === "manager" && /^\/admin\/quizzes\/?$/i.test(window.location.pathname)) addQuizReviewState(role);
  }

  function hideAdminStudentTotal() {
    var nodes = document.querySelectorAll("#root p, #root span, #root div");
    for (var i = 0; i < nodes.length; i++) {
      var label = nodes[i];
      if (label.children.length || label.textContent.trim() !== "Total Students") continue;
      var card = label.closest(".rounded-2xl");
      if (card) card.style.display = "none";
    }
  }

  function apiUrl(path) {
    return (/^(localhost|127\.0\.0\.1|0\.0\.0\.0)$/.test(window.location.hostname)
      ? window.location.origin + "/api" : "https://labapi.genziitian.in/public/api") + path;
  }

  function apiFetch(path, options) {
    var token = "";
    try { token = localStorage.getItem("lab_token") || ""; } catch (_) {}
    options = options || {};
    options.headers = Object.assign({ Accept: "application/json", Authorization: "Bearer " + token }, options.headers || {});
    return fetch(apiUrl(path), options).then(function (response) {
      if (!response.ok) throw new Error("Request failed");
      return response.status === 204 ? null : response.json();
    });
  }

  function syncPaperPricingLink() {
    var existing = document.getElementById("ql-paper-pricing-link");
    if (document.body.dataset.epVerifiedRole !== "manager" || !/^\/admin(?:\/(?:quizzes|courses))?\/?$/.test(location.pathname)) {
      if (existing) existing.remove();
      return;
    }
    var host = document.querySelector("#root main");
    if (!host || existing) return;
    var link = document.createElement("a");
    link.id = "ql-paper-pricing-link";
    link.className = "ql-storefront-manager-link";
    link.href = "/manager/sales";
    link.textContent = "Manage sales →";
    host.insertBefore(link, host.firstChild);
  }

  var quizListCache = null;
  var quizListCacheAt = 0;
  var quizListPending = null;

  function addQuizReviewState(role) {
    if (quizListPending) return;
    if (quizListCache && Date.now() - quizListCacheAt < 4000) {
      paintQuizReviewState(role, quizListCache);
      return;
    }
    quizListPending = apiFetch("/admin/quizzes").then(function (rows) {
      quizListCache = Array.isArray(rows) ? rows : [];
      quizListCacheAt = Date.now();
      paintQuizReviewState(role, quizListCache);
    }).catch(function () {}).finally(function () { quizListPending = null; });
  }

  function paintQuizReviewState(role, quizzes) {
    var table = document.querySelector("#root table");
    if (!table) return;
    var headers = table.querySelectorAll("thead th");
    Array.prototype.forEach.call(headers, function (th) {
      if (/^active$/i.test(th.textContent.trim())) th.textContent = role === "manager" ? "Active / disabled" : "Review status";
    });
    table.querySelectorAll("tbody tr").forEach(function (row) {
      var manage = row.querySelector('a[href*="/admin/quizzes/"]');
      var match = manage && manage.getAttribute("href").match(/\/admin\/quizzes\/(\d+)/);
      if (!match) return;
      var paper = quizzes.find(function (quiz) { return String(quiz.id) === match[1]; });
      if (!paper) return;
      var firstCell = row.querySelector("td");
      if (firstCell && !firstCell.querySelector(".ql-paper-review-state")) {
        var badge = document.createElement("span");
        badge.className = "ql-paper-review-state";
        badge.textContent = paper.approval_status === "pending" ? "Pending manager approval" : (paper.is_active ? "Approved · active" : "Approved · disabled");
        badge.style.cssText = "display:inline-block;margin:4px 0 0 8px;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:600;background:" + (paper.approval_status === "pending" ? "#fff7ed;color:#c2410c" : paper.is_active ? "#ecfdf5;color:#047857" : "#f1f5f9;color:#475569");
        firstCell.appendChild(badge);
      }
      // Managers see the price of a paid paper next to its title.
      if (role === "manager" && firstCell) {
        var priceText = Number(paper.price_paise || 0) > 0 ? "\u20B9" + String(paper.price_paise / 100).replace(/\.0+$/, "") : "";
        var priceChip = firstCell.querySelector(".ql-paper-price");
        if (priceText && !priceChip) {
          priceChip = document.createElement("span");
          priceChip.className = "ql-paper-price";
          priceChip.style.cssText = "display:inline-block;margin:4px 0 0 8px;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:700;background:#fef3c7;color:#92400e";
          firstCell.appendChild(priceChip);
        }
        if (priceChip && !priceText) priceChip.remove();
        else if (priceChip && priceChip.textContent !== priceText) priceChip.textContent = priceText;
      }
      var activeCell = row.children.length > 5 ? row.children[5] : null;
      if (activeCell) {
        var toggle = activeCell.querySelector('input[type="checkbox"]');
        if (role === "admin" && toggle) {
          toggle.style.display = "none";
          toggle.disabled = true;
        }
        if (role === "manager" && toggle) {
          toggle.style.display = "none";
          var statusButton = activeCell.querySelector(".ql-active-toggle");
          if (!statusButton) {
            statusButton = document.createElement("button");
            statusButton.type = "button";
            statusButton.className = "ql-active-toggle";
        statusButton.style.cssText = "border:1px solid #cbd5e1;border-radius:8px;background:white;color:#334155;padding:6px 9px;font-family:inherit;font-weight:600;font-size:12px;line-height:1.2;cursor:pointer";
            activeCell.appendChild(statusButton);
            statusButton.addEventListener("click", function () {
              statusButton.disabled = true;
              statusButton.textContent = "Updating…";
              apiFetch("/admin/quizzes/" + paper.id + "/toggle", { method: "PATCH" }).then(function () { window.location.reload(); }).catch(function () { statusButton.disabled = false; statusButton.textContent = paper.is_active ? "Disable" : "Activate"; });
            });
          }
          statusButton.disabled = paper.approval_status !== "approved";
          statusButton.textContent = paper.approval_status !== "approved" ? "Awaiting approval" : (paper.is_active ? "Disable" : "Activate");
        }
      }
      if (role === "manager" && paper.approval_status === "pending" && !row.querySelector(".ql-approve-paper")) {
        var actions = row.querySelector("td:last-child > div");
        if (!actions) return;
        var approve = document.createElement("button");
        approve.type = "button";
        approve.className = "ql-approve-paper";
        approve.textContent = "Approve";
        approve.style.cssText = "border:0;border-radius:8px;background:#16a34a;color:white;padding:6px 10px;font:600 12px/1.2 inherit;cursor:pointer";
        approve.addEventListener("click", function () {
          approve.disabled = true;
          approve.textContent = "Approving…";
          apiFetch("/admin/quizzes/" + paper.id + "/approve", { method: "PATCH" }).then(function () { window.location.reload(); }).catch(function () { approve.disabled = false; approve.textContent = "Approve"; });
        });
        actions.insertBefore(approve, actions.firstChild);
      }
      row.dataset.qlPaperReviewReady = String(paper.approval_status) + ":" + String(paper.is_active);
    });
  }

  function ensureManagerCourseAssignments() {
    var page = document.querySelector("#root main .page-enter > div");
    if (!page || document.getElementById("ql-manager-course-assignments")) return;
    var card = document.createElement("section");
    card.id = "ql-manager-course-assignments";
    card.style.cssText = "margin-top:20px;background:#fff;border:1px solid #e2e8f0;border-radius:18px;padding:24px;box-shadow:0 2px 5px rgba(15,23,42,.08)";
    card.innerHTML = '<h2 style="margin:0;color:#0f172a;font-size:20px;font-weight:700">Teacher course access</h2><p style="margin:6px 0 16px;color:#64748b;font-size:14px">Choose an admin teacher, then assign the courses they can manage.</p><select id="ql-teacher-select" style="width:100%;max-width:440px;padding:10px;border:1px solid #cbd5e1;border-radius:10px"><option>Loading teachers…</option></select><div id="ql-teacher-courses" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:8px;margin:16px 0"></div><div style="display:flex;align-items:center;gap:12px"><button id="ql-save-teacher-courses" type="button" style="border:0;border-radius:10px;background:#16a34a;color:white;padding:10px 16px;font-weight:700;cursor:pointer">Save course access</button><span id="ql-teacher-course-message" role="status" style="font-size:13px;color:#64748b"></span></div>';
    page.appendChild(card);
    Promise.all([apiFetch("/admin/users?filter=admins&per_page=100"), apiFetch("/admin/courses")]).then(function (results) {
      var users = results[0].data || [];
      var courses = results[1] || [];
      var select = card.querySelector("#ql-teacher-select");
      select.innerHTML = '<option value="">Select a teacher</option>' + users.map(function (user) { return '<option value="' + user.id + '">' + escapeHtml(user.name) + ' · ' + escapeHtml(user.email) + '</option>'; }).join("");
      function showAssignments() {
        var user = users.find(function (item) { return String(item.id) === select.value; });
        var assigned = user && user.assigned_course_ids || [];
        card.querySelector("#ql-teacher-courses").innerHTML = courses.map(function (course) {
          return '<label style="display:flex;align-items:center;gap:8px;padding:10px;border:1px solid #e2e8f0;border-radius:10px;color:#334155"><input type="checkbox" value="' + course.id + '" ' + (assigned.map(String).includes(String(course.id)) ? 'checked' : '') + '> ' + escapeHtml(course.name) + '</label>';
        }).join("");
      }
      select.addEventListener("change", showAssignments);
      card.querySelector("#ql-save-teacher-courses").addEventListener("click", function () {
        if (!select.value) return;
        var ids = Array.prototype.map.call(card.querySelectorAll("#ql-teacher-courses input:checked"), function (input) { return Number(input.value); });
        var message = card.querySelector("#ql-teacher-course-message");
        message.textContent = "Saving…";
        apiFetch("/admin/users/" + select.value + "/courses", { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ course_ids: ids }) }).then(function () { message.textContent = "Course access saved."; }).catch(function () { message.textContent = "Could not save course access."; });
      });
    }).catch(function () { card.querySelector("#ql-teacher-course-message").textContent = "Could not load teacher or course data."; });
  }

  function escapeHtml(value) {
    return String(value || "").replace(/[&<>"']/g, function (character) { return ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]; });
  }

  var managerProfileLoad = null;

  function ensureManagerProfile() {
    var page = document.querySelector("#root main .page-enter > div");
    if (!page || document.getElementById("ql-manager-profile-card")) return;

    var card = document.createElement("section");
    card.id = "ql-manager-profile-card";
    card.style.cssText = "background:#fff;border:1px solid #e2e8f0;border-radius:18px;padding:24px;box-shadow:0 2px 5px rgba(15,23,42,.08);";
    card.innerHTML =
      '<div style="margin-bottom:20px"><h2 style="margin:0;color:#0f172a;font-size:20px;font-weight:700">Manager Profile</h2>' +
      '<p style="margin:6px 0 0;color:#64748b;font-size:14px">Manage the name and photo shown on your manager account.</p></div>' +
      '<form id="ql-manager-profile-form" style="display:grid;gap:16px">' +
      '<div style="display:flex;align-items:center;gap:14px">' +
      '<div id="ql-manager-avatar" style="width:64px;height:64px;border-radius:50%;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#ecfdf5;color:#15803d;font-size:21px;font-weight:700;flex:0 0 auto"></div>' +
      '<div style="min-width:0"><div id="ql-manager-profile-name" style="font-weight:700;color:#0f172a">Loading profile…</div><div id="ql-manager-profile-role" style="margin-top:4px;color:#15803d;font-size:12px;font-weight:700">MANAGER</div></div></div>' +
      '<label style="display:grid;gap:6px;color:#475569;font-size:14px">Name<input id="ql-manager-name" name="name" maxlength="120" required style="width:100%;padding:11px 13px;border:1px solid #dbe3ee;border-radius:12px;color:#0f172a;background:#fff;font:inherit"></label>' +
      '<label style="display:grid;gap:6px;color:#475569;font-size:14px">Email<input id="ql-manager-email" readonly style="width:100%;padding:11px 13px;border:1px solid #dbe3ee;border-radius:12px;color:#64748b;background:#f8fafc;font:inherit"></label>' +
      '<label style="display:grid;gap:6px;color:#475569;font-size:14px">Profile photo<input id="ql-manager-photo" type="file" accept="image/png,image/jpeg,image/webp" style="color:#475569;font-size:13px"></label>' +
      '<label style="display:flex;align-items:center;gap:8px;color:#64748b;font-size:13px"><input id="ql-manager-remove-photo" type="checkbox"> Remove current photo</label>' +
      '<div style="display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap"><p id="ql-manager-profile-message" role="status" style="margin:0;color:#64748b;font-size:13px"></p><button id="ql-manager-profile-save" type="submit" style="border:0;border-radius:11px;background:#16a34a;color:#fff;padding:11px 17px;font-size:14px;font-weight:700;cursor:pointer">Save Profile</button></div>' +
      '</form>';

    var headingCard = page.firstElementChild;
    if (headingCard && headingCard.nextSibling) page.insertBefore(card, headingCard.nextSibling);
    else page.appendChild(card);

    if (!managerProfileLoad) {
      var token = "";
      try { token = localStorage.getItem("lab_token") || ""; } catch (_) {}
      var apiBase = /^(localhost|127\.0\.0\.1|0\.0\.0\.0)$/.test(window.location.hostname)
        ? window.location.origin + "/api"
        : "https://labapi.genziitian.in/public/api";
      managerProfileLoad = fetch(apiBase + "/auth/me", {
        headers: { Accept: "application/json", Authorization: "Bearer " + token }
      }).then(function (response) {
        if (!response.ok) throw new Error("Could not load your profile.");
        return response.json();
      }).then(function (payload) {
        return payload.user || {};
      }).catch(function (error) {
        managerProfileLoad = null;
        throw error;
      });
    }

    var form = card.querySelector("#ql-manager-profile-form");
    var nameInput = card.querySelector("#ql-manager-name");
    var emailInput = card.querySelector("#ql-manager-email");
    var photoInput = card.querySelector("#ql-manager-photo");
    var removePhoto = card.querySelector("#ql-manager-remove-photo");
    var avatar = card.querySelector("#ql-manager-avatar");
    var profileName = card.querySelector("#ql-manager-profile-name");
    var message = card.querySelector("#ql-manager-profile-message");
    var saveButton = card.querySelector("#ql-manager-profile-save");
    var currentUser = null;

    function showUser(user) {
      currentUser = user;
      nameInput.value = user.name || "";
      emailInput.value = user.email || "";
      profileName.textContent = user.name || "Manager";
      avatar.replaceChildren();
      if (user.avatar) {
        var image = document.createElement("img");
        image.src = user.avatar;
        image.alt = "Profile photo";
        image.style.cssText = "width:100%;height:100%;object-fit:cover";
        avatar.appendChild(image);
      } else {
        avatar.textContent = (user.name || "M").trim().split(/\s+/).map(function (part) { return part.charAt(0); }).join("").slice(0, 2).toUpperCase();
      }
    }

    managerProfileLoad.then(showUser).catch(function (error) {
      message.textContent = error.message || "Could not load your profile.";
      message.style.color = "#dc2626";
    });

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      if (!currentUser) return;
      var token = "";
      try { token = localStorage.getItem("lab_token") || ""; } catch (_) {}
      var body = new FormData();
      body.append("_method", "PATCH");
      body.append("name", nameInput.value.trim());
      if (photoInput.files && photoInput.files[0]) body.append("avatar", photoInput.files[0]);
      if (removePhoto.checked) body.append("remove_avatar", "1");
      saveButton.disabled = true;
      saveButton.textContent = "Saving…";
      message.textContent = "";
      fetch(apiBase + "/student/profile", {
        method: "POST",
        headers: { Accept: "application/json", Authorization: "Bearer " + token },
        body: body
      }).then(function (response) {
        return response.json().then(function (payload) {
          if (!response.ok) throw new Error(payload.message || "Could not save your profile.");
          return payload.user || {};
        });
      }).then(function (updated) {
        currentUser = Object.assign({}, currentUser, updated);
        showUser(currentUser);
        photoInput.value = "";
        removePhoto.checked = false;
        message.textContent = "Profile saved.";
        message.style.color = "#15803d";
        try {
          var storedUser = JSON.parse(localStorage.getItem("lab_user") || "{}");
          localStorage.setItem("lab_user", JSON.stringify(Object.assign(storedUser, currentUser)));
        } catch (_) {}
        var sidebarName = document.querySelector("#root aside .mt-3.rounded-xl p");
        if (sidebarName && currentUser.name) sidebarName.textContent = currentUser.name;
      }).catch(function (error) {
        message.textContent = error.message || "Could not save your profile.";
        message.style.color = "#dc2626";
      }).finally(function () {
        saveButton.disabled = false;
        saveButton.textContent = "Save Profile";
      });
    });
  }

  function removeStudentWeakSpotCard() {
    if (!/^\/dashboard\/?$/i.test(window.location.pathname)) return;

    document.querySelectorAll("#root a").forEach(function (card) {
      var text = card.textContent.replace(/\s+/g, " ").trim();
      if (!/REVIEW\s*[·.]\s*YOUR WEAK SPOTS/i.test(text) || !/Revisit incorrect answers from recent attempts/i.test(text)) return;

      var cardList = card.parentElement;
      var section = cardList && cardList.parentElement;
      card.remove();

      if (!cardList || !section) return;
      var remainingCards = cardList.querySelectorAll("a").length;
      if (remainingCards === 0) {
        section.remove();
        return;
      }

      section.querySelectorAll("div").forEach(function (label) {
        if (/^UP NEXT\s*[·.]\s*\d+\s+THINGS?$/i.test(label.textContent.trim())) {
          label.textContent = "UP NEXT · " + remainingCards + " " + (remainingCards === 1 ? "THING" : "THINGS");
        }
      });
    });
  }

  /* ---------------------------------------------------------------
   * Student dashboard: tag the cards so storefront-dashboard.css can
   * give them colour and motion. Only attributes are added, so React
   * keeps full ownership of the markup and its state.
   * ------------------------------------------------------------- */
  var DASH_STATS = { "CURRENT STREAK": "streak", "ACCURACY": "accuracy", "THIS WEEK": "week", "RANK": "rank" };

  function tag(el, name, value) {
    if (el && el.getAttribute(name) !== value) el.setAttribute(name, value);
  }

  function decorateDashboard() {
    if (!/^\/dashboard\/?$/i.test(window.location.pathname)) return;
    var hello = null;
    document.querySelectorAll("#root h1").forEach(function (h) {
      if (!hello && /^Welcome back/i.test(h.textContent.trim())) hello = h;
    });
    if (!hello) return;

    var root = hello.parentElement;
    while (root && root.id !== "root" && !/CURRENT STREAK/.test(root.textContent)) root = root.parentElement;
    if (!root || root.id === "root") return;
    tag(root, "data-ql-dash", "root");
    tag(hello, "data-ql-hello", "");

    root.querySelectorAll("div").forEach(function (label) {
      if (label.children.length) return;
      var text = label.textContent.trim().toUpperCase();
      var card = label.closest(".rounded-2xl");
      if (!card) return;
      if (DASH_STATS[text]) tag(card, "data-ql-stat", DASH_STATS[text]);
      else if (/^PERFORMANCE\b/.test(text)) tag(card, "data-ql-card", "perf");
      else if (text === "WEEKLY GOAL") tag(card, "data-ql-card", "goal");
    });

    /* The Activity and Leaderboard panels are not shown on the dashboard. */
    root.querySelectorAll("div.uppercase").forEach(function (label) {
      var text = label.textContent.trim().toUpperCase();
      if (text !== "ACTIVITY" && text !== "LEADERBOARD") return;
      var card = label.closest(".rounded-2xl");
      if (!card) return;
      tag(card, "data-ql-hidden", "");
      var row = card.parentElement;
      if (row && row !== root && Array.prototype.every.call(row.children, function (c) {
        return c.hasAttribute("data-ql-hidden") || /^(ACTIVITY|LEADERBOARD)/.test(c.textContent.trim().toUpperCase());
      })) tag(row, "data-ql-hidden", "");
    });

    root.querySelectorAll("a.rounded-2xl").forEach(function (card) {
      var text = card.textContent.toUpperCase();
      var kind = /CONTINUE WHERE/.test(text) ? "continue" : /DAILY CHALLENGE/.test(text) ? "daily" : /REVIEW/.test(text) ? "review" : "";
      if (kind) tag(card, "data-ql-next", kind);
    });

    /* Normalise line lengths so the charts can draw themselves in with CSS. */
    root.querySelectorAll('[data-ql-stat] svg path[fill="none"], [data-ql-card="perf"] svg path[fill="none"]').forEach(function (path) {
      tag(path, "pathLength", "1");
      tag(path, "data-ql-draw", "");
    });
  }

  /* ---------------------------------------------------------------
   * Manager console: tag the Quizzes and Subjects pages so the
   * "Manager console" rules in storefront-dashboard.css can restyle
   * them, and add a quick search over the quiz table. React keeps
   * ownership of the rows; this only sets attributes and hides rows.
   * ------------------------------------------------------------- */
  function consoleHeading(text) {
    var found = null;
    document.querySelectorAll("#root main h1, #root h1").forEach(function (h) {
      if (!found && h.textContent.trim() === text) found = h;
    });
    return found;
  }

  function filterQuizRows() {
    var table = document.querySelector("[data-ql-tablecard] table");
    var heading = document.querySelector("[data-ql-console-title]");
    if (!table) return;
    var input = document.getElementById("ql-quiz-search");
    var words = (input ? input.value : "").toLowerCase().split(/\s+/).filter(Boolean);
    var rows = table.querySelectorAll("tbody tr");
    var shown = 0;
    rows.forEach(function (row) {
      var text = row.textContent.toLowerCase();
      var match = words.every(function (word) { return text.indexOf(word) !== -1; });
      if (row.hidden === match) row.hidden = !match;
      if (match) shown++;
    });
    tag(table, "data-ql-empty", shown ? "false" : "true");
    if (heading) tag(heading, "data-count", shown === rows.length ? String(rows.length) : shown + " of " + rows.length);
  }

  function decorateManagerConsole() {
    var page = /^\/(?:admin|manager)\/(quizzes|courses)\/?$/i.exec(window.location.pathname);
    if (!page) return;

    if (page[1].toLowerCase() === "courses") {
      var subjects = consoleHeading("Subjects");
      var header = subjects && subjects.parentElement && subjects.parentElement.parentElement;
      var grid = header && header.nextElementSibling;
      if (!grid || !/\bgrid\b/.test(grid.className)) return;
      tag(grid, "data-ql-console", "courses");
      tag(header, "data-ql-console-head", "");
      tag(subjects, "data-ql-console-title", "");
      tag(subjects, "data-count", String(grid.children.length));
      grid.querySelectorAll("button").forEach(function (button) {
        var label = button.textContent.trim().toLowerCase();
        if (label === "edit" || /^delet/.test(label)) tag(button, "data-ql-act", label === "edit" ? "edit" : "delete");
      });
      return;
    }

    var title = consoleHeading("Quizzes");
    var root = title && (title.closest(".space-y-4") || title.parentElement.parentElement);
    if (!root) return;
    tag(root, "data-ql-console", "quizzes");
    tag(title.parentElement, "data-ql-console-head", "");
    tag(title, "data-ql-console-title", "");

    var firstSelect = root.querySelector("select");
    var filters = firstSelect && firstSelect.closest(".grid");
    if (filters) {
      tag(filters, "data-ql-filters", "");
      if (!document.getElementById("ql-quiz-search")) {
        var field = document.createElement("div");
        field.className = "ql-console-search";
        var label = document.createElement("label");
        label.htmlFor = "ql-quiz-search";
        label.textContent = "Search";
        var input = document.createElement("input");
        input.id = "ql-quiz-search";
        input.type = "search";
        input.placeholder = "Search by title or course";
        input.autocomplete = "off";
        input.addEventListener("input", filterQuizRows);
        field.appendChild(label);
        field.appendChild(input);
        filters.appendChild(field);
      }
    }

    var table = root.querySelector("table");
    if (!table) { tag(title, "data-count", "0"); return; }
    tag(table.parentElement, "data-ql-tablecard", "");
    table.querySelectorAll("tbody tr").forEach(function (row) {
      var cells = row.children;
      if (cells.length < 7) return;
      tag(cells[0], "data-ql-cell", "title");
      tag(cells[1], "data-ql-cell", "course");
      tag(cells[3], "data-ql-cell", cells[3].textContent.trim() === "-" ? "empty" : "week");
      tag(cells[4], "data-ql-cell", "count");
      tag(cells[cells.length - 1], "data-ql-cell", "actions");
      cells[cells.length - 1].querySelectorAll("button").forEach(function (button) {
        var label = button.textContent.trim().toLowerCase();
        if (label === "manage" || label === "edit" || label === "delete") tag(button, "data-ql-act", label);
      });
    });
    filterQuizRows();
  }

  /* ---------------------------------------------------------------
   * My Papers: the student's own record, papers they bought and papers
   * they attempted, shown as its own tab inside the student app
   * (/my-papers). Free papers they never opened stay in Practice. The app renders an
   * empty container for this route and this fills it.
   * ------------------------------------------------------------- */
  function fillMyPapers() {
    var host = document.getElementById("ql-my-papers");
    if (!host || host.dataset.qlLoaded) return;
    var runtime = window.QLStorefront;
    if (!runtime || !runtime.token()) return;
    host.dataset.qlLoaded = "1";
    host.innerHTML = '<div class="ql-mp-head"><div class="ql-mp-title"><h1>Your papers.</h1><a class="ql-mp-browse" href="/practice">Browse practice</a></div><p>Papers you bought or attempted, with your progress.</p></div><div class="ql-mp-grid" aria-live="polite"><p class="ql-mp-note">Loading your papers…</p></div>';
    var grid = host.querySelector(".ql-mp-grid");
    function note(text) {
      grid.replaceChildren();
      var p = document.createElement("p");
      p.className = "ql-mp-note";
      p.textContent = text;
      grid.appendChild(p);
    }
    fetch(runtime.apiBase + "/storefront/my-papers", {
      headers: { Accept: "application/json", Authorization: "Bearer " + runtime.token() }
    }).then(function (response) {
      if (response.status === 403) throw new Error("role");
      if (!response.ok) throw new Error("load");
      return response.json();
    }).then(function (data) {
      if (!host.isConnected) return;
      var papers = Array.isArray(data.papers) ? data.papers : [];
      if (!papers.length) return note("Nothing here yet. Start any free paper from Practice, or buy a paper, and it shows up here with your score.");
      grid.replaceChildren();
      var labels = { quiz1: "Quiz 1", quiz2: "Quiz 2", endterm: "End Term", mock_test: "Mock test", practice: "Practice", practice_graded: "Graded practice" };
      papers.forEach(function (paper) {
        var paid = Number(paper.price_paise || 0) > 0;
        var purchased = paper.purchased === true || paper.source === "purchase";
        var expired = paid && !!paper.expired;
        var usable = paper.available !== false && paper.has_access !== false && !expired;
        var attempts = Number(paper.attempt_count || 0);
        var state = paper.available === false ? "Unavailable" : expired ? "Access expired" : purchased ? "Purchased \u2713" : paid ? "Paid" : "Free";
        var card = document.createElement("article");
        card.className = "ql-mp-card" + (purchased && usable ? " owned" : "");
        var badge = document.createElement("span");
        badge.className = "ql-mp-badge" + (paper.available === false || expired ? " off" : purchased ? " paid" : paid ? " lock" : "");
        badge.textContent = state;
        var title = document.createElement("h3");
        title.textContent = paper.title || "Paper";
        var sub = document.createElement("p");
        sub.className = "ql-mp-sub";
        sub.textContent = [(paper.course || {}).name, paper.year, labels[paper.section]].filter(Boolean).join(" · ");
        var meta = document.createElement("p");
        meta.className = "ql-mp-meta";
        [
          paper.question_count != null ? paper.question_count + " questions" : "",
          paper.time_limit_minutes ? paper.time_limit_minutes + " min" : "Untimed",
          paper.expires_at && paid ? (expired ? "Expired " : "Access until ") + new Date(paper.expires_at).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" }) : ""
        ].filter(Boolean).forEach(function (text) {
          var chip = document.createElement("span");
          chip.textContent = text;
          meta.appendChild(chip);
        });
        var progress = document.createElement("p");
        progress.className = "ql-mp-progress" + (paper.in_progress ? " live" : attempts ? " done" : "");
        progress.textContent = paper.in_progress ? "In progress"
          : attempts ? (paper.last_total_marks != null ? "Last score " + Number(paper.last_score || 0) + "/" + Number(paper.last_total_marks) + " \u00b7 " : "") + attempts + (attempts === 1 ? " attempt" : " attempts")
          : "Not started";
        // Score line and the Free / Purchased tag share one row, with a thin bar for the last score.
        var status = document.createElement("div");
        status.className = "ql-mp-status";
        status.append(progress, badge);
        card.append(title, sub, meta, status);
        var total = Number(paper.last_total_marks || 0);
        if (attempts && total > 0 && !paper.in_progress) {
          var pct = Math.max(0, Math.min(100, Math.round((Number(paper.last_score || 0) / total) * 100)));
          var bar = document.createElement("div");
          bar.className = "ql-mp-bar";
          bar.setAttribute("role", "img");
          bar.setAttribute("aria-label", "Last score " + pct + "%");
          var fill = document.createElement("i");
          fill.style.width = pct + "%";
          bar.appendChild(fill);
          card.appendChild(bar);
        }
        if (paper.available !== false) {
          var action = document.createElement("a");
          action.className = "ql-mp-action" + (usable ? "" : " renew");
          action.href = usable ? "/paper/" + encodeURIComponent(paper.id) : "/papers?paper=" + encodeURIComponent(paper.id);
          action.textContent = usable ? (paper.in_progress ? "Continue" : attempts ? "Attempt again" : "Start") : expired ? "Renew access" : "Buy paper";
          var actions = document.createElement("div");
          actions.className = "ql-mp-actions";
          if (usable) {
            var details = document.createElement("a");
            details.className = "ql-mp-action renew";
            details.href = "/papers?paper=" + encodeURIComponent(paper.id);
            details.textContent = "View details";
            actions.appendChild(details);
          }
          actions.appendChild(action);
          card.appendChild(actions);
        }
        grid.appendChild(card);
      });
    }).catch(function (error) {
      if (!host.isConnected) return;
      note(error.message === "role" ? "My Papers is for student accounts. Managers handle papers and sales from the manager console." : "Your papers could not load. Check your connection and reload the page.");
    });
  }

  /* ---------------------------------------------------------------
   * Practice: paid papers carry a lock and price until the student
   * buys them, then a "Purchased" badge. Free papers are left alone.
   * Prices come from the public catalogue, purchases from My Papers.
   * ------------------------------------------------------------- */
  var paperAccess = null;
  var paperAccessAt = 0;
  function loadPaperAccess() {
    var runtime = window.QLStorefront;
    if (!runtime || !runtime.token()) return;
    // One request at a time, and at most one a minute, whether it worked or not.
    if (paperAccess === "loading" || (paperAccessAt && Date.now() - paperAccessAt < 60000)) return;
    var previous = paperAccess;
    paperAccess = "loading";
    var headers = { Accept: "application/json", Authorization: "Bearer " + runtime.token() };
    var json = function (response) { return response.ok ? response.json() : { papers: [] }; };
    Promise.all([
      fetch(runtime.apiBase + "/storefront/papers", { headers: { Accept: "application/json" } }).then(json),
      fetch(runtime.apiBase + "/storefront/my-papers", { headers: headers }).then(json)
    ]).then(function (results) {
      var map = {};
      (results[0].papers || []).forEach(function (paper) {
        if (Number(paper.price_paise || 0) > 0) map[paper.id] = { price: Number(paper.price_paise), owned: false };
      });
      (results[1].papers || []).forEach(function (paper) {
        if (map[paper.id] && paper.has_access !== false && !paper.expired) map[paper.id].owned = true;
      });
      paperAccess = map;
      paperAccessAt = Date.now();
      schedule();
    }).catch(function () {
      paperAccess = previous;
      paperAccessAt = Date.now();
    });
  }

  function decoratePracticeCards() {
    if (!/^\/practice\//i.test(window.location.pathname)) return;
    // Managers and admins open paid papers without buying, so a lock would mislead.
    if (storedRole() && storedRole() !== "student") return;
    var links = document.querySelectorAll('#root a[href^="/quiz/"]');
    if (!links.length) return;
    loadPaperAccess();
    if (!paperAccess || paperAccess === "loading") return;
    links.forEach(function (link) {
      var m = /^\/quiz\/(\d+)\/?$/.exec(link.getAttribute("href") || "");
      var info = m && paperAccess[m[1]];
      var row = link.querySelector(":scope > div > div");
      if (!row) return;
      var want = info ? (info.owned ? "owned" : "locked") : "";
      var chip = row.querySelector(".ql-paid-chip");
      if (!want) { if (chip) chip.remove(); if (link.hasAttribute("data-ql-paid")) link.removeAttribute("data-ql-paid"); return; }
      var text = info.owned ? "Purchased \u2713" : "\uD83D\uDD12 \u20B9" + String(info.price / 100).replace(/\.0+$/, "");
      if (!chip) {
        chip = document.createElement("span");
        chip.className = "ql-paid-chip";
        row.appendChild(chip);
      }
      if (chip.textContent !== text) chip.textContent = text;
      tag(chip, "data-state", want);
      tag(link, "data-ql-paid", want);
    });
  }

  /* ---------------------------------------------------------------
   * Manager sidebar: the console is reachable at both /admin/... and
   * /manager/..., but the sidebar links point at /manager/..., so on
   * an /admin address the app highlights nothing. Mark the matching
   * link as current.
   * ------------------------------------------------------------- */
  function syncConsoleNav() {
    var links = document.querySelectorAll("#root aside nav a[href]");
    var path = window.location.pathname.replace(/\/+$/, "") || "/";
    var best = null;
    if (/^\/admin(\/|$)/.test(path) && !document.querySelector("#root aside nav a.ql-nav-active")) {
      var target = path.replace(/^\/admin/, "/manager");
      links.forEach(function (link) {
        var href = (link.getAttribute("href") || "").replace(/\/+$/, "");
        if (!/^\/manager(\/|$)/.test(href)) return;
        var match = href === "/manager" ? target === "/manager" : target === href || target.indexOf(href + "/") === 0;
        if (match && (!best || href.length > best.getAttribute("href").length)) best = link;
      });
    }
    links.forEach(function (link) {
      if (link.classList.contains("ql-nav-current") !== (link === best)) link.classList.toggle("ql-nav-current", link === best);
    });
  }

  /* ---------------------------------------------------------------
   * Manager console: a back link on the single-quiz page, which has
   * no way back to the quiz list of its own.
   * ------------------------------------------------------------- */
  function syncQuizBackLink() {
    var existing = document.getElementById("ql-quiz-back");
    var page = /^\/(admin|manager)\/quizzes\/\d+\/?$/i.exec(window.location.pathname);
    var host = document.querySelector("#root main");
    if (!page || !host) {
      if (existing) existing.remove();
      return;
    }
    var listPath = "/" + page[1].toLowerCase() + "/quizzes";
    if (existing) {
      if (existing.getAttribute("href") !== listPath) existing.setAttribute("href", listPath);
      if (host.firstChild !== existing) host.insertBefore(existing, host.firstChild);
      return;
    }
    var link = document.createElement("a");
    link.id = "ql-quiz-back";
    link.className = "ql-console-back";
    link.href = listPath;
    link.textContent = "← All quizzes";
    link.addEventListener("click", function (event) {
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      // Use the sidebar's own link so the app switches page without a reload.
      var nav = null;
      document.querySelectorAll("#root aside nav a[href]").forEach(function (item) {
        if (!nav && /\/quizzes\/?$/.test(item.getAttribute("href"))) nav = item;
      });
      if (nav) { event.preventDefault(); nav.click(); }
    });
    host.insertBefore(link, host.firstChild);
  }

  /* ---------------------------------------------------------------
   * Student sidebar: a link back to the public home page, placed just
   * above the account block at the bottom.
   * ------------------------------------------------------------- */
  function syncHomeLink() {
    document.querySelectorAll("#root aside").forEach(function (aside) {
      if (!aside.querySelector('nav a[href="/dashboard"]')) return;
      var existing = aside.querySelector(":scope > .ql-home-link");
      var footer = null;
      Array.prototype.forEach.call(aside.children, function (child) {
        if (child.tagName === "DIV" && /\bborder-t\b/.test(child.className)) footer = child;
      });
      if (!footer) return;
      if (existing) {
        if (existing.nextElementSibling !== footer) aside.insertBefore(existing, footer);
        return;
      }
      var link = document.createElement("a");
      link.className = "ql-home-link";
      link.href = "/";
      link.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 9.5V21h14V9.5"/><path d="M10 21v-6h4v6"/></svg><span>Home page</span>';
      aside.insertBefore(link, footer);
    });
  }

  /* ---------------------------------------------------------------
   * Practice course page: tag the header and the paper-type tabs so
   * storefront-dashboard.css can lay them out as tiles.
   * ------------------------------------------------------------- */
  function decorateCoursePage() {
    if (!/^\/practice\/[^/]+(\/papers)?\/?$/i.test(window.location.pathname)) return;
    var first = null;
    document.querySelectorAll("#root main button").forEach(function (button) {
      if (!first && /^Practice Assignment/i.test(button.textContent.trim())) first = button;
    });
    var tabs = first && first.parentElement;
    if (!tabs || tabs.querySelectorAll("button").length < 6) return;
    tag(tabs, "data-ql-course-tabs", "");
    if (tabs.parentElement) tag(tabs.parentElement, "data-ql-course-tabrow", "");
    tabs.querySelectorAll("button").forEach(function (button) {
      var count = button.lastElementChild ? button.lastElementChild.textContent.trim() : "";
      tag(button, "data-empty", /\/0$/.test(count) ? "true" : "false");
    });
    // Paper types with no papers are hidden; if the open one is empty, open the first that has papers.
    var filled = tabs.querySelectorAll('button[data-empty="false"]');
    tag(tabs, "data-all-empty", filled.length ? "false" : "true");
    var active = tabs.querySelector("button.bg-brand");
    var key = window.location.pathname;
    if (filled.length && active && active.getAttribute("data-empty") === "true" && tabs.getAttribute("data-ql-autopick") !== key) {
      tabs.setAttribute("data-ql-autopick", key);
      filled[0].click();
    }
    var heading = document.querySelector("#root main h1");
    var card = heading && heading.closest(".rounded-2xl");
    if (card) tag(card, "data-ql-course-head", "");
  }

  /* ---------------------------------------------------------------
   * Brand: Ensure Quiz LAB by GenZ IITian is displayed everywhere.
   * ------------------------------------------------------------- */
  function syncBrandName() {
    var epLogo = document.querySelector("#ep-role-switcher .brand-logo");
    if (epLogo) {
      var spans = epLogo.querySelectorAll("span");
      for (var s = 0; s < spans.length; s++) {
        if (spans[s].textContent.trim() === "Exam Portal") {
          spans[s].outerHTML =
            '<div class="ql-brand-wrap" style="display:inline-flex;flex-direction:column;line-height:1.15;vertical-align:middle;">' +
              '<span style="font-size:14px;font-weight:800;color:#ffffff;letter-spacing:-0.01em;">Quiz LAB</span>' +
              '<span style="font-size:10px;color:#94a3b8;font-weight:500;">by GenZ <span style="color:#22c55e;font-style:italic;font-weight:700;">IITian</span></span>' +
            '</div>';
          break;
        }
      }
    }

    var elements = document.querySelectorAll("#root span, #root div, #root h1");
    for (var i = 0; i < elements.length; i++) {
      var el = elements[i];
      if (el.dataset.qlBrandDone) continue;
      var txt = el.textContent || "";
      if (txt.includes("Gen-Z") && txt.includes("IITian")) {
        var hasDeeper = false;
        for (var c = 0; c < el.children.length; c++) {
          var chTxt = el.children[c].textContent || "";
          if (chTxt.includes("Gen-Z") && chTxt.includes("IITian")) {
            hasDeeper = true;
            break;
          }
        }
        if (hasDeeper) continue;

        var isAdmin = /admin/i.test(txt);
        var isWhite = el.classList.contains("text-white") ||
                      (el.closest && (el.closest("aside") || el.closest(".border-\\[\\#1f2937\\]"))) ||
                      (window.getComputedStyle(el).color === "rgb(255, 255, 255)");

        el.dataset.qlBrandDone = "true";
        el.innerHTML =
          '<div class="ql-brand-wrap" style="display:inline-flex;flex-direction:column;line-height:1.15;vertical-align:middle;">' +
            '<div style="display:inline-flex;align-items:center;">' +
              '<span style="font-size:15px;font-weight:800;letter-spacing:-0.01em;' + (isWhite ? 'color:#ffffff;' : 'color:#0f172a;') + '">Quiz LAB</span>' +
              (isAdmin ? '<span style="margin-left:8px;border-radius:4px;background:#1f2937;padding:2px 6px;font-size:9px;font-weight:700;text-transform:uppercase;color:#94a3b8;">Admin</span>' : '') +
            '</div>' +
            '<span style="font-size:10.5px;font-weight:500;' + (isWhite ? 'color:#94a3b8;' : 'color:#64748b;') + '">by GenZ <span style="color:#16a34a;font-style:italic;font-weight:700;">IITian</span></span>' +
          '</div>';
      }
    }
  }

  /* ---------------------------------------------------------------
   * Papers open in the self-paced paper room (/paper/{id}) and the Exam
   * tab opens the online exam platform. Both are separate pages, so
   * these links must load a page instead of routing inside the app.
   * ------------------------------------------------------------- */
  function storedRole() {
    try { return JSON.parse(localStorage.getItem("lab_user") || "{}").role || ""; } catch (_) { return ""; }
  }

  function paperRoomPath(pathname) {
    var m = /^\/quiz\/(\d+)\/?$/.exec(pathname || "");
    return m ? "/paper/" + m[1] : "";
  }

  document.addEventListener("click", function (event) {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    var link = event.target && event.target.closest ? event.target.closest("a[href]") : null;
    if (!link || link.target === "_blank" || link.origin !== window.location.origin) return;
    var paper = paperRoomPath(link.pathname);
    if (paper) {
      event.preventDefault();
      event.stopPropagation();
      window.location.assign(paper);
    } else if (/^\/exams?\/?$/.test(link.pathname) && !/^\/(admin|manager)(\/|$)/.test(window.location.pathname) && storedRole() === "manager") {
      // A manager browsing the student view gets the student-facing exam list.
      event.preventDefault();
      event.stopPropagation();
      window.location.assign("/exams?preview=student");
    } else if (/^\/(exams?(\/|$)|manager\/(discussions|sales)\/?$|paper-pricing\/?$)/.test(link.pathname)) {
      event.stopPropagation();
    }
  }, true);

  /* Practice list: tag the heading and search box for styling, and type course names into the search placeholder. */
  var practiceTyping = null;
  function decoratePracticeList() {
    if (window.location.pathname.replace(/\/+$/, "") !== "/practice") {
      if (practiceTyping) { clearInterval(practiceTyping.timer); practiceTyping = null; }
      return;
    }
    var heads = document.querySelectorAll("h1");
    for (var i = 0; i < heads.length; i++) {
      var h = heads[i];
      if (/^Brush up at your own pace\.?$/.test((h.textContent || "").trim()) && h.parentElement && !h.parentElement.hasAttribute("data-ql-practice-head")) {
        h.parentElement.setAttribute("data-ql-practice-head", "");
      }
    }
    var input = document.querySelector('input[data-ql-typing], input[placeholder^="Search courses"]');
    if (!input) return;
    if (input.parentElement && !input.parentElement.hasAttribute("data-ql-practice-search")) input.parentElement.setAttribute("data-ql-practice-search", "");
    if (practiceTyping && practiceTyping.input === input) return;
    if (practiceTyping) clearInterval(practiceTyping.timer);
    input.setAttribute("data-ql-typing", "");
    input.setAttribute("aria-label", "Search courses");
    var still = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (still) { input.placeholder = "Search your courses\u2026"; practiceTyping = { input: input, timer: 0 }; return; }
    var state = { input: input, word: 0, pos: 0, hold: 0, erasing: false, timer: 0 };
    function words() {
      var names = [];
      document.querySelectorAll('a.block[href^="/practice/"] .font-semibold.text-slate-900').forEach(function (el) {
        var name = (el.textContent || "").trim();
        if (name && names.indexOf(name) < 0 && names.length < 6) names.push(name);
      });
      return names.concat(["Quiz 1 papers", "End Term prep", "Mock tests"]);
    }
    state.timer = setInterval(function () {
      if (!document.body.contains(input)) { clearInterval(state.timer); if (practiceTyping === state) practiceTyping = null; return; }
      if (document.activeElement === input || input.value) { if (input.placeholder !== "Search courses\u2026") input.placeholder = "Search courses\u2026"; state.pos = 0; state.erasing = false; state.hold = 0; return; }
      if (state.hold > 0) { state.hold--; return; }
      var list = words();
      var word = list[state.word % list.length];
      if (!state.erasing) {
        state.pos++;
        if (state.pos >= word.length) { state.pos = word.length; state.erasing = true; state.hold = 16; }
      } else {
        state.pos -= 2;
        if (state.pos <= 0) { state.pos = 0; state.erasing = false; state.word++; state.hold = 3; }
      }
      input.placeholder = "Search \u201c" + word.slice(0, state.pos) + "\u201d";
    }, 85);
    practiceTyping = state;
  }

  function run() {
    var paper = paperRoomPath(window.location.pathname);
    if (paper) { window.location.replace(paper); return; }
    syncBrandName();
    syncAdminShell();
    syncPaperPricingLink();
    removeStudentWeakSpotCard();
    decorateDashboard();
    decorateManagerConsole();
    fillMyPapers();
    decoratePracticeCards();
    decoratePracticeList();
    syncConsoleNav();
    syncHomeLink();
    decorateCoursePage();
    syncQuizBackLink();
    if (!/\/discussions/i.test(window.location.pathname)) return;
    injectStyles();
    ROWS.forEach(convertRow);
    convertDiscussionSortRow();
    // Put search, sort, subject and course on one row.
    var sortRow = document.querySelector(".ql-discussion-sort-row");
    var filterCard = sortRow && sortRow.parentElement && sortRow.parentElement.parentElement;
    if (filterCard && filterCard.getAttribute("data-ql-disc-filters") !== "") filterCard.setAttribute("data-ql-disc-filters", "");
  }

  var pending = null;
  function schedule() {
    clearTimeout(pending);
    pending = setTimeout(run, 120);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", schedule);
  } else {
    schedule();
  }

  new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
  new MutationObserver(schedule).observe(document.body, { attributes: true, attributeFilter: ["data-ep-verified-role"] });
  window.addEventListener("popstate", schedule);

  var lastPath = window.location.pathname;
  setInterval(function () {
    if (window.location.pathname !== lastPath) { lastPath = window.location.pathname; schedule(); }
  }, 500);
})();
