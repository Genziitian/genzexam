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
      ".ql-filter-select:focus{outline:none;border-color:#3a3fd8;box-shadow:0 0 0 3px rgba(58, 63, 216,.12)}" +
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
        badge.style.cssText = "display:inline-block;margin:4px 0 0 8px;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:600;background:" + (paper.approval_status === "pending" ? "#fff7ed;color:#c2410c" : paper.is_active ? "#f1f2ff;color:#2a2fa8" : "#f1f5f9;color:#475569");
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
        approve.style.cssText = "border:0;border-radius:8px;background:#3a3fd8;color:white;padding:6px 10px;font:600 12px/1.2 inherit;cursor:pointer";
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
    card.innerHTML = '<h2 style="margin:0;color:#0f172a;font-size:20px;font-weight:700">Teacher course access</h2><p style="margin:6px 0 16px;color:#64748b;font-size:14px">Choose an admin teacher, then assign the courses they can manage.</p><select id="ql-teacher-select" style="width:100%;max-width:440px;padding:10px;border:1px solid #cbd5e1;border-radius:10px"><option>Loading teachers…</option></select><div id="ql-teacher-courses" style="display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:8px;margin:16px 0"></div><div style="display:flex;align-items:center;gap:12px"><button id="ql-save-teacher-courses" type="button" style="border:0;border-radius:10px;background:#3a3fd8;color:white;padding:10px 16px;font-weight:700;cursor:pointer">Save course access</button><span id="ql-teacher-course-message" role="status" style="font-size:13px;color:#64748b"></span></div>';
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
      '<div id="ql-manager-avatar" style="width:64px;height:64px;border-radius:50%;display:flex;align-items:center;justify-content:center;overflow:hidden;background:#f1f2ff;color:#2a2fa8;font-size:21px;font-weight:700;flex:0 0 auto"></div>' +
      '<div style="min-width:0"><div id="ql-manager-profile-name" style="font-weight:700;color:#0f172a">Loading profile…</div><div id="ql-manager-profile-role" style="margin-top:4px;color:#2a2fa8;font-size:12px;font-weight:700">MANAGER</div></div></div>' +
      '<label style="display:grid;gap:6px;color:#475569;font-size:14px">Name<input id="ql-manager-name" name="name" maxlength="120" required style="width:100%;padding:11px 13px;border:1px solid #dbe3ee;border-radius:12px;color:#0f172a;background:#fff;font:inherit"></label>' +
      '<label style="display:grid;gap:6px;color:#475569;font-size:14px">Email<input id="ql-manager-email" readonly style="width:100%;padding:11px 13px;border:1px solid #dbe3ee;border-radius:12px;color:#64748b;background:#f8fafc;font:inherit"></label>' +
      '<label style="display:grid;gap:6px;color:#475569;font-size:14px">Profile photo<input id="ql-manager-photo" type="file" accept="image/png,image/jpeg,image/webp" style="color:#475569;font-size:13px"></label>' +
      '<label style="display:flex;align-items:center;gap:8px;color:#64748b;font-size:13px"><input id="ql-manager-remove-photo" type="checkbox"> Remove current photo</label>' +
      '<div style="display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap"><p id="ql-manager-profile-message" role="status" style="margin:0;color:#64748b;font-size:13px"></p><button id="ql-manager-profile-save" type="submit" style="border:0;border-radius:11px;background:#3a3fd8;color:#fff;padding:11px 17px;font-size:14px;font-weight:700;cursor:pointer">Save Profile</button></div>' +
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

  function countUp(el) {
    if (el.hasAttribute("data-ql-counted")) return;
    var node = el.firstChild;
    if (!node || node.nodeType !== 3) return;
    var match = /^(\D*)(\d+(?:\.\d+)?)$/.exec(node.nodeValue.trim());
    if (!match) return;
    el.setAttribute("data-ql-counted", "");
    var target = Number(match[2]);
    if (!target || (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches)) return;
    var prefix = match[1], decimals = (match[2].split(".")[1] || "").length, finalText = node.nodeValue, started = 0;
    function frame(now) {
      if (!started) started = now;
      // React re-rendered a new value meanwhile: leave it alone.
      if (!el.isConnected || el.firstChild !== node) return;
      var t = Math.min(1, (now - started) / 900);
      if (t >= 1) { node.nodeValue = finalText; return; }
      node.nodeValue = prefix + (target * (1 - Math.pow(1 - t, 3))).toFixed(decimals);
      requestAnimationFrame(frame);
    }
    node.nodeValue = prefix + (0).toFixed(decimals);
    requestAnimationFrame(frame);
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

    /* Numbers on the stat cards and the performance card count up once when they first appear. */
    root.querySelectorAll("[data-ql-stat] .leading-none, [data-ql-card=perf] .leading-none").forEach(countUp);

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

    function getLikedIds() {
      try {
        var raw = localStorage.getItem("ql_liked_papers");
        return new Set(raw ? JSON.parse(raw) : []);
      } catch (_) {
        return new Set();
      }
    }
    function saveLikedIds(set) {
      try {
        localStorage.setItem("ql_liked_papers", JSON.stringify(Array.from(set)));
      } catch (_) {}
    }
    var likedIds = getLikedIds();

    var filters = {
      liked: false,
      status: "all",
      access: "all",
      section: "all",
      course: "all",
      sort: "newest"
    };

    host.innerHTML = '<div class="ql-mp-head">' +
      '<div class="ql-mp-title">' +
        '<h1>Your papers.</h1>' +
        '<div class="ql-mp-title-actions">' +
          '<a class="ql-mp-browse" href="/practice">Browse practice</a>' +
          '<a class="ql-mp-browse" href="/try-practice">🎯 Try your practice</a>' +
          '<button class="ql-upload-open" type="button">＋ Upload a paper <span class="ql-upload-tag">PRO</span></button>' +
          '<button class="ql-mp-filter-btn" type="button" aria-label="Filter papers">' +
            '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"></polygon></svg>' +
            '<span>Filter</span>' +
            '<span class="ql-mp-filter-count" style="display:none">0</span>' +
          '</button>' +
        '</div>' +
      '</div>' +
      '<p>Papers you bought or attempted, with your progress.</p>' +
      '<div class="ql-mp-quick-bar" role="tablist" aria-label="Paper quick filters">' +
        '<button type="button" class="ql-mp-qchip active" data-qfilter="all">All</button>' +
        '<button type="button" class="ql-mp-qchip" data-qfilter="liked"><svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg> Liked</button>' +
        '<button type="button" class="ql-mp-qchip" data-qfilter="in_progress">In progress</button>' +
        '<button type="button" class="ql-mp-qchip" data-qfilter="completed">Completed</button>' +
      '</div>' +
    '</div>' +
    '<div class="ql-mp-grid" aria-live="polite"><p class="ql-mp-note">Loading your papers…</p></div>';

    installUploadedPaperDialog(host, runtime);
    var grid = host.querySelector(".ql-mp-grid");

    function note(text, actionText, onAction) {
      grid.replaceChildren();
      var p = document.createElement("p");
      p.className = "ql-mp-note";
      p.textContent = text;
      if (actionText && onAction) {
        var btn = document.createElement("button");
        btn.type = "button";
        btn.className = "ql-mp-action";
        btn.style.cssText = "max-width:220px;margin:14px auto 0";
        btn.textContent = actionText;
        btn.addEventListener("click", onAction);
        p.appendChild(document.createElement("br"));
        p.appendChild(btn);
      }
      grid.appendChild(p);
    }

    function countActiveFilters() {
      var count = 0;
      if (filters.liked) count++;
      if (filters.status !== "all") count++;
      if (filters.access !== "all") count++;
      if (filters.section !== "all") count++;
      if (filters.course !== "all") count++;
      if (filters.sort !== "newest") count++;
      return count;
    }

    function syncFilterUI() {
      var badge = host.querySelector(".ql-mp-filter-count");
      if (badge) {
        var count = countActiveFilters();
        badge.style.display = count > 0 ? "inline-flex" : "none";
        badge.textContent = String(count);
      }
      var qchips = host.querySelectorAll(".ql-mp-qchip");
      qchips.forEach(function (btn) {
        var q = btn.dataset.qfilter;
        var active = false;
        if (q === "all") active = !filters.liked && filters.status === "all";
        else if (q === "liked") active = filters.liked;
        else if (q === "in_progress") active = !filters.liked && filters.status === "in_progress";
        else if (q === "completed") active = !filters.liked && filters.status === "completed";
        btn.classList.toggle("active", active);
      });
    }

    fetch(runtime.apiBase + "/storefront/my-papers", {
      headers: { Accept: "application/json", Authorization: "Bearer " + runtime.token() }
    }).then(function (response) {
      if (response.status === 403) throw new Error("role");
      if (!response.ok) throw new Error("load");
      return response.json();
    }).then(function (data) {
      if (!host.isConnected) return;
      var rawPapers = Array.isArray(data.papers) ? data.papers.slice() : [];
      if (!rawPapers.length) {
        return note("Nothing here yet. Start any free paper from Practice, or buy a paper, and it shows up here with your score.");
      }

      var labels = { quiz1: "Quiz 1", quiz2: "Quiz 2", endterm: "End Term", mock_test: "Mock test", practice: "Practice", practice_graded: "Graded practice" };

      function matchesFilter(paper, stateObj) {
        var s = stateObj || filters;
        if (s.liked && !likedIds.has(Number(paper.id))) return false;
        if (s.status === "in_progress" && !paper.in_progress) return false;
        if (s.status === "completed" && (!paper.attempt_count || paper.in_progress)) return false;
        if (s.status === "not_started" && (paper.attempt_count > 0 || paper.in_progress)) return false;
        if (s.access === "free" && (Number(paper.price_paise || 0) > 0 || paper.source === "personal_upload")) return false;
        if (s.access === "purchased" && !(paper.purchased === true || paper.source === "purchase")) return false;
        if (s.access === "upload" && paper.source !== "personal_upload") return false;
        if (s.section !== "all" && paper.section !== s.section) return false;
        if (s.course !== "all" && (paper.course || {}).name !== s.course) return false;
        return true;
      }

      function sortPapers(list, sortKey) {
        var out = list.slice();
        if (sortKey === "title") {
          out.sort(function (a, b) { return (a.title || "").localeCompare(b.title || ""); });
        } else if (sortKey === "attempts") {
          out.sort(function (a, b) { return Number(b.attempt_count || 0) - Number(a.attempt_count || 0); });
        } else if (sortKey === "score") {
          out.sort(function (a, b) {
            var pctA = a.last_total_marks ? Number(a.last_score || 0) / Number(a.last_total_marks) : 0;
            var pctB = b.last_total_marks ? Number(b.last_score || 0) / Number(b.last_total_marks) : 0;
            return pctB - pctA;
          });
        } else {
          out.sort(function (a, b) { return Number(b.id) - Number(a.id); });
        }
        return out;
      }

      function render() {
        syncFilterUI();
        var filtered = rawPapers.filter(function (p) { return matchesFilter(p, filters); });
        var sorted = sortPapers(filtered, filters.sort);

        if (!sorted.length) {
          if (filters.liked) {
            return note("No liked papers yet. Tap the heart on any paper card to save it to your favorites.", "Show all papers", function () {
              filters.liked = false;
              filters.status = "all";
              render();
            });
          }
          return note("No papers match your filters.", "Reset filters", function () {
            filters.liked = false;
            filters.status = "all";
            filters.access = "all";
            filters.section = "all";
            filters.course = "all";
            filters.sort = "newest";
            render();
          });
        }

        grid.replaceChildren();
        sorted.forEach(function (paper) {
          var paid = Number(paper.price_paise || 0) > 0;
          var purchased = paper.purchased === true || paper.source === "purchase";
          var uploaded = paper.source === "personal_upload";
          var isSpin = paper.source === "spin_practice";
          var expired = paid && !!paper.expired;
          var usable = paper.available !== false && paper.has_access !== false && !expired;
          var attempts = Number(paper.attempt_count || 0);
          var state = paper.available === false ? "Unavailable" : expired ? "Access expired" : purchased ? "Purchased \u2713" : isSpin ? "Practice" : uploaded ? "Uploaded" : paid ? "Paid" : "Free";

          var card = document.createElement("article");
          card.className = "ql-mp-card" + (purchased && usable ? " owned" : "");

          // Heart favorite button
          var isLiked = likedIds.has(Number(paper.id));
          var heart = document.createElement("button");
          heart.type = "button";
          heart.className = "ql-mp-heart" + (isLiked ? " active" : "");
          heart.setAttribute("aria-label", isLiked ? "Remove from favorites" : "Save to favorites");
          heart.title = isLiked ? "Remove from favorites" : "Save to favorites";
          heart.innerHTML = '<svg width="17" height="17" viewBox="0 0 24 24" fill="' + (isLiked ? "currentColor" : "none") + '" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path></svg>';
          heart.addEventListener("click", function (e) {
            e.stopPropagation();
            var pid = Number(paper.id);
            if (likedIds.has(pid)) {
              likedIds.delete(pid);
              heart.classList.remove("active");
              heart.querySelector("svg").setAttribute("fill", "none");
              heart.title = "Save to favorites";
            } else {
              likedIds.add(pid);
              heart.classList.add("active");
              heart.querySelector("svg").setAttribute("fill", "currentColor");
              heart.title = "Remove from favorites";
            }
            saveLikedIds(likedIds);
            if (filters.liked) render();
          });
          card.appendChild(heart);

          var badge = document.createElement("span");
          badge.className = "ql-mp-badge" + (paper.available === false || expired ? " off" : purchased ? " paid" : paid ? " lock" : "");
          badge.textContent = state;

          var title = document.createElement("h3");
          title.textContent = paper.title || "Paper";

          var sub = document.createElement("p");
          sub.className = "ql-mp-sub";
          sub.textContent = [uploaded ? "Your upload" : isSpin ? ((paper.course || {}).name + " · Spin Practice") : (paper.course || {}).name, paper.year, isSpin ? "" : labels[paper.section]].filter(Boolean).join(" · ");

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
              details.addEventListener("click", function (event) {
                if (event.metaKey || event.ctrlKey || event.shiftKey || event.button) return;
                event.preventDefault();
                showPaperDetails(paper, labels, state, usable, attempts, action.href);
              });
              actions.appendChild(details);
            }
            actions.appendChild(action);
            if (window.QLShare) actions.appendChild(window.QLShare.button(paper.id, paper.title || "", "ql-share-icon"));
            card.appendChild(actions);
          }
          grid.appendChild(card);
        });
      }

      // Quick filter click handlers
      host.querySelectorAll(".ql-mp-qchip").forEach(function (btn) {
        btn.addEventListener("click", function () {
          var q = btn.dataset.qfilter;
          if (q === "all") {
            filters.liked = false;
            filters.status = "all";
          } else if (q === "liked") {
            filters.liked = true;
            filters.status = "all";
          } else if (q === "in_progress") {
            filters.liked = false;
            filters.status = "in_progress";
          } else if (q === "completed") {
            filters.liked = false;
            filters.status = "completed";
          }
          render();
        });
      });

      // Filter modal setup
      var filterBtn = host.querySelector(".ql-mp-filter-btn");
      if (filterBtn) {
        filterBtn.addEventListener("click", function () {
          var draft = Object.assign({}, filters);
          var overlay = document.createElement("div");
          overlay.className = "ql-fm-overlay";
          overlay.setAttribute("role", "dialog");
          overlay.setAttribute("aria-modal", "true");

          var distinctCourses = Array.from(new Set(rawPapers.map(function (p) { return (p.course || {}).name; }).filter(Boolean))).sort();

          overlay.innerHTML = '<div class="ql-fm-modal">' +
            '<div class="ql-fm-header">' +
              '<div><h2>Filter Papers</h2><p>Choose filter options to narrow down your papers.</p></div>' +
              '<button type="button" class="ql-fm-close" aria-label="Close">✕</button>' +
            '</div>' +
            '<div class="ql-fm-body">' +
              '<div class="ql-fm-group">' +
                '<label>Favorites</label>' +
                '<div class="ql-fm-chips" data-fkey="liked">' +
                  '<button type="button" class="ql-fm-chip' + (!draft.liked ? ' active' : '') + '" data-val="all">All papers</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.liked ? ' active' : '') + '" data-val="liked">❤️ Liked only</button>' +
                '</div>' +
              '</div>' +
              '<div class="ql-fm-group">' +
                '<label>Status & Progress</label>' +
                '<div class="ql-fm-chips" data-fkey="status">' +
                  '<button type="button" class="ql-fm-chip' + (draft.status === 'all' ? ' active' : '') + '" data-val="all">All</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.status === 'in_progress' ? ' active' : '') + '" data-val="in_progress">In progress</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.status === 'completed' ? ' active' : '') + '" data-val="completed">Completed</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.status === 'not_started' ? ' active' : '') + '" data-val="not_started">Not started</button>' +
                '</div>' +
              '</div>' +
              '<div class="ql-fm-group">' +
                '<label>Access & Pricing</label>' +
                '<div class="ql-fm-chips" data-fkey="access">' +
                  '<button type="button" class="ql-fm-chip' + (draft.access === 'all' ? ' active' : '') + '" data-val="all">All</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.access === 'free' ? ' active' : '') + '" data-val="free">Free</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.access === 'purchased' ? ' active' : '') + '" data-val="purchased">Purchased</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.access === 'upload' ? ' active' : '') + '" data-val="upload">Your uploads</button>' +
                '</div>' +
              '</div>' +
              '<div class="ql-fm-group">' +
                '<label>Exam Section</label>' +
                '<div class="ql-fm-chips" data-fkey="section">' +
                  '<button type="button" class="ql-fm-chip' + (draft.section === 'all' ? ' active' : '') + '" data-val="all">All</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.section === 'quiz1' ? ' active' : '') + '" data-val="quiz1">Quiz 1</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.section === 'quiz2' ? ' active' : '') + '" data-val="quiz2">Quiz 2</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.section === 'endterm' ? ' active' : '') + '" data-val="endterm">End Term</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.section === 'mock_test' ? ' active' : '') + '" data-val="mock_test">Mock Test</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.section === 'practice' ? ' active' : '') + '" data-val="practice">Practice</button>' +
                '</div>' +
              '</div>' +
              (distinctCourses.length ? (
                '<div class="ql-fm-group">' +
                  '<label for="ql-fm-course-select">Course</label>' +
                  '<select id="ql-fm-course-select" class="ql-fm-select">' +
                    '<option value="all"' + (draft.course === 'all' ? ' selected' : '') + '>All courses (' + distinctCourses.length + ')</option>' +
                    distinctCourses.map(function (c) {
                      return '<option value="' + c.replace(/"/g, '&quot;') + '"' + (draft.course === c ? ' selected' : '') + '>' + c.replace(/</g, '&lt;') + '</option>';
                    }).join('') +
                  '</select>' +
                '</div>'
              ) : '') +
              '<div class="ql-fm-group">' +
                '<label>Sort By</label>' +
                '<div class="ql-fm-chips" data-fkey="sort">' +
                  '<button type="button" class="ql-fm-chip' + (draft.sort === 'newest' ? ' active' : '') + '" data-val="newest">Newest first</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.sort === 'title' ? ' active' : '') + '" data-val="title">Title (A-Z)</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.sort === 'attempts' ? ' active' : '') + '" data-val="attempts">Most attempted</button>' +
                  '<button type="button" class="ql-fm-chip' + (draft.sort === 'score' ? ' active' : '') + '" data-val="score">Highest score</button>' +
                '</div>' +
              '</div>' +
            '</div>' +
            '<div class="ql-fm-footer">' +
              '<button type="button" class="ql-fm-reset">Reset filters</button>' +
              '<button type="button" class="ql-fm-apply">Apply filters (<span class="ql-fm-count">0</span>)</button>' +
            '</div>' +
          '</div>';

          function updateDraftCount() {
            var matching = rawPapers.filter(function (p) { return matchesFilter(p, draft); });
            var countEl = overlay.querySelector(".ql-fm-count");
            if (countEl) countEl.textContent = String(matching.length);
          }
          updateDraftCount();

          function close() {
            document.removeEventListener("keydown", onKey);
            overlay.remove();
          }
          function onKey(e) { if (e.key === "Escape") close(); }

          overlay.querySelector(".ql-fm-close").addEventListener("click", close);
          overlay.addEventListener("click", function (e) { if (e.target === overlay) close(); });

          overlay.querySelectorAll(".ql-fm-chips").forEach(function (group) {
            var fkey = group.dataset.fkey;
            group.querySelectorAll(".ql-fm-chip").forEach(function (chip) {
              chip.addEventListener("click", function () {
                var val = chip.dataset.val;
                if (fkey === "liked") draft.liked = (val === "liked");
                else draft[fkey] = val;

                group.querySelectorAll(".ql-fm-chip").forEach(function (c) { c.classList.remove("active"); });
                chip.classList.add("active");
                updateDraftCount();
              });
            });
          });

          var courseSelect = overlay.querySelector("#ql-fm-course-select");
          if (courseSelect) {
            courseSelect.addEventListener("change", function () {
              draft.course = courseSelect.value;
              updateDraftCount();
            });
          }

          overlay.querySelector(".ql-fm-reset").addEventListener("click", function () {
            draft = { liked: false, status: "all", access: "all", section: "all", course: "all", sort: "newest" };
            filters = Object.assign({}, draft);
            close();
            render();
          });

          overlay.querySelector(".ql-fm-apply").addEventListener("click", function () {
            filters = Object.assign({}, draft);
            close();
            render();
          });

          document.addEventListener("keydown", onKey);
          document.body.appendChild(overlay);
        });
      }

      render();
    }).catch(function (error) {
      if (!host.isConnected) return;
      note(error.message === "role" ? "My Papers is for student accounts. Managers handle papers and sales from the manager console." : "Your papers could not load. Check your connection and reload the page.");
    });
  }

  function showPaperDetails(paper, labels, state, usable, attempts, startHref) {
    if (!document.getElementById("ql-pd-style")) {
      var st = document.createElement("style");
      st.id = "ql-pd-style";
      st.textContent = ".ql-pd-overlay{position:fixed;inset:0;z-index:99999;background:rgba(15,23,42,.62);display:grid;place-items:center;padding:18px}.ql-pd{width:min(560px,100%);max-height:90vh;overflow:auto;background:#fff;border-radius:22px;padding:26px;box-shadow:0 24px 80px #121a2755;color:#0f172a}.ql-pd-top{display:flex;justify-content:space-between;align-items:flex-start;gap:12px}.ql-pd h2{margin:0;font-size:22px;line-height:1.25;letter-spacing:-.01em}.ql-pd-sub{margin:6px 0 0;color:#64748b;font-size:14px}.ql-pd-x{flex:none;border:0;background:#f1f5f9;color:#334155;border-radius:50%;width:36px;height:36px;font-size:20px;cursor:pointer}.ql-pd-desc{margin:16px 0 0;color:#334155;line-height:1.6;font-size:14.5px}.ql-pd-facts{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px;margin:18px 0 0}.ql-pd-facts div{background:#f1f2ff;border-radius:14px;padding:11px 14px}.ql-pd-facts dt{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:#64748b;font-weight:600}.ql-pd-facts dd{margin:3px 0 0;font-weight:700;font-size:14.5px;color:#0f172a}.ql-pd-note{margin:16px 0 0;font-size:13px;color:#64748b}.ql-pd-actions{display:flex;gap:10px;margin-top:20px}.ql-pd-actions a,.ql-pd-actions button{flex:1;text-align:center;border-radius:13px;padding:13px;font:700 14.5px inherit;text-decoration:none;cursor:pointer;border:1px solid #c9ccf5;background:#fff;color:#3a3fd8}.ql-pd-actions a.go{background:#3a3fd8;border-color:#3a3fd8;color:#fff}.ql-pd-actions a.go:hover{background:#2b30b8}@media(max-width:480px){.ql-pd{padding:20px}.ql-pd-facts{grid-template-columns:1fr}}";
      document.head.appendChild(st);
    }
    var last = document.activeElement;
    var overlay = document.createElement("div");
    overlay.className = "ql-pd-overlay";
    var box = document.createElement("div");
    box.className = "ql-pd";
    box.setAttribute("role", "dialog");
    box.setAttribute("aria-modal", "true");
    function el(tag, cls, text) { var n = document.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; }
    function close() { document.removeEventListener("keydown", onKey); overlay.remove(); if (last && last.focus) last.focus(); }
    function onKey(e) { if (e.key === "Escape") close(); }
    var top = el("div", "ql-pd-top");
    var heading = el("div");
    heading.appendChild(el("h2", "", paper.title || "Paper"));
    heading.appendChild(el("p", "ql-pd-sub", [(paper.course || {}).name, (paper.course || {}).level, paper.year].filter(Boolean).join(" · ")));
    var x = el("button", "ql-pd-x", "×");
    x.type = "button";
    x.setAttribute("aria-label", "Close");
    x.addEventListener("click", close);
    top.append(heading, x);
    box.appendChild(top);
    box.appendChild(el("p", "ql-pd-desc", paper.description || "Practice this paper and review your progress from your student dashboard."));
    var facts = el("dl", "ql-pd-facts");
    var rows = [
      ["Paper type", labels[paper.section] || paper.section || "Practice paper"],
      ["Questions", paper.question_count != null ? paper.question_count : "See paper"],
      ["Time limit", paper.time_limit_minutes ? paper.time_limit_minutes + " minutes" : "No time limit"],
      ["Status", state],
      ["Attempts", attempts],
      ["Last score", attempts && paper.last_total_marks != null ? Number(paper.last_score || 0) + "/" + Number(paper.last_total_marks) : "—"]
    ];
    if (paper.expires_at && Number(paper.price_paise || 0) > 0) rows.push(["Access until", new Date(paper.expires_at).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" })]);
    rows.forEach(function (r) { var d = el("div"); d.append(el("dt", "", r[0]), el("dd", "", String(r[1]))); facts.appendChild(d); });
    box.appendChild(facts);
    var actions = el("div", "ql-pd-actions");
    var closeBtn = el("button", "", "Close");
    closeBtn.type = "button";
    closeBtn.addEventListener("click", close);
    actions.appendChild(closeBtn);
    if (usable) { var go = el("a", "go", paper.in_progress ? "Continue" : attempts ? "Attempt again" : "Start"); go.href = startHref; actions.appendChild(go); }
    box.appendChild(actions);
    overlay.appendChild(box);
    overlay.addEventListener("click", function (e) { if (e.target === overlay) close(); });
    document.addEventListener("keydown", onKey);
    document.body.appendChild(overlay);
    x.focus();
  }

  function installUploadedPaperDialog(host, runtime) {
    var styleId = "ql-upload-paper-style";
    if (!document.getElementById(styleId)) {
      var style = document.createElement("style");
      style.id = styleId;
      style.textContent = ".ql-upload-open{margin:0;border:0;border-radius:13px;background:#3a3fd8;color:#fff;padding:12px 18px;font:700 14px inherit;cursor:pointer;white-space:nowrap;transition:transform .15s ease,background .15s ease,box-shadow .15s ease}.ql-upload-open:hover{background:#2b30b8;transform:translateY(-1px);box-shadow:0 10px 20px -10px #3a3fd8}.ql-mp-title-actions{display:flex;align-items:center;gap:10px;flex-wrap:wrap}\n.ql-upload-overlay{position:fixed;inset:0;z-index:99999;background:#f8fafc;display:flex;flex-direction:column;padding:0;overflow-y:auto;animation:qlu-fade .2s ease}\n:root[data-theme=dark] .ql-upload-overlay{background:#0b0f19}\n.ql-upload-modal{width:100%;min-height:100vh;max-height:none;overflow:visible;background:#fff;border-radius:0;box-shadow:none;color:#0f172a;display:flex;flex-direction:column;animation:qlu-rise .25s ease}\n:root[data-theme=dark] .ql-upload-modal{background:#0f172a;color:#f8fafc}\n.ql-upload-hero{position:relative;padding:36px 32px 28px;background:linear-gradient(135deg,#3a3fd8,#6a6ff0 70%,#8b90ff);color:#fff;border-radius:0;overflow:hidden;flex-shrink:0}\n.ql-upload-hero-inner{max-width:1000px;margin:0 auto;position:relative;width:100%}\n.ql-upload-hero::after{content:\"\";position:absolute;right:-50px;top:-60px;width:240px;height:240px;border-radius:50%;background:rgba(255,255,255,.14);pointer-events:none}\n.ql-upload-hero h2{margin:0;font-size:30px;line-height:1.25;letter-spacing:-.02em;position:relative}.ql-upload-hero p{margin:8px 0 0;max-width:680px;color:#e6e7ff;line-height:1.5;font-size:15px;position:relative}\n.ql-upload-pro{display:inline-block;margin-bottom:10px;padding:3px 10px;border-radius:999px;background:#ffc24b;color:#0e1330;font-size:11px;font-weight:800;letter-spacing:.08em;position:relative}\n.ql-upload-close{position:absolute;right:0;top:0;z-index:2;border:0;background:rgba(255,255,255,.2);color:#fff;border-radius:50%;width:40px;height:40px;font-size:24px;cursor:pointer;transition:background .15s,transform .2s;display:grid;place-items:center}.ql-upload-close:hover{background:rgba(255,255,255,.34);transform:rotate(90deg)}\n.ql-upload-body{padding:32px 32px 64px;display:grid;gap:24px;max-width:1000px;margin:0 auto;width:100%;box-sizing:border-box;flex:1}\n.ql-upload-quota{border-radius:18px;padding:18px 22px;background:#f1f2ff;border:1px solid #d5d8f7}.ql-upload-quota.locked{background:#fff7e0;border-color:#fde68a}.ql-upload-quota.empty{background:#fdecea;border-color:#f6c6c1}\n.ql-upload-quota-top{display:flex;justify-content:space-between;align-items:baseline;gap:10px;flex-wrap:wrap}.ql-upload-quota strong{font-size:16px}.ql-upload-quota small{color:#64748b;font-size:13px}\n.ql-upload-meter{display:flex;gap:6px;margin-top:12px}.ql-upload-meter i{flex:1;height:10px;border-radius:6px;background:#3a3fd8;transform-origin:left;animation:qlu-grow .5s cubic-bezier(.2,.8,.2,1) backwards}.ql-upload-meter i.used{background:#c9ccf5}\n.ql-upload-quota .ql-upload-upgrade{display:inline-block;margin-top:12px;padding:10px 18px;border-radius:11px;background:#3a3fd8;color:#fff;font-weight:700;font-size:13.5px;text-decoration:none;border:0;cursor:pointer;font-family:inherit}\n.ql-upload-steps{display:grid;grid-template-columns:1fr auto 1fr auto 1fr;gap:12px;align-items:center;text-align:center}\n.ql-upload-steps>div{padding:14px 10px;border-radius:16px;background:#f8fafc;border:1px solid #e2e8f0;animation:qlu-rise .5s ease backwards}.ql-upload-steps>div:nth-of-type(2){animation-delay:.12s}.ql-upload-steps>div:nth-of-type(3){animation-delay:.24s}\n.ql-upload-steps span{display:block;font-size:12.5px;font-weight:700}.ql-upload-icon{font-size:26px;margin-bottom:6px;display:inline-block;animation:qlu-bob 2.6s ease-in-out infinite}\n.ql-upload-steps b{color:#3a3fd8;font-size:18px;animation:qlu-nudge 1.4s ease-in-out infinite}\n.ql-upload-drop{position:relative;display:grid;place-items:center;gap:6px;text-align:center;padding:36px 24px;border:2px dashed #b9bedc;border-radius:22px;background:#f8f9ff;cursor:pointer;transition:border-color .15s,background .15s,transform .15s}\n.ql-upload-drop:hover,.ql-upload-drop.over{border-color:#3a3fd8;background:#eef0ff;transform:translateY(-1px)}.ql-upload-drop.disabled{opacity:.55;cursor:not-allowed;pointer-events:none}\n.ql-upload-drop .big{font-size:36px;animation:qlu-bob 2.2s ease-in-out infinite}.ql-upload-drop strong{font-size:16px}.ql-upload-drop small{color:#64748b}.ql-upload-drop input{position:absolute;inset:0;opacity:0;cursor:pointer}\n.ql-upload-chip{display:none;align-items:center;gap:10px;padding:12px 16px;border-radius:12px;background:#ecedff;color:#1b1f7a;font-weight:700;font-size:14px}.ql-upload-chip.on{display:flex;animation:qlu-rise .25s ease}\n.ql-upload-pick{display:block;width:100%;border:0;border-radius:14px;padding:16px;background:#3a3fd8;color:#fff;font-size:16px;font-weight:800;cursor:pointer;position:relative;overflow:hidden;transition:background .15s,transform .15s}.ql-upload-pick:hover:not(:disabled){background:#2b30b8;transform:translateY(-1px)}.ql-upload-pick:disabled{opacity:.55;cursor:not-allowed}\n.ql-upload-pick.busy{cursor:wait;opacity:1}.ql-upload-pick.busy::after{content:\"\";position:absolute;inset:0;background:linear-gradient(90deg,transparent,rgba(255,255,255,.35),transparent);animation:qlu-sheen 1.2s linear infinite}\n.ql-upload-state{margin:0;font-size:14px;color:#64748b;min-height:1.2em}.ql-upload-state.ok{color:#0e7a4f;font-weight:700;animation:qlu-rise .3s ease}.ql-upload-error{color:#b42318!important}\n.ql-upload-note{font-size:12.5px;color:#64748b;line-height:1.6;margin:0}\n.ql-upload-h{margin:4px 0 0;font-size:18px}.ql-upload-list{display:grid;gap:10px}\n.ql-upload-item{display:flex;justify-content:space-between;gap:12px;align-items:center;border:1px solid #e2e8f0;border-radius:14px;padding:14px 18px;animation:qlu-rise .35s ease backwards;transition:border-color .15s,transform .15s}.ql-upload-item:hover{border-color:#3a3fd8;transform:translateY(-1px)}\n.ql-upload-item a{color:#fff;background:#3a3fd8;padding:8px 16px;border-radius:999px;font-weight:700;font-size:13px;text-decoration:none}\n.ql-upload-quota.free{background:linear-gradient(135deg,#ecedff,#fff3d6);border-color:#c9ccf5}.ql-upload-quota-actions{display:flex;flex-wrap:wrap;gap:12px;align-items:center;margin-top:14px}.ql-upload-claim{border:0;border-radius:11px;padding:11px 20px;background:#3a3fd8;color:#fff;font:800 14px inherit;cursor:pointer;animation:qlu-pulse 2s ease-in-out infinite}.ql-upload-quota-actions .ql-upload-upgrade{margin-top:0;background:transparent;color:#3a3fd8;border:1px solid #c9ccf5}@keyframes qlu-pulse{0%,100%{box-shadow:0 0 0 0 rgba(58,63,216,.45)}50%{box-shadow:0 0 0 9px rgba(58,63,216,0)}}.ql-upload-tag{display:inline-block;margin-left:6px;padding:2px 7px;border-radius:6px;background:#fff1cc;color:#9a5b00;font-size:10px;font-weight:800;letter-spacing:.08em;vertical-align:middle}@keyframes qlu-fade{from{opacity:0}to{opacity:1}}@keyframes qlu-rise{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:none}}@keyframes qlu-grow{from{transform:scaleX(0)}to{transform:scaleX(1)}}@keyframes qlu-bob{0%,100%{transform:translateY(0)}50%{transform:translateY(-4px)}}@keyframes qlu-nudge{0%,100%{transform:translateX(0)}50%{transform:translateX(4px)}}@keyframes qlu-sheen{from{transform:translateX(-100%)}to{transform:translateX(100%)}}\n@media(prefers-reduced-motion:reduce){.ql-upload-overlay,.ql-upload-modal,.ql-upload-steps>div,.ql-upload-icon,.ql-upload-steps b,.ql-upload-drop .big,.ql-upload-meter i,.ql-upload-item,.ql-upload-pick.busy::after{animation:none!important}}\n@media(max-width:640px){.ql-mp-title-actions{width:100%}.ql-mp-title-actions>*{flex:1;text-align:center;justify-content:center}.ql-upload-hero,.ql-upload-body{padding-left:18px;padding-right:18px}.ql-upload-steps{gap:4px}.ql-upload-steps span{font-size:11px}}";
      document.head.appendChild(style);
    }
    var open = host.querySelector(".ql-upload-open");
    if (!open || open.dataset.bound) return;
    open.dataset.bound = "1";
    open.addEventListener("click", function () {
      var overlay = document.createElement("div");
      overlay.className = "ql-upload-overlay";
      overlay.innerHTML = '<section class="ql-upload-modal" role="dialog" aria-modal="true" aria-labelledby="ql-upload-title"><div class="ql-upload-hero" style="padding:20px 24px"><button class="ql-upload-close" type="button" aria-label="Close">×</button><h2 id="ql-upload-title">Your uploaded papers</h2></div><div class="ql-upload-body"><div class="ql-upload-quota" aria-live="polite">Checking your uploads…</div><div style="display:flex;align-items:center;justify-content:space-between;gap:12px"><h3 class="ql-upload-h">Your papers</h3><button type="button" class="ql-upload-new ql-upload-claim" style="animation:none">＋ Upload paper</button></div><form class="ql-upload-form" style="display:none;gap:12px"><label class="ql-upload-drop"><strong>Choose a PDF or JSON</strong><small>Up to 10 MB · PDF up to 30 pages</small><input class="ql-upload-file" type="file" name="paper" accept=".pdf,.json,application/pdf,application/json" required></label><div class="ql-upload-chip"></div><button class="ql-upload-pick" type="submit" disabled>Create my test</button><p class="ql-upload-state" aria-live="polite"></p><button type="button" class="ql-upload-hide">Close upload</button></form><div class="ql-upload-list"><p class="ql-upload-state">Loading…</p></div><details class="ql-upload-rules"><summary style="cursor:pointer;padding:10px 0;font-weight:700">Upload rules · See all</summary><div class="ql-upload-note" style="padding:8px 0"><p>Free: 1 successful upload every 7 days. Pro: 5 in the same rolling window. Each slot returns 7 days after use. Failed conversions do not use a slot.</p><p>PDF or JSON, up to 10 MB. PDFs support up to 30 pages of selectable text; scanned PDFs are not supported.</p><p>PDF text is sent to DeepSeek AI to structure questions. The temporary file is deleted after processing. JSON is processed without AI. Review questions because AI can make mistakes.</p><p>Your tests appear in My Papers. Our team may review uploads and add suitable papers to the public library.</p></div></details></div></section>';
      document.body.appendChild(overlay);

      var modal = overlay.querySelector(".ql-upload-modal");
      var quotaTimer, rulesTimer;
      var rules = modal.querySelector('.ql-upload-rules');
      function collapseRules() { clearTimeout(rulesTimer); rules.open = false; }
      rules.addEventListener('toggle', function () {
        clearTimeout(rulesTimer);
        rules.querySelector('summary').textContent = 'Upload rules · ' + (rules.open ? 'See less' : 'See all');
        if (rules.open) rulesTimer = setTimeout(collapseRules, 30000);
      });
      function onHidden() { if (document.hidden) collapseRules(); }
      document.addEventListener('visibilitychange', onHidden);
      window.addEventListener('pagehide', collapseRules);
      function escape(event) { if (event.key === 'Escape') close(); }
      function close() {
        clearInterval(quotaTimer); collapseRules(); overlay.remove();
        document.removeEventListener('visibilitychange', onHidden);
        document.removeEventListener('keydown', escape);
        window.removeEventListener('pagehide', collapseRules);
      }
      overlay.querySelector(".ql-upload-close").addEventListener("click", close);
      overlay.addEventListener("click", function (event) { if (event.target === overlay) close(); });
      document.addEventListener("keydown", escape);
      var list = modal.querySelector(".ql-upload-list");
      var state = modal.querySelector(".ql-upload-form .ql-upload-state");
      var quotaBox = modal.querySelector(".ql-upload-quota");
      var drop = modal.querySelector(".ql-upload-drop");
      var fileInput = modal.querySelector("input[type=file]");
      var chip = modal.querySelector(".ql-upload-chip");
      var button = modal.querySelector(".ql-upload-pick");
      var allowed = false, uploading = false;
      var uploadForm = modal.querySelector('.ql-upload-form');
      var newUpload = modal.querySelector('.ql-upload-new');
      newUpload.addEventListener('click', function () {
        collapseRules(); uploadForm.style.display = 'grid'; fileInput.focus();
      });
      modal.querySelector('.ql-upload-hide').addEventListener('click', function () { uploadForm.style.display = 'none'; });
      function authHeaders() { return { Accept: "application/json", Authorization: "Bearer " + runtime.token(), "X-QuizLab-Client": "web" }; }
      function inTime(iso) {
        var seconds = Math.max(0, Math.ceil((new Date(iso).getTime() - Date.now()) / 1000));
        if (!seconds) return "now — refresh to check availability";
        return "in " + Math.floor(seconds / 86400) + "d " + Math.floor(seconds / 3600) % 24 + "h " + Math.floor(seconds / 60) % 60 + "m " + seconds % 60 + "s";
      }
      function renderQuota(q) {
        clearInterval(quotaTimer);
        quotaBox.replaceChildren();
        quotaBox.className = "ql-upload-quota";
        if (!q) { allowed = false; newUpload.disabled = true; quotaBox.textContent = "Upload allowance unavailable. Reopen to retry."; syncButton(); return; }
        quotaBox.hidden = false;
        var top = document.createElement("div"); top.className = "ql-upload-quota-top";
        var head = document.createElement("strong"), sub = document.createElement("small");
        allowed = q.remaining > 0;
        head.style.fontSize = '13px';
        head.textContent = allowed ? (q.is_pro ? q.remaining + ' of ' + q.limit + ' uploads available' : q.remaining + ' free upload available') : 'Upload allowance used';
        quotaBox.style.padding = '8px 12px';
        if (!allowed && q.resets_at) {
          var refreshed = false;
          function tick() {
            sub.textContent = 'Next ' + (q.is_pro ? 'upload ' : 'free upload ') + inTime(q.resets_at);
            if (new Date(q.resets_at).getTime() <= Date.now() && !refreshed) { refreshed = true; clearInterval(quotaTimer); refreshUploads(); }
          }
          tick(); if (!refreshed) quotaTimer = setInterval(tick, 1000);
        }
        top.append(head, sub); quotaBox.appendChild(top);
        if (!q.is_pro) {
          var up = document.createElement('button'); up.type = 'button'; up.className = 'ql-upload-upgrade';
          up.style.cssText = 'border:0;background:transparent;color:#3a3fd8;font-weight:700;cursor:pointer;padding:6px 0';
          up.textContent = allowed ? 'Get ' + (q.pro_limit || 5) + ' · Pro' : 'Get Pro to upload';
          up.addEventListener('click', function () { close(); if (typeof window.openProPaywall === 'function') window.openProPaywall(); else location.assign('/pro'); });
          quotaBox.appendChild(up);
        }
        newUpload.disabled = !allowed;
        drop.classList.toggle("disabled", !allowed);
        syncButton();
      }
      function syncButton() { button.disabled = uploading || !allowed || !fileInput.files.length; }
      function setFile(file) {
        chip.classList.toggle("on", !!file);
        chip.textContent = file ? "📎 " + file.name + " · " + Math.max(1, Math.round(file.size / 1024)) + " KB" : "";
        syncButton();
      }
      fileInput.addEventListener("change", function () { setFile(fileInput.files[0]); });
      ["dragenter", "dragover"].forEach(function (name) { drop.addEventListener(name, function (e) { e.preventDefault(); drop.classList.add("over"); }); });
      ["dragleave", "drop"].forEach(function (name) { drop.addEventListener(name, function (e) { e.preventDefault(); drop.classList.remove("over"); }); });
      drop.addEventListener("drop", function (e) {
        var f = e.dataTransfer && e.dataTransfer.files[0];
        if (!f || !allowed) return;
        try { var dt = new DataTransfer(); dt.items.add(f); fileInput.files = dt.files; setFile(f); } catch (_) { /* browser without DataTransfer: use the picker */ }
      });
      function refreshUploads() {
        fetch(runtime.apiBase + "/student/uploaded-papers", { headers: authHeaders() }).then(async function (response) {
          var data = null;
          try { data = await response.json(); } catch (_) {}
          if (!response.ok) {
            var msg = (data && (data.message || data.error)) || ("Could not load uploads (" + response.status + ")");
            throw new Error(msg);
          }
          return data;
        }).then(function (data) {
          renderQuota(data.quota);
          list.replaceChildren();
          var papers = Array.isArray(data.papers) ? data.papers.slice().sort(function (a, b) { return Number(b.id) - Number(a.id); }) : [];
          if (!papers.length) { var empty = document.createElement("p"); empty.className = "ql-upload-state"; empty.textContent = "Your papers will appear here. Upload a paper and turn it into a practice test."; list.appendChild(empty);
            var first = document.createElement('button'); first.type = 'button'; first.className = 'ql-upload-claim'; first.style.animation = 'none'; first.textContent = 'Upload your first paper'; first.disabled = !allowed; first.onclick = function () { newUpload.click(); }; list.appendChild(first); return; }
          papers.forEach(function (paper, index) {
            var row = document.createElement("div"); row.className = "ql-upload-item"; row.style.animationDelay = (index * 50) + "ms";
            var info = document.createElement("div");
            var title = document.createElement("strong"); title.textContent = paper.title || "My paper";
            var count = document.createElement("div"); count.className = "ql-upload-state"; count.textContent = (paper.question_count || 0) + " questions · Your private test";
            info.append(title, count);
            var link = document.createElement("a"); link.href = "/paper/" + encodeURIComponent(paper.id); link.textContent = "Start";
            row.append(info, link); list.appendChild(row);
          });
        }).catch(function (error) {
          list.replaceChildren();
          var message = document.createElement("p");
          message.className = "ql-upload-state ql-upload-error";
          message.textContent = error.message;
          list.appendChild(message);
          quotaBox.textContent = "Uploads unavailable: " + error.message; allowed = false; newUpload.disabled = true; syncButton();
        });
      }
      refreshUploads();
      var steps = ["Reading your paper…", "Finding the questions…", "Checking answers and options…", "Building your test…"];
      modal.querySelector(".ql-upload-form").addEventListener("submit", function (event) {
        event.preventDefault();
        var file = fileInput.files[0];
        if (!file || !allowed || uploading) return;
        uploading = true;
        var n = 0, ticker;
        button.disabled = true; button.classList.add("busy"); button.textContent = steps[0];
        state.className = "ql-upload-state"; state.textContent = "This can take a minute for a PDF.";
        ticker = setInterval(function () { n = Math.min(n + 1, steps.length - 1); button.textContent = steps[n]; }, 6000);
        var form = new FormData(); form.append("paper", file);
        fetch(runtime.apiBase + "/student/uploaded-papers", { method: "POST", headers: authHeaders(), body: form }).then(function (response) {
          return response.json().catch(function () { return {}; }).then(function (data) { if (!response.ok) { if (data.quota) renderQuota(data.quota); throw new Error(data.error || data.message || "Could not create a test from this file."); } return data; });
        }).then(function (data) {
          state.className = "ql-upload-state ok";
          list.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
          state.textContent = "✅ " + (data.title || "Your paper") + " is ready with " + (data.question_count || 0) + " questions.";
          fileInput.value = ""; setFile(null);
          if (data.quota) renderQuota(data.quota);
          refreshUploads();
          host.dataset.qlLoaded = "";
          fillMyPapers();
        }).catch(function (error) { state.className = "ql-upload-state ql-upload-error"; state.textContent = error.message; }).finally(function () { clearInterval(ticker); uploading = false; button.classList.remove("busy"); button.textContent = "Create my test"; syncButton(); });
      });
    });
  }

  /* ---------------------------------------------------------------
   * Try your practice: Spin wheel & custom practice paper builder.
   * Lets any student customize course, week range, and paper types,
   * spins the wheel, and builds a 10-question unified paper.
   * ------------------------------------------------------------- */
  function syncTryPracticeNav() {
    var isTry = /^\/(try-practice|spin-practice)(\/|$)/i.test(window.location.pathname);
    document.querySelectorAll("#root aside nav").forEach(function (nav) {
      if (!nav.querySelector('a[href="/dashboard"]')) return;
      var existing = nav.querySelector('a[href="/try-practice"]');
      if (!existing) {
        var anchor = nav.querySelector('a[href="/my-papers"]') || nav.querySelector('a[href="/practice"]');
        if (!anchor) return;
        existing = document.createElement("a");
        existing.href = "/try-practice";
        existing.className = "mb-0.5 flex items-center gap-2.5 rounded-lg px-3 py-[7px] text-[13px] font-medium transition-colors " +
          (isTry ? "bg-brand text-white shadow-sm" : "text-slate-700 hover:bg-slate-100");
        existing.innerHTML = '<span class="flex h-5 w-5 items-center justify-center font-bold text-sm">🎯</span><span>Try your practice</span>';
        existing.addEventListener("click", function (e) {
          if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
          e.preventDefault();
          if (window.location.pathname !== "/try-practice") {
            window.history.pushState(null, "", "/try-practice");
            schedule();
          }
        });
        if (anchor.nextSibling) {
          anchor.parentNode.insertBefore(existing, anchor.nextSibling);
        } else {
          anchor.parentNode.appendChild(existing);
        }
      } else {
        existing.className = "mb-0.5 flex items-center gap-2.5 rounded-lg px-3 py-[7px] text-[13px] font-medium transition-colors " +
          (isTry ? "bg-brand text-white shadow-sm" : "text-slate-700 hover:bg-slate-100");
      }
    });
  }

  function fillTryPractice() {
    var onTry = /^\/(try-practice|spin-practice)(\/|$)/i.test(window.location.pathname);
    var host = document.getElementById("ql-try-practice");
    if (!host && onTry) {
      var main = document.querySelector("#root main");
      if (main && !main.querySelector(".ql-spin-container")) {
        host = document.createElement("div");
        host.id = "ql-try-practice";
        main.replaceChildren(host);
      }
    }
    if (!host || host.dataset.qlLoaded) return;
    var runtime = window.QLStorefront;
    if (!runtime || !runtime.token()) return;
    host.dataset.qlLoaded = "1";
    document.title = "Try your practice · Quiz LAB";
    host.innerHTML = [
      '<section class="ql-spin-container">',
        '<header class="ql-spin-head"><h1>Try your practice.</h1><p>Get random 10 question</p></header>',
        '<div class="ql-spin-grid">',
          '<div class="ql-spin-wheel-card">',
            '<div class="ql-wheel-stage" aria-hidden="true"><canvas id="ql-spin-canvas" width="680" height="680"></canvas>',
              '<span class="ql-wheel-pointer"></span><span class="ql-wheel-hub"><img src="/android-chrome-192x192.png" alt=""></span>',
            '</div>',
            '<p class="ql-spin-outcome" id="ql-spin-outcome" role="status" aria-live="polite"></p>',
          '</div>',
          '<form class="ql-spin-custom-card" id="ql-spin-form">',
            '<fieldset id="ql-spin-settings">',
              '<div class="ql-spin-field"><label for="ql-spin-course">Course</label>',
                '<select id="ql-spin-course" class="ql-spin-select" required disabled><option value="">Loading courses…</option></select>',
                '<button class="ql-spin-retry" type="button" id="ql-spin-retry" hidden>Retry loading courses</button>',
              '</div>',
              '<div class="ql-spin-field"><label>Week range <output id="ql-week-range-text">01 — 12</output></label>',
                '<div class="ql-spin-dual-range" id="ql-spin-range-track">',
                  '<input type="range" id="ql-spin-week-min" min="1" max="12" value="1" step="1" aria-label="Start week">',
                  '<input type="range" id="ql-spin-week-max" min="1" max="12" value="12" step="1" aria-label="End week">',
                '</div><div class="ql-spin-slider-labels"><span>Week 1</span><span>Week 12</span></div>',
              '</div>',
              '<div class="ql-spin-field"><label for="ql-spin-type-toggle">Paper types</label>',
                '<details class="ql-spin-types"><summary id="ql-spin-type-toggle"><span id="ql-spin-type-summary">All types</span><span aria-hidden="true">⌄</span></summary>',
                  '<div class="ql-spin-types-list">',
                    '<label><span>All types</span><input type="checkbox" value="all" checked></label>',
                    '<label><span>PA</span><input type="checkbox" value="pa"></label>',
                    '<label><span>GA</span><input type="checkbox" value="ga"></label>',
                    '<label><span>Quiz 1</span><input type="checkbox" value="quiz1"></label>',
                    '<label><span>Quiz 2</span><input type="checkbox" value="quiz2"></label>',
                    '<label><span>End term</span><input type="checkbox" value="endterm"></label>',
                    '<label><span>Mock</span><input type="checkbox" value="mock_test"></label>',
                  '</div>',
                '</details>',
              '</div>',
              '<div class="ql-spin-field"><label for="ql-spin-name">Paper name <span class="ql-spin-optional">Optional</span></label>',
                '<input type="text" id="ql-spin-name" class="ql-spin-input" placeholder="My practice paper" maxlength="150">',
              '</div>',
            '</fieldset>',
            '<button type="submit" class="ql-spin-main-btn" id="ql-spin-main-btn" disabled><span aria-hidden="true">↻</span> Spin the wheel</button>',
          '</form>',
        '</div>',
        '<section class="ql-spin-result" id="ql-spin-result" hidden tabindex="-1" aria-labelledby="ql-spin-result-title">',
          '<div><span class="ql-spin-result-check" aria-hidden="true">✓</span><h2 id="ql-spin-result-title"></h2><p id="ql-spin-result-meta"></p></div>',
          '<div class="ql-spin-result-actions"><a id="ql-spin-start" class="ql-spin-main-btn">Open paper <span aria-hidden="true">→</span></a><a href="/my-papers">My Papers</a></div>',
        '</section>',
      '</section>'
    ].join("");
    var canvas = host.querySelector("#ql-spin-canvas"), ctx = canvas.getContext("2d");
    var form = host.querySelector("#ql-spin-form"), settings = host.querySelector("#ql-spin-settings");
    var mainBtn = host.querySelector("#ql-spin-main-btn"), outcome = host.querySelector("#ql-spin-outcome");
    var courseSelect = host.querySelector("#ql-spin-course"), retry = host.querySelector("#ql-spin-retry");
    var weekMinInput = host.querySelector("#ql-spin-week-min"), weekMaxInput = host.querySelector("#ql-spin-week-max");
    var types = Array.from(host.querySelectorAll(".ql-spin-types-list input"));
    var result = host.querySelector("#ql-spin-result"), currentAngle = 0, isSpinning = false;
    var palette = ["#064e3b", "#0d7054", "#116149", "#158467", "#0c5a45", "#167454", "#14543d", "#0c8060", "#0c634f", "#1b755c"];
    function drawWheel(angle) {
      if (!ctx) return;
      ctx.setTransform(2, 0, 0, 2, 0, 0);
      ctx.clearRect(0, 0, 340, 340);
      var cx = 170, cy = 170, radius = 143;
      var rim = ctx.createLinearGradient(35, 35, 300, 300);
      rim.addColorStop(0, "#e0f4e9"); rim.addColorStop(.4, "#579d84"); rim.addColorStop(.65, "#ecfdf5"); rim.addColorStop(1, "#275e4a");
      ctx.beginPath(); ctx.arc(cx, cy, 159, 0, Math.PI * 2); ctx.fillStyle = rim; ctx.fill();
      ctx.beginPath(); ctx.arc(cx, cy, 154, 0, Math.PI * 2); ctx.fillStyle = "#082f27"; ctx.fill();
      for (var tick = 0; tick < 72; tick++) {
        var a = tick * Math.PI / 36, major = tick % 6 === 0;
        ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * 152, cy + Math.sin(a) * 152);
        ctx.lineTo(cx + Math.cos(a) * (major ? 145 : 149), cy + Math.sin(a) * (major ? 145 : 149));
        ctx.strokeStyle = major ? "#d5eedf" : "#6a9e87"; ctx.lineWidth = major ? 1.5 : .7; ctx.stroke();
      }
      ctx.save(); ctx.translate(cx, cy); ctx.rotate(angle * Math.PI / 180);
      for (var i = 0; i < 10; i++) {
        var start = i * Math.PI / 5, gradient = ctx.createRadialGradient(0, 0, 20, 0, 0, radius);
        gradient.addColorStop(0, "#062c23"); gradient.addColorStop(1, palette[i]);
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.arc(0, 0, radius, start, start + Math.PI / 5); ctx.closePath(); ctx.fillStyle = gradient; ctx.fill();
        ctx.strokeStyle = "rgba(156,227,187,.28)"; ctx.lineWidth = .8; ctx.stroke();
        var dot = start + Math.PI / 10;
        ctx.beginPath(); ctx.arc(Math.cos(dot) * 128, Math.sin(dot) * 128, 2.5, 0, Math.PI * 2); ctx.fillStyle = "#b9dec7"; ctx.fill();
      }
      ctx.restore();
      var light = ctx.createLinearGradient(65, 65, 270, 270);
      light.addColorStop(0, "rgba(255,255,255,.16)"); light.addColorStop(.5, "rgba(255,255,255,0)"); light.addColorStop(1, "rgba(0,0,0,.12)");
      ctx.beginPath(); ctx.arc(cx, cy, radius, 0, Math.PI * 2); ctx.fillStyle = light; ctx.fill();
      ctx.beginPath(); ctx.arc(cx, cy, 58, 0, Math.PI * 2); ctx.strokeStyle = "rgba(154,213,182,.45)"; ctx.lineWidth = 1; ctx.stroke();
    }
    drawWheel(0);
    function loadCourses() {
      retry.hidden = true; courseSelect.disabled = true; mainBtn.disabled = true;
      courseSelect.innerHTML = '<option value="">Loading courses…</option>';
      fetch(runtime.apiBase + "/courses", {headers: {Accept: "application/json", Authorization: "Bearer " + runtime.token()}})
        .then(function (res) { if (!res.ok) throw Error("Could not load courses."); return res.json(); })
        .then(function (courses) {
          if (!host.isConnected) return;
          var list = Array.isArray(courses) ? courses : [];
          courseSelect.innerHTML = '<option value="">Choose a course</option>' + list.map(function (course) {
            return '<option value="' + Number(course.id) + '">' + escapeHtml(course.name) + '</option>';
          }).join("");
          courseSelect.disabled = !list.length; mainBtn.disabled = !list.length;
          if (!list.length) outcome.textContent = "No courses are available yet.";
        }).catch(function () { outcome.textContent = "Could not load courses. Please try again."; retry.hidden = false; });
    }
    retry.addEventListener("click", loadCourses); loadCourses();
    function updateWeekRange() {
      var min = Number(weekMinInput.value), max = Number(weekMaxInput.value);
      if (min > max) {
        if (this === weekMinInput) weekMaxInput.value = max = min;
        else weekMinInput.value = min = max;
      }
      host.querySelector("#ql-week-range-text").textContent = String(min).padStart(2, "0") + " — " + String(max).padStart(2, "0");
      var track = host.querySelector("#ql-spin-range-track");
      track.style.setProperty("--range-start", ((min - 1) / 11 * 100) + "%");
      track.style.setProperty("--range-end", ((max - 1) / 11 * 100) + "%");
      weekMinInput.style.zIndex = min === 12 ? 3 : 1; weekMaxInput.style.zIndex = 2;
      weekMinInput.setAttribute("aria-valuetext", "Week " + min); weekMaxInput.setAttribute("aria-valuetext", "Week " + max);
    }
    weekMinInput.addEventListener("input", updateWeekRange); weekMaxInput.addEventListener("input", updateWeekRange); updateWeekRange();
    types.forEach(function (checkbox) {
      checkbox.addEventListener("change", function () {
        if (checkbox.value === "all") { types.forEach(function (item) { item.checked = item.value === "all"; }); }
        else {
          types[0].checked = false;
          if (!types.some(function (item) { return item.checked; })) types[0].checked = true;
        }
        host.querySelector("#ql-spin-type-summary").textContent = types.filter(function (item) { return item.checked; })
          .map(function (item) { return item.closest("label").querySelector("span").textContent; }).join(", ");
      });
    });
    document.addEventListener("click", function closeTypes(event) {
      if (!host.isConnected) { document.removeEventListener("click", closeTypes); return; }
      var details = host.querySelector(".ql-spin-types");
      if (details && !details.contains(event.target)) details.open = false;
    });
    function animateSpin() {
      if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return Promise.resolve();
      return new Promise(function (resolve) {
        var start = performance.now(), initial = currentAngle;
        function frame(now) {
          if (!host.isConnected) { resolve(); return; }
          var progress = Math.min(1, (now - start) / 2800);
          // Ease in, then settle softly. The wheel does not select a paper type.
          var eased = progress < .5 ? 4 * progress * progress * progress : 1 - Math.pow(-2 * progress + 2, 3) / 2;
          currentAngle = initial + 2034 * eased; drawWheel(currentAngle);
          if (progress < 1) requestAnimationFrame(frame); else { currentAngle %= 360; resolve(); }
        }
        requestAnimationFrame(frame);
      });
    }
    async function spinWheel(event) {
      event.preventDefault();
      if (isSpinning) return;
      if (!courseSelect.value) { courseSelect.reportValidity(); return; }
      var payload = {course_id: Number(courseSelect.value), week_min: Number(weekMinInput.value), week_max: Number(weekMaxInput.value),
        paper_types: types.filter(function (item) { return item.checked; }).map(function (item) { return item.value; }), title: host.querySelector("#ql-spin-name").value.trim()};
      isSpinning = true; settings.disabled = true; mainBtn.disabled = true; result.hidden = true;
      host.querySelector(".ql-spin-types").open = false;
      mainBtn.textContent = "Creating paper…"; outcome.className = "ql-spin-outcome"; outcome.textContent = "Creating your practice paper…";
      var controller = new AbortController(), timeout = setTimeout(function () { controller.abort(); }, 25000);
      try {
        var request = fetch(runtime.apiBase + "/student/spin-practice", {method: "POST", signal: controller.signal,
          headers: {Accept: "application/json", "Content-Type": "application/json", Authorization: "Bearer " + runtime.token()}, body: JSON.stringify(payload)})
          .then(async function (res) { var paper = await res.json(); if (!res.ok) throw Error(paper.error || paper.message || "Could not create your paper.");
            if (!(Number(paper.id) > 0 && Number(paper.question_count) > 0)) throw Error("The server returned an incomplete paper. Check My Papers before trying again.");
            return paper;
          });
        var responses = await Promise.allSettled([request, animateSpin()]);
        if (!host.isConnected) return;
        if (responses[0].status === "rejected") throw responses[0].reason;
        var paper = responses[0].value;
        host.querySelector("#ql-spin-result-title").textContent = paper.title || "Practice paper";
        host.querySelector("#ql-spin-result-meta").textContent = paper.question_count + " questions · Choose your time when you open it";
        host.querySelector("#ql-spin-start").href = "/paper/" + encodeURIComponent(paper.id);
        result.hidden = false; outcome.textContent = "Your paper is ready."; result.focus({preventScroll: true}); result.scrollIntoView({behavior: "smooth", block: "nearest"});
      } catch (error) {
        if (!host.isConnected) return;
        outcome.className = "ql-spin-outcome error";
        outcome.textContent = error.name === "AbortError" ? "The request timed out. Check My Papers before trying again." : (error.message || "Could not create your paper. Please try again.");
      } finally {
        clearTimeout(timeout); isSpinning = false;
        if (host.isConnected) { settings.disabled = false; mainBtn.disabled = false; mainBtn.innerHTML = '<span aria-hidden="true">↻</span> Spin the wheel'; }
      }
    }
    form.addEventListener("submit", spinWheel);
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
              '<span style="font-size:10px;color:#94a3b8;font-weight:500;">by GenZ <span style="color:#3a3fd8;font-style:italic;font-weight:700;">IITian</span></span>' +
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
            '<span style="font-size:10.5px;font-weight:500;' + (isWhite ? 'color:#94a3b8;' : 'color:#64748b;') + '">by GenZ <span style="color:#3a3fd8;font-style:italic;font-weight:700;">IITian</span></span>' +
          '</div>';
      }
    }
  }

  /* ---------------------------------------------------------------
   * Papers open in the self-paced paper room (/paper/{id}) and the Exam
   * tab opens the online exam platform. Both are separate pages, so
   * these links must load a page instead of routing inside the app.
   * ------------------------------------------------------------- */
  /* ---------------------------------------------------------------
   * Exam tab: students see it only when a manager has enrolled their
   * email in at least one online exam. Managers always see it.
   * ------------------------------------------------------------- */
  var examAccess = null, examAccessAt = 0;
  function updateExamNav() {
    var role = storedRole();
    var root = document.documentElement;
    if (role === "manager") { root.setAttribute("data-ql-exam", "show"); return; }
    var runtime = window.QLStorefront;
    if (!role || !runtime || !runtime.token()) { root.setAttribute("data-ql-exam", "hide"); return; }
    if (examAccess === null || (examAccess !== "loading" && Date.now() - examAccessAt > 300000)) {
      var was = examAccess; examAccess = "loading";
      fetch(runtime.apiBase + "/exam-platform/exams", { headers: { Accept: "application/json", Authorization: "Bearer " + runtime.token() } })
        .then(function (r) { return r.ok ? r.json() : { exams: [] }; })
        .then(function (d) { examAccess = Array.isArray(d.exams) && d.exams.length > 0; })
        .catch(function () { examAccess = was === "loading" ? false : !!was; })
        .then(function () { examAccessAt = Date.now(); updateExamNav(); });
    }
    root.setAttribute("data-ql-exam", examAccess === true ? "show" : "hide");
  }
  (function () {
    var st = document.createElement("style");
    st.textContent = 'html:not([data-ql-exam="show"]) #root a[href="/exams"],html:not([data-ql-exam="show"]) #root a[href^="/exams/"]{display:none!important}';
    (document.head || document.documentElement).appendChild(st);
  })();

  /* ---------------------------------------------------------------
   * Announcement slider at the top of the dashboard. Managers add,
   * schedule and remove announcements at /manager/announcements.
   * ------------------------------------------------------------- */
  var annData = null, annAt = 0, annTimer = null;
  function loadAnnouncements() {
    var runtime = window.QLStorefront;
    if (!runtime || annData === "loading" || (annAt && Date.now() - annAt < 300000)) return;
    annData = "loading";
    fetch(runtime.apiBase + "/announcements", { headers: { Accept: "application/json" } })
      .then(function (r) { return r.ok ? r.json() : { announcements: [] }; })
      .then(function (d) { annData = Array.isArray(d.announcements) ? d.announcements : []; })
      .catch(function () { annData = []; })
      .then(function () { annAt = Date.now(); var old = document.getElementById("ql-ann"); if (old) old.remove(); schedule(); });
  }
  function renderAnnouncements() {
    var existing = document.getElementById("ql-ann");
    if (!/^\/dashboard\/?$/.test(location.pathname)) { if (existing) existing.remove(); return; }
    loadAnnouncements();
    if (!Array.isArray(annData) || !annData.length) { if (existing) existing.remove(); return; }
    var main = document.querySelector("#root main");
    if (!main || existing) return;
    var host = main.firstElementChild && main.firstElementChild.children.length ? main.firstElementChild : main;
    var box = document.createElement("section");
    box.id = "ql-ann"; box.setAttribute("aria-label", "Announcements"); box.setAttribute("aria-roledescription", "carousel");
    var track = document.createElement("div"); track.className = "ql-ann-track";
    annData.forEach(function (a, i) {
      var slide = document.createElement("div");
      slide.className = "ql-ann-slide tone-" + (/^(brand|green|amber|dark)$/.test(a.tone) ? a.tone : "brand");
      slide.setAttribute("role", "group"); slide.setAttribute("aria-label", (i + 1) + " of " + annData.length);
      var copy = document.createElement("div"); copy.className = "ql-ann-copy";
      var tag = document.createElement("span"); tag.className = "ql-ann-tag"; tag.textContent = "📢 Announcement";
      var h = document.createElement("strong"); h.textContent = a.title || "";
      copy.append(tag, h);
      if (a.body) { var p = document.createElement("p"); p.textContent = a.body; copy.appendChild(p); }
      slide.appendChild(copy);
      if (a.link_url && /^(https:\/\/|\/)/.test(a.link_url)) {
        var link = document.createElement("a"); link.className = "ql-ann-cta"; link.href = a.link_url;
        if (/^https:/.test(a.link_url) && a.link_url.indexOf(location.origin) !== 0) { link.target = "_blank"; link.rel = "noopener"; }
        link.textContent = (a.link_label || "Open") + " →"; slide.appendChild(link);
      }
      track.appendChild(slide);
    });
    box.appendChild(track);
    var idx = 0, n = annData.length;
    function go(i) {
      idx = (i + n) % n; track.style.transform = "translateX(" + (-100 * idx) + "%)";
      Array.prototype.forEach.call(box.querySelectorAll(".ql-ann-dot"), function (d, k) { d.setAttribute("aria-current", k === idx ? "true" : "false"); });
    }
    function auto() { clearInterval(annTimer); if (n > 1) annTimer = setInterval(function () { if (!document.hidden && box.isConnected && !box.matches(":hover")) go(idx + 1); }, 6000); }
    if (n > 1) {
      var nav = document.createElement("div"); nav.className = "ql-ann-nav";
      var prev = document.createElement("button"); prev.type = "button"; prev.className = "ql-ann-arrow"; prev.setAttribute("aria-label", "Previous announcement"); prev.textContent = "‹";
      var next = document.createElement("button"); next.type = "button"; next.className = "ql-ann-arrow"; next.setAttribute("aria-label", "Next announcement"); next.textContent = "›";
      prev.onclick = function () { go(idx - 1); auto(); }; next.onclick = function () { go(idx + 1); auto(); };
      var dots = document.createElement("div"); dots.className = "ql-ann-dots";
      for (var k = 0; k < n; k++) (function (k) { var d = document.createElement("button"); d.type = "button"; d.className = "ql-ann-dot"; d.setAttribute("aria-label", "Announcement " + (k + 1)); d.onclick = function () { go(k); auto(); }; dots.appendChild(d); })(k);
      nav.append(prev, dots, next); box.appendChild(nav);
      var sx = null;
      box.addEventListener("touchstart", function (e) { sx = e.touches[0].clientX; }, { passive: true });
      box.addEventListener("touchend", function (e) { if (sx == null) return; var dx = e.changedTouches[0].clientX - sx; if (Math.abs(dx) > 40) { go(idx + (dx < 0 ? 1 : -1)); auto(); } sx = null; });
    }
    host.insertBefore(box, host.firstChild);
    go(0); auto();
  }

  /* ---------------------------------------------------------------
   * Header Bell & Daily Challenge navigation
   * Clicking bell shows announcements & notifications.
   * Clicking Daily Challenge takes user to /practice.
   * ------------------------------------------------------------- */
  var bellStyleId = "ql-bell-style";
  function ensureBellStyles() {
    if (document.getElementById(bellStyleId)) return;
    var s = document.createElement("style");
    s.id = bellStyleId;
    s.textContent =
      ".ql-bell-popover{position:fixed;z-index:99999;width:min(400px,calc(100vw - 24px));max-height:min(540px,calc(100vh - 80px));background:var(--surface,#fff);border:1px solid var(--line,#e2e8f0);border-radius:18px;box-shadow:0 20px 45px -10px rgba(15,23,42,.22),0 0 0 1px rgba(15,23,42,.05);display:flex;flex-direction:column;overflow:hidden;animation:qlu-rise .25s ease;color:var(--ink,#0f172a);font-family:system-ui,-apple-system,sans-serif}\n" +
      ":root[data-theme=dark] .ql-bell-popover{background:#151a25;border-color:#2e3b4c;color:#f8fafc;box-shadow:0 24px 50px -10px rgba(0,0,0,.6),0 0 0 1px rgba(255,255,255,.08)}\n" +
      ".ql-bell-head{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px 18px;border-bottom:1px solid var(--line,#e2e8f0);background:rgba(248,250,252,.8);backdrop-filter:blur(4px)}\n" +
      ":root[data-theme=dark] .ql-bell-head{background:rgba(21,26,37,.8);border-color:#2e3b4c}\n" +
      ".ql-bell-head strong{font-size:14.5px;font-weight:750;display:flex;align-items:center;gap:8px}\n" +
      ".ql-bell-badge{font-size:11px;font-weight:750;padding:2px 8px;border-radius:999px;background:#e0e7ff;color:#3730a3}\n" +
      ":root[data-theme=dark] .ql-bell-badge{background:#282b51;color:#a5b4fc}\n" +
      ".ql-bell-close{border:0;background:transparent;color:#64748b;font-size:22px;line-height:1;cursor:pointer;padding:2px 6px;border-radius:8px;transition:color .15s,background .15s}\n" +
      ".ql-bell-close:hover{color:#0f172a;background:rgba(0,0,0,.06)}\n" +
      ":root[data-theme=dark] .ql-bell-close:hover{color:#fff;background:rgba(255,255,255,.1)}\n" +
      ".ql-bell-list{padding:14px;overflow-y:auto;display:grid;gap:12px}\n" +
      ".ql-bell-card{border-radius:14px;padding:14px 16px;color:#fff;background:linear-gradient(135deg,#3730a3,#4f46e5 60%,#6366f1);box-shadow:0 4px 14px rgba(79,70,229,.2);display:grid;gap:6px}\n" +
      ".ql-bell-card.tone-green{background:linear-gradient(135deg,#166534,#16a34a)!important;box-shadow:0 4px 14px rgba(22,163,74,.2)!important}\n" +
      ".ql-bell-card.tone-amber{background:linear-gradient(135deg,#b45309,#f59e0b)!important;box-shadow:0 4px 14px rgba(245,158,11,.2)!important}\n" +
      ".ql-bell-card.tone-dark{background:linear-gradient(135deg,#0f172a,#1e293b)!important;box-shadow:0 4px 14px rgba(15,23,42,.3)!important}\n" +
      ".ql-bell-card b{font-size:14px;line-height:1.35;font-weight:700}\n" +
      ".ql-bell-card p{margin:0;font-size:12.5px;line-height:1.45;opacity:.92}\n" +
      ".ql-bell-card a{display:inline-block;align-self:start;margin-top:4px;padding:5px 12px;border-radius:8px;background:#fff;color:#1e1b4b;font-size:11.5px;font-weight:700;text-decoration:none;box-shadow:0 1px 3px rgba(0,0,0,.1)}\n" +
      ".ql-bell-card a:hover{opacity:.95}\n" +
      ".ql-bell-empty{padding:32px 18px;text-align:center;color:var(--muted,#64748b)}\n" +
      ".ql-bell-empty .icon{font-size:32px;margin-bottom:8px}\n" +
      ".ql-bell-empty strong{display:block;font-size:14px;color:var(--ink,#0f172a);margin-bottom:4px}\n" +
      ":root[data-theme=dark] .ql-bell-empty strong{color:#f8fafc}\n" +
      ".ql-bell-empty p{margin:0;font-size:12.5px;line-height:1.5}\n" +
      ".ql-bell-foot{padding:10px 16px;border-top:1px solid var(--line,#e2e8f0);display:flex;align-items:center;justify-content:space-between;font-size:12px;background:rgba(248,250,252,.5)}\n" +
      ":root[data-theme=dark] .ql-bell-foot{background:rgba(21,26,37,.5);border-color:#2e3b4c}\n" +
      ".ql-bell-scrim{position:fixed;inset:0;z-index:99998;background:transparent}";
    document.head.appendChild(s);
  }

  function toggleBellNotifications(bell) {
    var existing = document.getElementById("ql-bell-popover");
    var scrim = document.getElementById("ql-bell-scrim");
    if (existing) { existing.remove(); if (scrim) scrim.remove(); return; }
    ensureBellStyles();

    try {
      localStorage.setItem("ql_bell_seen_at", String(Date.now()));
      var dot = bell && bell.querySelector("span");
      if (dot) dot.style.display = "none";
    } catch (_) {}

    scrim = document.createElement("div");
    scrim.id = "ql-bell-scrim";
    scrim.className = "ql-bell-scrim";
    document.body.appendChild(scrim);

    var popover = document.createElement("div");
    popover.id = "ql-bell-popover";
    popover.className = "ql-bell-popover";
    popover.setAttribute("role", "dialog");
    popover.setAttribute("aria-label", "Notifications and announcements");

    if (bell) {
      var r = bell.getBoundingClientRect();
      var right = Math.max(12, window.innerWidth - r.right);
      popover.style.top = (r.bottom + 8) + "px";
      popover.style.right = right + "px";
    } else {
      popover.style.top = "64px";
      popover.style.right = "16px";
    }

    function close() {
      popover.remove();
      scrim.remove();
      document.removeEventListener("keydown", onKey);
    }
    scrim.onclick = close;
    function onKey(e) { if (e.key === "Escape") close(); }
    document.addEventListener("keydown", onKey);

    function renderContent(items) {
      var count = items ? items.length : 0;
      var head = '<div class="ql-bell-head"><strong><span>🔔</span>Announcements</strong>' +
        (count ? '<span class="ql-bell-badge">' + count + ' live</span>' : '') +
        '<button type="button" class="ql-bell-close" aria-label="Close">×</button></div>';

      var body = '<div class="ql-bell-list">';
      if (!items) {
        body += '<div class="ql-bell-empty"><p>Checking announcements…</p></div>';
      } else if (!items.length) {
        body += '<div class="ql-bell-empty"><div class="icon">🎉</div><strong>All caught up!</strong><p>No active announcements or notifications right now.</p></div>';
      } else {
        body += items.map(function (a) {
          var tone = /^(brand|green|amber|dark)$/.test(a.tone) ? a.tone : "brand";
          var cta = "";
          if (a.link_url && /^(https:\/\/|\/)/.test(a.link_url)) {
            cta = '<a href="' + escapeHtml(a.link_url) + '">' + escapeHtml(a.link_label || "View") + ' →</a>';
          }
          return '<article class="ql-bell-card tone-' + tone + '">' +
            '<span style="font-size:10px;font-weight:800;letter-spacing:.06em;text-transform:uppercase;opacity:.85">📢 Announcement</span>' +
            '<b>' + escapeHtml(a.title || "") + '</b>' +
            (a.body ? '<p>' + escapeHtml(a.body) + '</p>' : '') +
            cta +
            '</article>';
        }).join("");
      }
      body += '</div>';

      var user = null;
      try { user = JSON.parse(localStorage.getItem("lab_user") || "null"); } catch (_) {}
      var isManager = user && (user.role === "manager" || user.is_admin);
      var foot = '<div class="ql-bell-foot">' +
        (isManager ? '<a href="/manager/announcements" style="color:#4f46e5;font-weight:700;text-decoration:none">Manage announcements →</a>' : '<span style="color:#64748b">Everything live for your account</span>') +
        '<button type="button" class="ql-bell-close-btn" style="border:0;background:transparent;color:#64748b;cursor:pointer;font-weight:600;font-size:12px">Close</button></div>';

      popover.innerHTML = head + body + foot;
      var cBtn = popover.querySelector(".ql-bell-close");
      if (cBtn) cBtn.onclick = close;
      var cfBtn = popover.querySelector(".ql-bell-close-btn");
      if (cfBtn) cfBtn.onclick = close;
      popover.querySelectorAll("a").forEach(function (link) {
        link.addEventListener("click", function () { close(); });
      });
    }

    renderContent(Array.isArray(annData) ? annData : null);
    document.body.appendChild(popover);

    var runtime = window.QLStorefront;
    var apiBase = (runtime && runtime.apiBase) || "https://labapi.genziitian.in/public/api";
    fetch(apiBase + "/announcements", { headers: { Accept: "application/json" } })
      .then(function (r) { return r.ok ? r.json() : { announcements: [] }; })
      .then(function (d) {
        annData = Array.isArray(d.announcements) ? d.announcements : [];
        if (popover.isConnected) renderContent(annData);
      })
      .catch(function () {
        if (popover.isConnected && !Array.isArray(annData)) renderContent([]);
      });
  }

  function syncBellNotifications() {
    loadAnnouncements();
    var bell = document.querySelector(".ql-bell-btn, [data-ql-bell]");
    if (!bell) {
      var btn = Array.prototype.find.call(document.querySelectorAll("header button, nav button"), function (b) {
        return b.querySelector && b.querySelector('svg path[d*="M18 8A6 6 0 006 8"]');
      });
      if (btn) {
        btn.classList.add("ql-bell-btn");
        btn.setAttribute("data-ql-bell", "1");
        bell = btn;
      }
    }
    if (bell && Array.isArray(annData)) {
      var lastSeen = Number(localStorage.getItem("ql_bell_seen_at") || "0");
      var hasUnread = annData.length > 0 && (!lastSeen || annData.some(function (a) {
        return new Date(a.updated_at || a.created_at || a.starts_at || 0).getTime() > lastSeen;
      }));
      var dot = bell.querySelector("span");
      if (dot) dot.style.display = hasUnread ? "" : "none";
    }
  }

  document.addEventListener("click", function (e) {
    var dc = e.target.closest && e.target.closest('a, button');
    if (dc && /daily\s*challenge/i.test(dc.textContent || "")) {
      e.preventDefault();
      e.stopPropagation();
      var practiceNav = document.querySelector('a[href="/practice"]');
      if (practiceNav && practiceNav !== dc) {
        practiceNav.click();
      } else {
        location.assign("/practice");
      }
      return;
    }
    var bell = e.target.closest && (
      e.target.closest("button[data-ql-bell], .ql-bell-btn") ||
      (e.target.closest("button") && e.target.closest("button").querySelector('svg path[d*="M18 8A6 6 0 006 8"]'))
    );
    if (bell) {
      e.preventDefault();
      e.stopPropagation();
      toggleBellNotifications(bell);
      return;
    }
  }, true);

  /* ---------------------------------------------------------------
   * Video Solutions is closed for now: the page shows "Coming soon"
   * for everyone and the sidebar link does not open it.
   * ------------------------------------------------------------- */
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest('a[href="/video-solutions"],a[href^="/video-solutions/"]');
    if (!a) return;
    e.preventDefault(); e.stopPropagation();
    showMaintenance();
  }, true);
  function showMaintenance() {
    if (document.getElementById("ql-mt-overlay")) return;
    var last = document.activeElement;
    var gear = '<g fill="currentColor"><rect x="10.2" y="1.5" width="3.6" height="5" rx="1" transform="rotate(0 12 12)"/><rect x="10.2" y="1.5" width="3.6" height="5" rx="1" transform="rotate(45 12 12)"/><rect x="10.2" y="1.5" width="3.6" height="5" rx="1" transform="rotate(90 12 12)"/><rect x="10.2" y="1.5" width="3.6" height="5" rx="1" transform="rotate(135 12 12)"/><rect x="10.2" y="1.5" width="3.6" height="5" rx="1" transform="rotate(180 12 12)"/><rect x="10.2" y="1.5" width="3.6" height="5" rx="1" transform="rotate(225 12 12)"/><rect x="10.2" y="1.5" width="3.6" height="5" rx="1" transform="rotate(270 12 12)"/><rect x="10.2" y="1.5" width="3.6" height="5" rx="1" transform="rotate(315 12 12)"/><path fill-rule="evenodd" d="M12 4.8a7.2 7.2 0 1 0 0 14.4 7.2 7.2 0 0 0 0-14.4zm0 4.4a2.8 2.8 0 1 1 0 5.6 2.8 2.8 0 0 1 0-5.6z"/></g>';
    var o = document.createElement("div");
    o.id = "ql-mt-overlay";
    o.innerHTML = '<div class="ql-mt" role="dialog" aria-modal="true" aria-labelledby="ql-mt-title"><div class="ql-mt-art" aria-hidden="true"><svg class="g1" width="76" height="76" viewBox="0 0 24 24">' + gear + '</svg><svg class="g2" width="52" height="52" viewBox="0 0 24 24">' + gear + '</svg><span class="spark s1"></span><span class="spark s2"></span><span class="spark s3"></span></div><h2 id="ql-mt-title">Video Solutions is under maintenance</h2><p>We are polishing it so every solution plays smoothly. It will be back soon \u2014 keep practising in the meantime.</p><div class="ql-mt-bar" aria-hidden="true"><i></i></div><div class="ql-mt-actions"><a href="/practice">Go to Practice</a><button type="button">Got it</button></div></div>';
    function close() { document.removeEventListener("keydown", onKey); o.classList.add("out"); setTimeout(function () { o.remove(); }, 180); if (last && last.focus) last.focus(); }
    function onKey(e) { if (e.key === "Escape") close(); }
    o.addEventListener("click", function (e) { if (e.target === o) close(); });
    o.querySelector("button").addEventListener("click", close);
    document.addEventListener("keydown", onKey);
    document.body.appendChild(o);
    o.querySelector("button").focus();
  }
  function lockVideoSolutions() {
    var on = /^\/video-solutions(\/|$)/.test(location.pathname);
    document.documentElement.toggleAttribute("data-ql-vs-locked", on);
    if (!on) return;
    var main = document.querySelector("#root main");
    if (!main || main.querySelector("#ql-vs-soon")) return;
    var box = document.createElement("section");
    box.id = "ql-vs-soon";
    box.innerHTML = '<div class="ql-vs-ico" aria-hidden="true"><svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="5" width="20" height="14" rx="2.5"/><path d="M10 9.5v5l4.5-2.5z" fill="currentColor"/></svg></div><h1>Video solutions are coming soon</h1><p>Step-by-step video answers for questions are on the way. Keep practising in the meantime.</p><a href="/practice">Go to Practice →</a>';
    main.appendChild(box);
  }

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
    } else if (/^\/(exams?(\/|$)|manager\/(discussions|sales|announcements|reports|uploads)\/?$|paper-pricing\/?$)/.test(link.pathname)) {
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

  /* ---------------------------------------------------------------
   * Phone top bar: the level chip is gone and the streak pill sits in
   * its place. The pill is read from the dashboard and remembered, so
   * the other pages show it too.
   * ------------------------------------------------------------- */
  var topStreak = null;
  function syncPhoneTopBar() {
    var header = document.querySelector("header.lg\\:hidden");
    if (!header) return;

    header.querySelectorAll(".rounded-full.tracking-wide").forEach(function (chip) {
      if (/^LVL\s*\d+$/.test(chip.textContent.trim())) tag(chip, "data-ql-lvl", "");
    });

    if (/^\/dashboard\/?$/i.test(window.location.pathname)) {
      document.querySelectorAll("#root div.rounded-full").forEach(function (pill) {
        if (pill.closest("header") || !/^\d+-day streak$/.test(pill.textContent.trim())) return;
        tag(pill, "data-ql-streak-src", "");
        topStreak = { text: pill.textContent.trim(), html: pill.innerHTML };
      });
    }

    var slot = header.querySelector(".ql-top-streak");
    if (!topStreak) return;
    if (!slot) {
      var lvl = header.querySelector("[data-ql-lvl]");
      if (!lvl || !lvl.parentNode) return;
      slot = document.createElement("span");
      slot.className = "ql-top-streak";
      lvl.parentNode.insertBefore(slot, lvl);
    }
    if (slot.getAttribute("data-text") !== topStreak.text) {
      slot.setAttribute("data-text", topStreak.text);
      slot.innerHTML = topStreak.html;
    }
  }

  /* ---------------------------------------------------------------
   * Practice course page on phones: each paper is one compact row
   * (status dot, title, details, Start / Retake), with an
   * All / To do / Done filter above the list.
   * ------------------------------------------------------------- */
  function decorateCoursePapers() {
    if (!/^\/practice\/[^/]+(\/papers)?\/?$/i.test(window.location.pathname)) return;
    var main = document.querySelector("#root main");
    if (!main) return;
    var cards = main.querySelectorAll('a[href^="/quiz/"]>div.group.rounded-xl, a[href^="/paper/"]>div.group.rounded-xl');
    cards.forEach(function (card) {
      var go = card.querySelector(".mt-auto>div:last-child");
      var meta = card.querySelector(".mt-auto>div:first-child");
      if (!go || !meta || go === meta) return;
      var done = /^Retake/i.test(go.textContent.trim());
      tag(card.parentElement, "data-ql-paper", done ? "done" : "todo");
      tag(card, "data-ql-paper-card", done ? "done" : "todo");
      tag(go, "data-ql-paper-go", "");
      var pm = /\/(?:quiz|paper)\/(\d+)/.exec(card.parentElement.getAttribute("href") || "");
      if (pm && window.QLShare && !card.querySelector(".ql-share-btn")) {
        var th = card.querySelector("p");
        meta.appendChild(window.QLShare.button(pm[1], th ? th.textContent.trim() : "", "ql-share-inline ql-share-icon"));
      }
      var badge = card.querySelector(".bg-emerald-50");
      var count = badge ? parseInt(badge.textContent.replace(/\D/g, ""), 10) || 0 : 0;
      tag(meta, "data-ql-attempts", count ? (count === 1 ? "1 attempt" : count + " attempts") : "");
    });
    var row = main.querySelector("[data-ql-course-tabrow]");
    if (!cards.length || !row || main.querySelector(".ql-paper-filter")) return;
    if (!main.getAttribute("data-ql-paper-filter")) main.setAttribute("data-ql-paper-filter", "all");
    var bar = document.createElement("div");
    bar.className = "ql-paper-filter";
    var group = document.createElement("div");
    group.setAttribute("role", "group");
    group.setAttribute("aria-label", "Show papers");
    [["all", "All"], ["todo", "To do"], ["done", "Done"]].forEach(function (item) {
      var button = document.createElement("button");
      button.type = "button";
      button.textContent = item[1];
      button.setAttribute("aria-pressed", main.getAttribute("data-ql-paper-filter") === item[0] ? "true" : "false");
      button.addEventListener("click", function () {
        main.setAttribute("data-ql-paper-filter", item[0]);
        group.querySelectorAll("button").forEach(function (other) {
          other.setAttribute("aria-pressed", other === button ? "true" : "false");
        });
      });
      group.appendChild(button);
    });
    bar.appendChild(group);
    row.insertAdjacentElement("afterend", bar);
  }

  /* ---------------------------------------------------------------
   * Leaderboard on phones, matching the mobile app: a stepped
   * gold / silver / bronze podium that pops in, confetti on opening,
   * XP that counts up, and the student's own row pinned to the bottom
   * until their real place scrolls into view.
   * ------------------------------------------------------------- */
  var lbMe = null, lbMeAsked = false;

  function lbIsPhone() {
    return !!(window.matchMedia && window.matchMedia("(max-width: 640px)").matches);
  }

  function lbConfetti() {
    if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    var canvas = document.createElement("canvas");
    canvas.className = "ql-confetti";
    canvas.setAttribute("aria-hidden", "true");
    var ratio = Math.min(2, window.devicePixelRatio || 1);
    var w = window.innerWidth, h = window.innerHeight;
    canvas.width = w * ratio;
    canvas.height = h * ratio;
    document.body.appendChild(canvas);
    var ctx = canvas.getContext("2d");
    if (!ctx) { canvas.remove(); return; }
    ctx.scale(ratio, ratio);
    var colors = ["#f59e0b", "#3a3fd8", "#3b82f6", "#ec4899", "#a855f7", "#facc15", "#ef4444"];
    var pieces = [];
    for (var i = 0; i < 130; i++) {
      var left = i % 2 === 0;
      pieces.push({
        left: left,
        delay: Math.random() * 0.5,
        angle: (left ? -Math.PI / 3 : (-2 * Math.PI) / 3) + (Math.random() - 0.5) * 0.9,
        speed: h * (0.75 + Math.random() * 0.75),
        w: 5 + Math.random() * 6,
        h: 3 + Math.random() * 5,
        spin: (Math.random() - 0.5) * 14,
        color: colors[Math.floor(Math.random() * colors.length)],
        round: Math.random() < 0.25,
        seed: i
      });
    }
    var total = 3.2, started = 0;
    function frame(now) {
      if (!started) started = now;
      var time = (now - started) / 1000;
      if (time >= total || !canvas.isConnected) { canvas.remove(); return; }
      ctx.clearRect(0, 0, w, h);
      ctx.globalAlpha = Math.max(0, Math.min(1, (1 - time / total) / 0.25));
      pieces.forEach(function (p) {
        var t = time - p.delay;
        if (t <= 0) return;
        var drag = 1 - Math.exp(-2.2 * t);
        var x = (p.left ? 0 : w) + (Math.cos(p.angle) * p.speed * drag) / 2.2 + Math.sin(t * 3 + p.seed) * 6;
        var y = h * 0.62 + (Math.sin(p.angle) * p.speed * drag) / 2.2 + 0.5 * h * 0.55 * t * t;
        if (y > h + 20) return;
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(p.spin * t);
        ctx.fillStyle = p.color;
        if (p.round) {
          ctx.beginPath();
          ctx.arc(0, 0, p.w / 2, 0, Math.PI * 2);
          ctx.fill();
        } else {
          var flutter = 0.35 + 0.65 * Math.abs(Math.cos(t * 9 + p.seed));
          ctx.fillRect((-p.w * flutter) / 2, -p.h / 2, p.w * flutter, p.h);
        }
        ctx.restore();
      });
      requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  function lbInitials(name) {
    var parts = String(name || "").trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return "S";
    if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
    return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
  }

  /* One "you" row: rank, initials, name with a YOU tag, XP. */
  function lbRow(rank, name, xp) {
    var row = document.createElement("div");
    row.className = "ql-lb-row";
    var r = document.createElement("b");
    r.textContent = rank ? "#" + rank : "—";
    var avatar = document.createElement("span");
    avatar.className = "ql-lb-av";
    avatar.textContent = lbInitials(name);
    var label = document.createElement("span");
    label.className = "ql-lb-name";
    var text = document.createElement("span");
    text.textContent = name || "You";
    var you = document.createElement("em");
    you.textContent = "YOU";
    label.append(text, you);
    var points = document.createElement("strong");
    points.className = "ql-lb-xp";
    points.textContent = xp == null ? "" : String(xp);
    row.append(r, avatar, label, points);
    return row;
  }

  function lbDots() {
    var dots = document.createElement("div");
    dots.className = "ql-lb-dots";
    dots.setAttribute("aria-hidden", "true");
    dots.append(document.createElement("i"), document.createElement("i"), document.createElement("i"));
    return dots;
  }

  function decorateLeaderboard() {
    var pin = document.querySelector(".ql-lb-pin");
    if (!/^\/leaderboard\/?$/i.test(window.location.pathname)) {
      if (pin) pin.remove();
      return;
    }
    var heading = null;
    document.querySelectorAll("#root main h1").forEach(function (h) {
      if (!heading && h.textContent.trim() === "Leaderboard") heading = h;
    });
    var root = heading && heading.closest(".space-y-6");
    var table = root && root.querySelector("table");
    if (!root || !table) return;
    tag(root, "data-ql-lb", "");

    var podium = root.querySelector(".grid.grid-cols-3");
    if (podium && podium.children.length === 3) {
      tag(podium, "data-ql-podium", "");
      tag(podium.children[0], "data-place", "2");
      tag(podium.children[1], "data-place", "1");
      tag(podium.children[2], "data-place", "3");
      podium.querySelectorAll("p.font-bold").forEach(countUp);
    }
    if (!root.hasAttribute("data-ql-party")) {
      root.setAttribute("data-ql-party", "");
      lbConfetti();
    }

    // Who is "you": from the list if you are in it, otherwise from the header and your profile.
    var rankNote = heading.parentElement.querySelector("span.text-brand");
    var myRank = rankNote ? parseInt(rankNote.textContent.replace(/\D/g, ""), 10) || null : null;
    var realRow = table.querySelector("tbody tr.bg-brand\\/5");
    var name = "", xp = null;
    if (realRow) {
      var cells = realRow.querySelectorAll("td");
      var nameNode = cells[1] && cells[1].querySelector("span.text-sm");
      name = nameNode && nameNode.firstChild ? String(nameNode.firstChild.nodeValue || "").trim() : "";
      xp = cells[2] ? cells[2].textContent.trim() : null;
      var rankCell = cells[0] ? parseInt(cells[0].textContent.replace(/\D/g, ""), 10) : 0;
      if (rankCell) myRank = rankCell;
    } else {
      try { name = (JSON.parse(localStorage.getItem("lab_user") || "{}") || {}).name || ""; } catch (_) { name = ""; }
      if (lbMe) xp = lbMe.xp;
      var runtime = window.QLStorefront;
      if (!lbMeAsked && runtime && runtime.token && runtime.token()) {
        lbMeAsked = true;
        fetch(runtime.apiBase + "/leaderboard", {
          headers: { Accept: "application/json", Authorization: "Bearer " + runtime.token() }
        }).then(function (response) { return response.ok ? response.json() : null; }).then(function (data) {
          if (data && data.me) { lbMe = data.me; schedule(); }
        }).catch(function () {});
      }
    }
    if (!myRank || (realRow && myRank <= 3)) { if (pin) pin.remove(); return; }

    // Beyond the listed students: three dots, then your row, after the table.
    var target = realRow;
    if (!realRow) {
      var tail = root.querySelector(".ql-lb-tail");
      if (!tail) {
        tail = document.createElement("div");
        tail.className = "ql-lb-tail";
        tail.append(lbDots(), lbRow(myRank, name, xp));
        root.appendChild(tail);
      }
      var tailXp = tail.querySelector(".ql-lb-xp");
      if (tailXp && xp != null && tailXp.textContent !== String(xp)) tailXp.textContent = String(xp);
      target = tail;
    }

    if (!pin) {
      pin = document.createElement("div");
      pin.className = "ql-lb-pin";
      pin.append(lbDots(), lbRow(myRank, name, xp));
      document.body.appendChild(pin);
    }
    // Wide screens: line the pinned row up with the table instead of the whole window.
    if (!pin._qlPlace) {
      pin._qlPlace = function () {
        var t = document.querySelector("[data-ql-lb] table");
        if (window.innerWidth >= 1024 && t) {
          var r = t.getBoundingClientRect();
          pin.style.left = Math.round(r.left) + "px";
          pin.style.right = Math.max(16, Math.round(window.innerWidth - r.right)) + "px";
        } else { pin.style.left = ""; pin.style.right = ""; }
      };
      window.addEventListener("resize", pin._qlPlace, { passive: true });
    }
    pin._qlPlace();
    var pinXp = pin.querySelector(".ql-lb-xp");
    if (pinXp && xp != null && pinXp.textContent !== String(xp)) pinXp.textContent = String(xp);

    // Show the pinned row only while your real place is still below the screen.
    if (pin._qlTarget !== target) {
      if (pin._qlWatch) pin._qlWatch.disconnect();
      pin._qlTarget = target;
      if ("IntersectionObserver" in window) {
        pin._qlWatch = new IntersectionObserver(function (entries) {
          var entry = entries[entries.length - 1];
          var below = !entry.isIntersecting && entry.boundingClientRect.top > window.innerHeight * 0.5;
          pin.classList.toggle("on", below);
        }, { rootMargin: "0px 0px -150px 0px" });
        pin._qlWatch.observe(target);
      }
    }
  }

  /*
   * Login: one banner beside the form.
   *
   * The compiled login screen renders an animated mock dashboard in a 62%
   * column beside the form. The mock is a React subtree, so it is hidden by
   * ql-redesign.css and one static banner is placed in the same column here.
   * The form itself keeps its own markup; only the stacked badge and the
   * two-line headline are trimmed, so the page reads as banner plus form.
   */
  var LOGIN_POINTS = [
    "Every past paper, in a room that behaves like the real exam",
    "A real timer, a question palette and a calculator",
    "Worked solutions the moment you submit",
  ];

  function simplifyLogin() {
    if (!/^\/login\/?$/i.test(window.location.pathname)) return;
    var column = document.querySelector(".lg\\:w-\\[62\\%\\]");
    if (!column) return;

    // The floating "Live preview of your dashboard" label belongs to the mock.
    var float = document.querySelector(".login-preview-float");
    if (float) float.style.display = "none";

    if (!column.querySelector(".ql-login-banner")) {
      // Mark the mock so the stylesheet can hide it without hiding the column.
      Array.prototype.forEach.call(column.children, function (child) {
        if (!child.classList.contains("ql-login-banner")) tag(child, "data-ql-login-preview", "");
      });

      var banner = document.createElement("div");
      banner.className = "ql-login-banner";
      banner.innerHTML =
        '<div class="ql-lg-brand"><img src="/assets/quiz-lab-icon.png" alt="" width="44" height="44"><div>Quiz LAB<small>by GenZ IITian</small></div></div>' +
        '<div class="ql-lg-copy">' +
        '<span class="ql-lg-pill"><i></i>Made for IITM BS students</span>' +
        '<h2>Practise like it\'s the <mark>real exam.</mark></h2>' +
        '<p>Past papers for the IITM BS degree, sat under a real clock with the same palette, navigation and marking you get on the day.</p>' +
        '</div>' +
        '<div class="ql-lg-scene" aria-hidden="true">' +
          '<div class="ql-lg-card">' +
            '<div class="ql-lg-head"><span>MATHS 1 · QUIZ 1</span><b class="ql-lg-ring"><svg viewBox="0 0 40 40"><circle cx="20" cy="20" r="16"/><circle class="bar" cx="20" cy="20" r="16"/></svg><em>45</em></b></div>' +
            '<div class="ql-lg-q">If f(x) = 2x + 3, what is f\u207b\u00b9(7)?</div>' +
            '<div class="ql-lg-opt"><i>A</i>5</div><div class="ql-lg-opt ok"><i>B</i>2<s>Correct</s></div><div class="ql-lg-opt"><i>C</i>17</div>' +
          '</div>' +
          '<div class="ql-lg-pal"><b>Palette</b><div>' + Array.apply(null, Array(15)).map(function (_, k) { return '<i style="--k:' + k + '"></i>'; }).join('') + '</div></div>' +
          '<div class="ql-lg-toast t1"><span>\u26a1</span>+200 XP</div>' +
          '<div class="ql-lg-toast t2"><span>\ud83c\udfc6</span>Rank up</div>' +
          '<div class="ql-lg-toast t3"><span>\u2713</span>Solutions ready</div>' +
        '</div>' +
        '<div class="ql-lg-marquee" aria-hidden="true"><div>' +
          ['Maths 1','Statistics 1','Computational Thinking','English 1','Python','Maths 2','Statistics 2','DBMS','PDSA','Java','MLF','MLT','MLP','BDM'].concat(['Maths 1','Statistics 1','Computational Thinking','English 1','Python','Maths 2','Statistics 2','DBMS','PDSA','Java','MLF','MLT','MLP','BDM']).map(function (c) { return '<span>' + c + '</span>'; }).join('') +
        '</div></div>';
      column.appendChild(banner);
    }

    // Trim the form's own preamble: the banner now carries the message.
    var form = document.querySelector(".max-w-\\[400px\\]");
    if (!form || form.dataset.qlLoginTrimmed === "") return;
    var badge = form.querySelector("span.rounded-full.border-brand\\/25");
    if (badge) badge.style.display = "none";
    var heading = form.querySelector("h2");
    if (heading) {
      heading.textContent = "Sign in";
      heading.classList.remove("sm:text-[34px]");
    }
    var lede = heading && heading.nextElementSibling;
    if (lede && lede.tagName === "P") {
      lede.textContent = "Pick up your streak, rank and saved papers.";
      lede.classList.remove("whitespace-nowrap");
    }
    tag(form, "data-ql-login-trimmed", "");
  }

  function run() {
    var paper = paperRoomPath(window.location.pathname);
    if (paper) { window.location.replace(paper); return; }
    syncBrandName();
    simplifyLogin();
    syncAdminShell();
    syncPaperPricingLink();
    removeStudentWeakSpotCard();
    decorateDashboard();
    syncPhoneTopBar();
    decorateManagerConsole();
    fillMyPapers();
    fillTryPractice();
    syncTryPracticeNav();
    decoratePracticeCards();
    decoratePracticeList();
    syncConsoleNav();
    syncHomeLink();
    decorateCoursePage();
    decorateCoursePapers();
    updateExamNav();
    renderAnnouncements();
    syncBellNotifications();
    lockVideoSolutions();
    decorateLeaderboard();
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
