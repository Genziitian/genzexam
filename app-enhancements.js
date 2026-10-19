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

    var root = hello.closest('[data-ql-dash="root"]') || hello.parentElement;
    while (root && root.id !== "root" && !root.hasAttribute("data-ql-dash") && !/CURRENT STREAK/.test(root.textContent)) root = root.parentElement;
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

    ensureDashboardQuickActions(root);
  }

  function showDownloadsModal() {
    var dialog = document.getElementById("ql-downloads-dialog");
    if (!dialog) {
      dialog = document.createElement("dialog");
      dialog.id = "ql-downloads-dialog";
      dialog.className = "ql-downloads-dialog";
      dialog.innerHTML =
        '<div class="ql-dl-modal-box">' +
          '<div class="ql-dl-icon-circle">' +
            '<svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 14l-4-4h3V8h2v4h3l-4 4z"/></svg>' +
          '</div>' +
          '<h2>Available in App Only</h2>' +
          '<p>This is only available in the app.<br>Please wait, that is coming soon!</p>' +
          '<button type="button" class="ql-dl-close-btn">Got it</button>' +
        '</div>';
      document.body.appendChild(dialog);

      var closeBtn = dialog.querySelector(".ql-dl-close-btn");
      if (closeBtn) closeBtn.addEventListener("click", function () { dialog.close(); });
      dialog.addEventListener("click", function (e) {
        var box = dialog.querySelector(".ql-dl-modal-box");
        if (!box) return;
        var rect = box.getBoundingClientRect();
        if (e.clientX < rect.left || e.clientX > rect.right || e.clientY < rect.top || e.clientY > rect.bottom) {
          dialog.close();
        }
      });
    }
    if (typeof dialog.showModal === "function") {
      dialog.showModal();
    } else {
      dialog.setAttribute("open", "");
    }
  }

  function ensureDashboardQuickActions(root) {
    if (!root) return;
    var statCard = root.querySelector("[data-ql-stat]");
    var statGrid = statCard ? statCard.parentElement : null;
    var perfCard = root.querySelector("[data-ql-card=perf]");
    var dashboardStatus = root.querySelector("[data-ql-dashboard-status]");
    if (!statGrid && !perfCard && !dashboardStatus) return;

    var existing = root.querySelector("#ql-dash-quick-actions");
    if (!existing) {
      existing = document.createElement("div");
      existing.id = "ql-dash-quick-actions";
      existing.className = "ql-dash-qa";
      existing.innerHTML =
        '<div class="ql-qa-row">' +
          '<button type="button" class="ql-qa-card ql-qa-half ql-qa-downloads" aria-label="Downloads">' +
            '<div class="ql-qa-icon-wrap" style="background:#DBEAFE">' +
              '<svg class="ql-qa-icon" style="color:#2563EB" width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 14l-4-4h3V8h2v4h3l-4 4z"/></svg>' +
              '<span class="ql-qa-pro-badge icon-corner">PRO</span>' +
            '</div>' +
            '<div class="ql-qa-info">' +
              '<span class="ql-qa-label">Downloads</span>' +
            '</div>' +
            '<svg class="ql-qa-arrow" style="color:#2563EB" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>' +
          '</button>' +
          '<a href="/discussions" class="ql-qa-card ql-qa-half ql-qa-discussions" aria-label="Discussions">' +
            '<div class="ql-qa-icon-wrap" style="background:#F3E8FF">' +
              '<svg class="ql-qa-icon" style="color:#9333EA" width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm-3 9H7V9h10v2zm-4 4H7v-2h6v2zm4-8H7V5h10v2z"/></svg>' +
            '</div>' +
            '<div class="ql-qa-info">' +
              '<span class="ql-qa-label">Discussions</span>' +
            '</div>' +
            '<svg class="ql-qa-arrow" style="color:#9333EA" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>' +
          '</a>' +
        '</div>' +
        '<a href="/upload-paper" class="ql-qa-card ql-qa-wide ql-qa-upload" aria-label="Upload a paper">' +
          '<div class="ql-qa-icon-wrap" style="background:#DCFCE7">' +
            '<svg class="ql-qa-icon" style="color:#16A34A" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="12" y1="18" x2="12" y2="12"/><polyline points="9 15 12 12 15 15"/></svg>' +
          '</div>' +
          '<div class="ql-qa-info">' +
            '<div class="ql-qa-title-row">' +
              '<span class="ql-qa-label">Upload a paper</span>' +
              '<span class="ql-qa-pro-badge inline">PRO</span>' +
            '</div>' +
            '<span class="ql-qa-sub">Turn your PDF into a practice test</span>' +
          '</div>' +
          '<svg class="ql-qa-arrow" style="color:#16A34A" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>' +
        '</a>' +
        '<a href="/try-practice" class="ql-qa-card ql-qa-wide ql-qa-spin" aria-label="Test yourself">' +
          '<div class="ql-qa-icon-wrap" style="background:#F3E8FF">' +
            '<svg class="ql-qa-icon" style="color:#7C3AED" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="4" ry="4"/><circle cx="8.5" cy="8.5" r="1.5" fill="currentColor"/><circle cx="15.5" cy="8.5" r="1.5" fill="currentColor"/><circle cx="8.5" cy="15.5" r="1.5" fill="currentColor"/><circle cx="15.5" cy="15.5" r="1.5" fill="currentColor"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/></svg>' +
          '</div>' +
          '<div class="ql-qa-info">' +
            '<div class="ql-qa-title-row">' +
              '<span class="ql-qa-label">Test yourself</span>' +
              '<span class="ql-qa-pro-badge inline">PRO</span>' +
            '</div>' +
            '<span class="ql-qa-sub">Spin a custom practice paper</span>' +
          '</div>' +
          '<svg class="ql-qa-arrow" style="color:#7C3AED" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg>' +
        '</a>';

      var dlBtn = existing.querySelector(".ql-qa-downloads");
      if (dlBtn) {
        dlBtn.addEventListener("click", function (e) {
          e.preventDefault();
          showDownloadsModal();
        });
      }

      existing.querySelectorAll("a").forEach(function (link) {
        link.addEventListener("click", function (e) {
          if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
          var href = link.getAttribute("href");
          if (!href) return;
          var targetNav = document.querySelector('nav a[href="' + href + '"]');
          if (targetNav) {
            e.preventDefault();
            targetNav.click();
            return;
          }
          e.preventDefault();
          window.location.assign(href);
        });
      });
    }

    if (statGrid && statGrid.parentNode) {
      if (existing.previousElementSibling !== statGrid || existing.parentNode !== statGrid.parentNode) {
        statGrid.parentNode.insertBefore(existing, statGrid.nextSibling);
      }
    } else if (perfCard && perfCard.parentNode) {
      if (existing.nextElementSibling !== perfCard || existing.parentNode !== perfCard.parentNode) {
        perfCard.parentNode.insertBefore(existing, perfCard);
      }
    } else if (dashboardStatus && dashboardStatus.parentNode) {
      if (existing.previousElementSibling !== dashboardStatus || existing.parentNode !== dashboardStatus.parentNode) {
        dashboardStatus.parentNode.insertBefore(existing, dashboardStatus.nextSibling);
      }
    }
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
    // If the framework wiped the page's content during navigation, render it again.
    if (host && host.dataset.qlLoaded && !host.querySelector(".ql-mp-grid")) host.dataset.qlLoaded = "";
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
          var state = paper.available === false ? "Unavailable" : expired ? "Access expired" : purchased ? "Purchased \u2713" : isSpin ? "Private tests" : uploaded ? "Uploaded" : paid ? "Paid" : "Free";

          var card = document.createElement("article");
          card.className = "ql-mp-card" + (purchased && usable ? " owned" : "");

          // Card top action buttons (Share + Heart)
          var topActions = document.createElement("div");
          topActions.className = "ql-mp-card-top-actions";
          if (window.QLShare && paper.available !== false && paper.can_share !== false && !paper.is_personal && !["spin_practice", "personal_upload"].includes(paper.source)) {
            topActions.appendChild(window.QLShare.button(paper.id, paper.title || "", "ql-share-icon"));
          }

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
          topActions.appendChild(heart);
          card.appendChild(topActions);

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

  var uploadQuotaTimer = null, uploadSyncTimer = null, uploadListRequest = 0;
  function fillUploadPaperPage() {
    var onUpload = /^\/(upload-paper|upload)(\/|$)/i.test(window.location.pathname);
    var host = document.getElementById("ql-upload-paper-page");
    if (!onUpload) {
      if (host) {
        host.dataset.qlLoaded = "";
        host.innerHTML = "";
      }
      var existingUpload = document.querySelector(".ql-upload-page-container");
      if (existingUpload && (!host || !host.contains(existingUpload))) {
        existingUpload.remove();
      }
      clearInterval(uploadQuotaTimer);
      clearInterval(uploadSyncTimer);
      return;
    }

    var staleRewards = document.getElementById("ql-rewards-page") || document.querySelector(".ql-rewards-page");
    if (staleRewards && staleRewards !== host) staleRewards.remove();
    var stalePractice = document.getElementById("ql-try-practice") || document.querySelector(".ql-spin-container");
    if (stalePractice && stalePractice !== host) stalePractice.remove();

    if (!host) {
      var outlet = document.querySelector("#root main .page-enter, #root main");
      if (outlet && !outlet.querySelector("#ql-upload-paper-page")) {
        host = document.createElement("div");
        host.id = "ql-upload-paper-page";
        outlet.appendChild(host);
      }
    }
    if (!host || host.dataset.qlLoaded) return;
    var runtime = window.QLStorefront;
    var tok = runtime && runtime.token ? runtime.token() : (localStorage.getItem("lab_token") || "");
    if (!tok) return;
    host.dataset.qlLoaded = "1";
    document.title = "Upload a paper · Quiz LAB";

    var container = document.createElement("div");
    container.className = "ql-upload-page-container";
    container.innerHTML =
      '<div class="ql-up-head">' +
        '<div class="ql-up-title-row">' +
          '<a href="/dashboard" class="ql-up-back-btn" aria-label="Go back">' +
            '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>' +
            '<span>Back</span>' +
          '</a>' +
          '<div class="ql-up-title-wrap">' +
            '<h1 class="ql-up-title">Upload a paper.</h1>' +
          '</div>' +
          '<span class="ql-up-pro-badge">PRO</span>' +
        '</div>' +
        '<p class="ql-up-subtitle">Upload a study PDF or structured JSON to convert it into a full practice test in your account.</p>' +
      '</div>' +

      '<section class="ql-up-card ql-up-steps-card">' +
        '<div class="ql-up-card-header">' +
          '<h2 class="ql-up-card-title">How it works</h2>' +
        '</div>' +
        '<div class="ql-up-steps">' +
          '<div class="ql-up-step">' +
            '<div class="ql-up-step-icon" style="background:#eef2ff;color:#4338ca">📄</div>' +
            '<div class="ql-up-step-info">' +
              '<strong>Upload</strong>' +
              '<span>Choose a PDF or JSON</span>' +
            '</div>' +
          '</div>' +
          '<div class="ql-up-step-arrow">→</div>' +
          '<div class="ql-up-step">' +
            '<div class="ql-up-step-icon" style="background:#fffbeb;color:#d97706">✦</div>' +
            '<div class="ql-up-step-info">' +
              '<strong>Convert</strong>' +
            '</div>' +
          '</div>' +
          '<div class="ql-up-step-arrow">→</div>' +
          '<div class="ql-up-step">' +
            '<div class="ql-up-step-icon" style="background:#ecfdf5;color:#059669">▶</div>' +
            '<div class="ql-up-step-info">' +
              '<strong>Take test</strong>' +
              '<span>Practice anytime in My Papers</span>' +
            '</div>' +
          '</div>' +
        '</div>' +
      '</section>' +

      '<section class="ql-up-card ql-up-quota-card">' +
        '<div class="ql-up-quota-row">' +
          '<div class="ql-up-quota-info">' +
            '<span class="ql-up-quota-headline" aria-live="polite">Checking your uploads…</span>' +
            '<span class="ql-up-quota-sub"></span>' +
          '</div>' +
          '<button type="button" class="ql-upload-new ql-up-quota-btn" style="display:none">Use free upload</button>' +
        '</div>' +
        '<div class="ql-up-pro-banner" style="display:none">' +
          '<div class="ql-up-pro-banner-left">' +
            '<span class="ql-up-pro-crown">👑</span>' +
            '<div class="ql-up-pro-banner-text">' +
              '<strong>5 uploads every 7 days with Pro</strong>' +
              '<small>Pro members get 5 rolling slots and priority AI conversion</small>' +
            '</div>' +
          '</div>' +
          '<button type="button" class="ql-up-pro-btn">Get Pro</button>' +
        '</div>' +
      '</section>' +

      '<form class="ql-up-card ql-up-form-card ql-upload-form" style="display:none">' +
        '<div class="ql-up-card-header">' +
          '<h2 class="ql-up-card-title">Upload your file</h2>' +
          '<button type="button" class="ql-upload-hide ql-up-ghost-btn">Close upload</button>' +
        '</div>' +
        '<label class="ql-up-dropzone ql-upload-drop">' +
          '<div class="ql-up-dropzone-icon">' +
            '<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>' +
          '</div>' +
          '<strong>Choose a PDF or JSON</strong>' +
          '<small>Up to 10 MB · PDF up to 30 pages</small>' +
          '<input class="ql-upload-file" type="file" name="paper" accept=".pdf,.json,application/pdf,application/json" required>' +
        '</label>' +
        '<div class="ql-up-chip ql-upload-chip"></div>' +
        '<button class="ql-upload-pick ql-up-submit-btn" type="submit" disabled>Create my test</button>' +
        '<p class="ql-upload-state ql-up-state" aria-live="polite"></p>' +
      '</form>' +

      '<section class="ql-up-card ql-up-papers-card">' +
        '<div class="ql-up-card-header">' +
          '<h2 class="ql-up-card-title">Your papers</h2>' +
        '</div>' +
        '<div class="ql-upload-list ql-up-papers-list">' +
          '<p class="ql-upload-state ql-up-state">Loading…</p>' +
        '</div>' +
      '</section>' +

      '<section class="ql-up-card ql-up-rules-card ql-up-rules">' +
        '<details class="ql-upload-rules">' +
          '<summary>' +
            '<span>Upload rules</span>' +
            '<span class="ql-up-rules-toggle">See all</span>' +
          '</summary>' +
          '<div class="ql-up-rules-content ql-upload-note">' +
            '<div class="ql-up-rule-item">' +
              '<strong>Allowance rules</strong>' +
              '<p>Free: 1 successful upload every 7 days. Pro: 5 in the same rolling window. Each slot returns 7 days after use. Failed conversions do not use a slot.</p>' +
            '</div>' +
            '<div class="ql-up-rule-item">' +
              '<strong>Format & size</strong>' +
              '<p>PDF or JSON, up to 10 MB. PDFs support up to 30 pages of selectable text; scanned PDFs are not supported.</p>' +
            '</div>' +
            '<div class="ql-up-rule-item">' +
              '<strong>DeepSeek AI processing</strong>' +
              '<p>PDF text is sent to DeepSeek AI to structure questions. The temporary file is deleted after processing. JSON is processed without AI. Review questions because AI can make mistakes.</p>' +
            '</div>' +
            '<div class="ql-up-rule-item">' +
              '<strong>Availability</strong>' +
              '<p>Your tests appear in My Papers. Our team may review uploads and add suitable papers to the public library.</p>' +
            '</div>' +
          '</div>' +
        '</details>' +
      '</section>';

    host.replaceChildren(container);

    var quotaHeadline = container.querySelector(".ql-up-quota-headline");
    var quotaSub = container.querySelector(".ql-up-quota-sub");
    var newUpload = container.querySelector(".ql-upload-new");
    var proBanner = container.querySelector(".ql-up-pro-banner");
    var proBtn = container.querySelector(".ql-up-pro-btn");
    var uploadForm = container.querySelector(".ql-upload-form");
    var hideForm = container.querySelector(".ql-upload-hide");
    var drop = container.querySelector(".ql-upload-drop");
    var fileInput = container.querySelector(".ql-upload-file");
    var chip = container.querySelector(".ql-upload-chip");
    var button = container.querySelector(".ql-upload-pick");
    var state = container.querySelector(".ql-up-form-card .ql-upload-state");
    var list = container.querySelector(".ql-upload-list");
    var rules = container.querySelector(".ql-upload-rules");
    var backBtn = container.querySelector(".ql-up-back-btn");

    var allowed = false, uploading = false, lastQuota = null;

    if (backBtn) {
      backBtn.addEventListener("click", function (e) {
        if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
        e.preventDefault();
        if (window.history.length > 1) {
          window.history.back();
        } else {
          window.location.assign("/dashboard");
        }
      });
    }

    rules.addEventListener("toggle", function () {
      var toggle = rules.querySelector(".ql-up-rules-toggle");
      if (toggle) toggle.textContent = rules.open ? "See less" : "See all";
    });

    newUpload.addEventListener("click", function () {
      uploadForm.style.display = "flex";
      fileInput.focus();
      uploadForm.scrollIntoView({ behavior: "smooth", block: "nearest" });
    });

    hideForm.addEventListener("click", function () {
      uploadForm.style.display = "none";
    });

    proBtn.addEventListener("click", function () {
      if (typeof window.openProPaywall === "function") window.openProPaywall();
      else window.location.assign("/pro");
    });

    function authHeaders() {
      return { Accept: "application/json", Authorization: "Bearer " + runtime.token(), "X-QuizLab-Client": "web" };
    }

    function inTime(iso) {
      var seconds = Math.max(0, Math.ceil((new Date(iso).getTime() - Date.now()) / 1000));
      if (!seconds) return "now — refresh to check availability";
      return "in " + Math.floor(seconds / 86400) + "d " + Math.floor(seconds / 3600) % 24 + "h " + Math.floor(seconds / 60) % 60 + "m " + seconds % 60 + "s";
    }

    function renderQuota(q) {
      lastQuota = q;
      clearInterval(uploadQuotaTimer);
      if (!q) {
        allowed = false;
        newUpload.style.display = "none";
        newUpload.disabled = true;
        quotaHeadline.textContent = "Upload allowance unavailable";
        quotaSub.textContent = "Please refresh to retry.";
        quotaSub.style.display = "";
        proBanner.style.display = "none";
        syncButton();
        return;
      }
      allowed = q.remaining > 0;
      quotaHeadline.textContent = allowed
        ? (q.is_pro ? q.remaining + " of " + q.limit + " uploads available" : q.remaining + " free upload available")
        : "Upload allowance used";

      if (!allowed && q.resets_at) {
        quotaSub.style.display = "";
        var refreshed = false;
        function tick() {
          quotaSub.textContent = "Next " + (q.is_pro ? "upload " : "free upload ") + inTime(q.resets_at);
          if (new Date(q.resets_at).getTime() <= Date.now() && !refreshed) {
            refreshed = true;
            clearInterval(uploadQuotaTimer);
            refreshUploads();
          }
        }
        tick();
        if (!refreshed) uploadQuotaTimer = setInterval(tick, 1000);
      } else {
        quotaSub.textContent = q.is_pro ? "Resets every 7 days (rolling window)" : "";
        quotaSub.style.display = q.is_pro ? "" : "none";
      }

      newUpload.style.display = allowed ? "inline-flex" : "none";
      newUpload.disabled = !allowed || uploading;
      newUpload.textContent = q.is_pro ? "＋ Upload paper" : "Claim " + q.remaining + " free upload" + (q.remaining === 1 ? "" : "s");

      if (!q.is_pro) {
        proBanner.style.display = "flex";
      } else {
        proBanner.style.display = "none";
      }

      if (!allowed && !uploading) uploadForm.style.display = "none";
      drop.classList.toggle("disabled", !allowed);
      syncButton();
    }

    function syncButton() {
      button.disabled = uploading || !allowed || !fileInput.files.length;
    }

    function setFile(file) {
      chip.classList.toggle("on", !!file);
      chip.textContent = file ? "📎 " + file.name + " · " + Math.max(1, Math.round(file.size / 1024)) + " KB" : "";
      syncButton();
    }

    fileInput.addEventListener("change", function () {
      setFile(fileInput.files[0]);
    });

    ["dragenter", "dragover"].forEach(function (name) {
      drop.addEventListener(name, function (e) { e.preventDefault(); drop.classList.add("over"); });
    });
    ["dragleave", "drop"].forEach(function (name) {
      drop.addEventListener(name, function (e) { e.preventDefault(); drop.classList.remove("over"); });
    });
    drop.addEventListener("drop", function (e) {
      var f = e.dataTransfer && e.dataTransfer.files[0];
      if (!f || !allowed) return;
      try {
        var dt = new DataTransfer();
        dt.items.add(f);
        fileInput.files = dt.files;
        setFile(f);
      } catch (_) {}
    });

    function refreshUploads() {
      if (!host.isConnected || uploading) return;
      var requestId = ++uploadListRequest;
      fetch(runtime.apiBase + "/student/uploaded-papers", { headers: authHeaders() }).then(async function (response) {
        var data = null;
        try { data = await response.json(); } catch (_) {}
        if (!response.ok) {
          var msg = (data && (data.message || data.error)) || ("Could not load uploads (" + response.status + ")");
          throw new Error(msg);
        }
        return data;
      }).then(function (data) {
        if (!host.isConnected || requestId !== uploadListRequest || uploading) return;
        renderQuota(data.quota);
        list.replaceChildren();
        var papers = Array.isArray(data.papers) ? data.papers.slice().sort(function (a, b) { return Number(b.id) - Number(a.id); }) : [];
        if (!papers.length) {
          var empty = document.createElement("div");
          empty.className = "ql-up-empty";
          empty.textContent = allowed
            ? "No papers yet. Use the upload button above to create a test."
            : lastQuota ? "No papers to show. Your next upload countdown is shown above; existing tests remain available here."
            : "Your upload allowance could not be loaded. Please refresh.";
          list.appendChild(empty);
          return;
        }
        papers.forEach(function (paper) {
          var row = document.createElement("div");
          row.className = "ql-up-paper-item";
          var info = document.createElement("div");
          info.className = "ql-up-paper-info";
          var title = document.createElement("strong");
          title.textContent = paper.title || "My paper";
          var count = document.createElement("span");
          count.textContent = (paper.question_count || 0) + " questions · Your private test";
          info.append(title, count);
          var link = document.createElement("a");
          link.href = "/paper/" + encodeURIComponent(paper.id);
          link.className = "ql-up-paper-start";
          link.textContent = "Start";
          row.append(info, link);
          list.appendChild(row);
        });
      }).catch(function (error) {
        if (!host.isConnected || requestId !== uploadListRequest || uploading) return;
        list.replaceChildren();
        var message = document.createElement("p");
        message.className = "ql-up-state ql-up-state-err";
        message.textContent = error.message;
        list.appendChild(message);
        quotaHeadline.textContent = "Uploads unavailable";
        quotaSub.textContent = error.message;
        allowed = false;
        newUpload.disabled = true;
        syncButton();
      });
    }

    refreshUploads();
    uploadSyncTimer = setInterval(function () {
      if (host.isConnected && !document.hidden && !uploading) refreshUploads();
    }, 30000);

    var steps = ["Reading your paper…", "Finding the questions…", "Checking answers and options…", "Building your test…"];
    uploadForm.addEventListener("submit", function (event) {
      event.preventDefault();
      var file = fileInput.files[0];
      if (!file || !allowed || uploading) return;
      uploading = true;
      uploadListRequest++;
      newUpload.disabled = true;
      var n = 0, ticker;
      button.disabled = true;
      button.classList.add("busy");
      button.textContent = steps[0];
      state.className = "ql-up-state";
      state.textContent = "This can take a minute for a PDF.";
      ticker = setInterval(function () {
        n = Math.min(n + 1, steps.length - 1);
        button.textContent = steps[n];
      }, 6000);
      var form = new FormData();
      form.append("paper", file);
      fetch(runtime.apiBase + "/student/uploaded-papers", { method: "POST", headers: authHeaders(), body: form }).then(function (response) {
        return response.json().catch(function () { return {}; }).then(function (data) {
          if (!response.ok) {
            if (data.quota) renderQuota(data.quota);
            throw new Error(data.error || data.message || "Could not create a test from this file.");
          }
          return data;
        });
      }).then(function (data) {
        state.className = "ql-up-state ok";
        state.textContent = "✅ " + (data.title || "Your paper") + " is ready with " + (data.question_count || 0) + " questions.";
        fileInput.value = "";
        setFile(null);
        if (data.quota) renderQuota(data.quota);
        uploading = false;
        refreshUploads();
        var myPapersHost = document.getElementById("ql-my-papers");
        if (myPapersHost) {
          myPapersHost.dataset.qlLoaded = "";
          fillMyPapers();
        }
      }).catch(function (error) {
        state.className = "ql-up-state err";
        state.textContent = error.message;
      }).finally(function () {
        clearInterval(ticker);
        uploading = false;
        button.classList.remove("busy");
        button.textContent = "Create my test";
        newUpload.disabled = !allowed;
        if (!allowed) uploadForm.style.display = "none";
        syncButton();
      });
    });
  }

  function openUploadedPaperModal(runtime) {
    if (!/^\/(upload-paper|upload)(\/|$)/i.test(window.location.pathname)) {
      window.location.assign("/upload-paper");
    }
  }

  function installUploadedPaperDialog(host, runtime) {
    // Handled by fillUploadPaperPage on /upload-paper
  }

  document.addEventListener("click", function (e) {
    var btn = e.target.closest && e.target.closest(".ql-upload-open");
    if (!btn) return;
    e.preventDefault();
    openUploadedPaperModal(window.QLStorefront);
  });

  /* ---------------------------------------------------------------
   * Test yourself: Spin wheel & custom practice paper builder.
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
        existing.dataset.qlInjected = "1";
        existing.className = "mb-0.5 flex items-center gap-2.5 rounded-lg px-3 py-[7px] text-[13px] font-medium transition-all " +
          (isTry ? "ql-nav-active" : "text-[#9ca3af] hover:bg-[#1c2533] hover:text-[#e5e7eb]");
        existing.innerHTML = '<span class="flex h-5 w-5 items-center justify-center"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/></svg></span><span>Test yourself</span>';
        existing.addEventListener("click", function (e) {
          if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
          e.preventDefault();
          window.location.assign("/try-practice");
        });
        if (anchor.nextSibling) {
          anchor.parentNode.insertBefore(existing, anchor.nextSibling);
        } else {
          anchor.parentNode.appendChild(existing);
        }
      } else if (existing.dataset.qlInjected) {
        existing.className = "mb-0.5 flex items-center gap-2.5 rounded-lg px-3 py-[7px] text-[13px] font-medium transition-all " +
          (isTry ? "ql-nav-active" : "text-[#9ca3af] hover:bg-[#1c2533] hover:text-[#e5e7eb]");
      } else {
        if (existing.classList.contains("text-slate-700")) {
          existing.classList.remove("text-slate-700", "hover:bg-slate-100", "bg-brand", "text-white", "shadow-sm");
          if (!existing.classList.contains("ql-nav-active")) {
            existing.classList.add("text-[#9ca3af]", "hover:bg-[#1c2533]", "hover:text-[#e5e7eb]");
          }
        }
        if (isTry) {
          existing.classList.add("ql-nav-active");
          existing.classList.remove("text-[#9ca3af]");
        } else if (existing.classList.contains("ql-nav-active") && !/^\/try-practice(\/|$)/i.test(window.location.pathname)) {
          existing.classList.remove("ql-nav-active");
          existing.classList.add("text-[#9ca3af]");
        }
      }
      if (!existing.querySelector('.ql-spin-pro-badge')) {
        var badge = document.createElement('span');
        badge.className = 'ql-spin-pro-badge';
        badge.textContent = 'PRO';
        badge.title = 'Pro: up to 7 spins daily. Free: 1 daily.';
        existing.appendChild(badge);
      }
    });
  }

  function syncUploadPaperNav() {
    var isUpload = /^\/(upload-paper|upload)(\/|$)/i.test(window.location.pathname);
    document.querySelectorAll("#root aside nav").forEach(function (nav) {
      if (!nav.querySelector('a[href="/dashboard"]')) return;
      var oldButton = nav.querySelector("button.ql-sidebar-upload");
      if (oldButton) oldButton.remove();

      var existing = nav.querySelector('a[href="/upload-paper"]');
      if (!existing) {
        var anchor = nav.querySelector('a[href="/my-papers"]') || nav.querySelector('a[href="/practice"]');
        if (!anchor) return;
        var link = document.createElement("a");
        link.href = "/upload-paper";
        link.dataset.qlInjected = "1";
        link.className = "ql-sidebar-upload mb-0.5 flex w-full items-center gap-2.5 rounded-lg px-3 py-[7px] text-[13px] font-medium transition-all " +
          (isUpload ? "ql-nav-active" : "text-[#9ca3af] hover:bg-[#1c2533] hover:text-[#e5e7eb]");
        link.innerHTML = '<span class="flex-shrink-0 opacity-75">' +
          '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>' +
          '</span>' +
          '<span class="flex-1 text-left tracking-[-0.01em]">Upload a paper</span>' +
          '<span class="ql-upload-tag">PRO</span>';
        link.addEventListener("click", function (e) {
          if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
          e.preventDefault();
          window.location.assign("/upload-paper");
        });
        if (anchor.nextSibling) {
          anchor.parentNode.insertBefore(link, anchor.nextSibling);
        } else {
          anchor.parentNode.appendChild(link);
        }
      } else {
        if (isUpload) {
          existing.classList.add("ql-nav-active");
          existing.classList.remove("text-[#9ca3af]");
        } else {
          existing.classList.remove("ql-nav-active");
          existing.classList.add("text-[#9ca3af]");
        }
      }
    });
  }

  function fillTryPractice() {
    var onTry = /^\/(try-practice|spin-practice)(\/|$)/i.test(window.location.pathname);
    var bottomNav = document.querySelector("#root > div > div.fixed.bottom-0, #root div.fixed.inset-x-0.bottom-0");
    var host = document.getElementById("ql-try-practice");
    if (!onTry) {
      if (document.body.classList.contains("ql-page-try-practice")) {
        document.body.classList.remove("ql-page-try-practice");
        if (bottomNav) bottomNav.style.removeProperty("display");
      }
      if (host) {
        host.dataset.qlLoaded = "";
        host.innerHTML = "";
      }
      var existingSpin = document.querySelector(".ql-spin-container");
      if (existingSpin && (!host || !host.contains(existingSpin))) {
        existingSpin.remove();
      }
      return;
    }
    document.body.classList.add("ql-page-try-practice");
    if (bottomNav) bottomNav.style.setProperty("display", "none", "important");

    var staleRewards = document.getElementById("ql-rewards-page") || document.querySelector(".ql-rewards-page");
    if (staleRewards && staleRewards !== host) staleRewards.remove();
    var staleUpload = document.getElementById("ql-upload-paper-page") || document.querySelector(".ql-upload-page-container");
    if (staleUpload && staleUpload !== host) staleUpload.remove();

    if (!host) {
      var outlet = document.querySelector("#root main .page-enter, #root main");
      if (outlet && !outlet.querySelector("#ql-try-practice")) {
        host = document.createElement("div");
        host.id = "ql-try-practice";
        outlet.appendChild(host);
      }
    }
    if (!host || host.dataset.qlLoaded) return;
    var runtime = window.QLStorefront;
    var tok = runtime && runtime.token ? runtime.token() : (localStorage.getItem("lab_token") || "");
    if (!tok) return;
    host.dataset.qlLoaded = "1";
    document.title = "Test yourself · Quiz LAB";
    host.innerHTML = [
      '<section class="ql-spin-container">',
        '<header class="ql-spin-head">',
          '<div class="ql-spin-back-row">',
            '<a href="/dashboard" class="ql-spin-back-btn ql-up-back-btn" id="ql-spin-back">',
              '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>',
              '<span>Back</span>',
            '</a>',
          '</div>',
          '<div class="ql-spin-heading-row"><h1>Test yourself <span class="ql-spin-pro-badge" title="Pro: up to 7 spins daily. Free: 1 daily.">PRO</span></h1><button type="button" class="ql-spin-help-button" id="ql-spin-help" aria-haspopup="dialog">How it works</button></div><p>Generate 10 random question</p></header>',
        '<div class="ql-spin-grid">',
          '<div class="ql-spin-wheel-card">',
            '<div class="ql-wheel-stage" aria-hidden="true"><canvas id="ql-spin-canvas" width="680" height="680"></canvas>',
              '<span class="ql-wheel-flare ql-wheel-flare-one"></span><span class="ql-wheel-flare ql-wheel-flare-two"></span><span class="ql-wheel-flare ql-wheel-flare-three"></span><span class="ql-wheel-pointer"></span><span class="ql-wheel-hub"><img src="/android-chrome-192x192.png" alt=""></span>',
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
            '<div class="ql-spin-action-dock">',
              '<button type="submit" class="ql-spin-main-btn" id="ql-spin-main-btn" disabled><span aria-hidden="true">↻</span> Spin the wheel</button>',
            '</div>',
          '</form>',
        '</div>',
      '</section>'
    ].join("");
    host.querySelector("#ql-spin-help").addEventListener("click", function () {
      var dialog = document.createElement("dialog");
      dialog.className = "ql-spin-help-dialog";
      dialog.setAttribute("aria-labelledby", "ql-spin-help-title");
      dialog.innerHTML = '<div class="ql-spin-help-content">' +
        '<div class="ql-spin-help-top"><span><img src="/assets/quiz-lab-icon.png" alt="" width="32" height="32">Quiz LAB</span><button type="button" class="ql-spin-help-close" aria-label="Close explanation" autofocus><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg></button></div>' +
        '<h2 id="ql-spin-help-title">How it works</h2><p>A fresh mix of questions from existing papers.</p>' +
        '<ol><li><strong>Choose your course.</strong> Set the weeks you want to practise.</li><li><strong>Pick paper types.</strong> Select one, several, or all types. A paper name is optional.</li><li><strong>Spin the wheel.</strong> Get up to 10 random matching questions. The wheel animation does not change your filters.</li><li><strong>Open your paper.</strong> Choose your time limit and start. Find the paper again in My Papers.</li></ol>' +
        '<p class="ql-spin-help-free">1 free spin daily, or up to 7 daily with Pro. Resets at midnight IST. Papers auto-delete after 30 days. No upload tokens used. Your papers are private and cannot be shared.</p>' +
        '<button type="button" class="ql-spin-help-done">Got it</button></div>';
      host.appendChild(dialog);
      dialog.querySelector(".ql-spin-help-close").addEventListener("click", function () { dialog.close(); });
      dialog.querySelector(".ql-spin-help-done").addEventListener("click", function () { dialog.close(); });
      dialog.addEventListener("click", function (event) {
        var bounds = dialog.getBoundingClientRect();
        if (event.target === dialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) dialog.close();
      });
      dialog.addEventListener("close", function () { dialog.remove(); });
      dialog.showModal();
    });
    var backBtn = host.querySelector("#ql-spin-back");
    if (backBtn) {
      backBtn.addEventListener("click", function (e) {
        if (isSpinning) return;
        if (e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
        e.preventDefault();
        if (window.history.length > 1) {
          window.history.back();
        } else {
          window.location.assign("/dashboard");
        }
      });
    }
    var canvas = host.querySelector("#ql-spin-canvas"), ctx = canvas.getContext("2d");
    var form = host.querySelector("#ql-spin-form"), settings = host.querySelector("#ql-spin-settings");
    var mainBtn = host.querySelector("#ql-spin-main-btn"), outcome = host.querySelector("#ql-spin-outcome");
    var courseSelect = host.querySelector("#ql-spin-course"), retry = host.querySelector("#ql-spin-retry");
    var weekMinInput = host.querySelector("#ql-spin-week-min"), weekMaxInput = host.querySelector("#ql-spin-week-max");
    var types = Array.from(host.querySelectorAll(".ql-spin-types-list input"));
    var currentAngle = 0, isSpinning = false, spinQuota = null;
    var GOLD = "#c9a961", GOLD_LIGHT = "#f1e1b6", GOLD_DEEP = "#8e7234";
    function drawWheel(angle) {
      if (!ctx) return;
      ctx.setTransform(2, 0, 0, 2, 0, 0);
      ctx.clearRect(0, 0, 340, 340);
      var cx = 170, cy = 170, radius = 138;
      // Champagne metal rim
      var rim = ctx.createLinearGradient(20, 20, 320, 320);
      rim.addColorStop(0, GOLD_LIGHT); rim.addColorStop(.35, GOLD); rim.addColorStop(.6, GOLD_DEEP); rim.addColorStop(.85, GOLD); rim.addColorStop(1, GOLD_LIGHT);
      ctx.beginPath(); ctx.arc(cx, cy, 160, 0, Math.PI * 2); ctx.fillStyle = rim; ctx.fill();
      ctx.beginPath(); ctx.arc(cx, cy, 154, 0, Math.PI * 2); ctx.fillStyle = "#2b2670"; ctx.fill();
      for (var bulb = 0; bulb < 30; bulb++) {
        var ba = bulb * Math.PI / 15;
        ctx.beginPath(); ctx.arc(cx + Math.cos(ba) * 148, cy + Math.sin(ba) * 148, bulb % 2 ? 1.4 : 2.2, 0, Math.PI * 2);
        ctx.fillStyle = bulb % 2 ? "rgba(201,169,97,.7)" : GOLD_LIGHT; ctx.fill();
      }
      ctx.save(); ctx.translate(cx, cy); ctx.rotate(angle * Math.PI / 180);
      var segColors = ["#312e81", "#4338ca"];
      for (var i = 0; i < 10; i++) {
        var start = i * Math.PI / 5 - Math.PI / 2 - Math.PI / 10, base = segColors[i % 2];
        var gradient = ctx.createRadialGradient(0, 0, 20, 0, 0, radius);
        gradient.addColorStop(0, "#1b1850"); gradient.addColorStop(.7, base); gradient.addColorStop(1, i % 2 ? "#5b54dc" : "#423e9a");
        ctx.beginPath(); ctx.moveTo(0, 0); ctx.arc(0, 0, radius, start, start + Math.PI / 5); ctx.closePath(); ctx.fillStyle = gradient; ctx.fill();
        ctx.strokeStyle = "rgba(201,169,97,.55)"; ctx.lineWidth = .9; ctx.stroke();
        var dot = start + Math.PI / 10;
        ctx.beginPath(); ctx.arc(Math.cos(start) * (radius - 6), Math.sin(start) * (radius - 6), 2, 0, Math.PI * 2); ctx.fillStyle = GOLD_LIGHT; ctx.fill();
        ctx.save(); ctx.rotate(dot); ctx.translate(98, 0); ctx.rotate(Math.PI / 2);
        ctx.beginPath(); ctx.arc(0, 0, 13, 0, Math.PI * 2); ctx.fillStyle = "rgba(255,255,255,.1)"; ctx.fill();
        ctx.strokeStyle = "rgba(201,169,97,.85)"; ctx.lineWidth = .9; ctx.stroke();
        ctx.fillStyle = "#f8f4ea"; ctx.font = "700 12px system-ui, sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
        ctx.fillText(String(i + 1).padStart(2, "0"), 0, 0);
        ctx.restore();
      }
      ctx.restore();
      ctx.beginPath(); ctx.arc(cx, cy, radius, 0, Math.PI * 2); ctx.strokeStyle = GOLD; ctx.lineWidth = 2; ctx.stroke();
      ctx.beginPath(); ctx.arc(cx, cy, 58, 0, Math.PI * 2); ctx.strokeStyle = "rgba(201,169,97,.6)"; ctx.lineWidth = 1; ctx.stroke();
      var light = ctx.createLinearGradient(65, 65, 270, 270);
      light.addColorStop(0, "rgba(255,255,255,.18)"); light.addColorStop(.5, "rgba(255,255,255,0)"); light.addColorStop(1, "rgba(0,0,0,.14)");
      ctx.beginPath(); ctx.arc(cx, cy, radius, 0, Math.PI * 2); ctx.fillStyle = light; ctx.fill();
    }
    drawWheel(0);
    function updateSpinQuota(quota) {
      if (!quota || typeof quota.remaining !== "number") return;
      spinQuota = quota;
      renderSpinButton();
    }
    function renderSpinButton() {
      if (isSpinning) {
        mainBtn.disabled = true;
        mainBtn.classList.remove("ql-spin-upgrade-btn");
        mainBtn.innerHTML = '<span aria-hidden="true">↻</span> Creating paper…';
        return;
      }
      if (!spinQuota) {
        mainBtn.disabled = courseSelect.disabled;
        mainBtn.classList.remove("ql-spin-upgrade-btn");
        mainBtn.innerHTML = '<span aria-hidden="true">↻</span> Spin the wheel';
        return;
      }
      if (!spinQuota.is_pro) {
        if (spinQuota.remaining > 0) {
          mainBtn.type = "submit";
          mainBtn.disabled = courseSelect.disabled;
          mainBtn.classList.remove("ql-spin-upgrade-btn");
          mainBtn.innerHTML = '<span aria-hidden="true">↻</span> Spin the wheel · 1 free spin left';
        } else {
          mainBtn.type = "button";
          mainBtn.disabled = false;
          mainBtn.classList.add("ql-spin-upgrade-btn");
          mainBtn.innerHTML = '★ Unlock 7 spins/day with Pro';
        }
      } else {
        mainBtn.type = "submit";
        mainBtn.classList.remove("ql-spin-upgrade-btn");
        if (spinQuota.remaining > 0) {
          mainBtn.disabled = courseSelect.disabled;
          mainBtn.innerHTML = '<span aria-hidden="true">↻</span> Spin the wheel · ' + spinQuota.remaining + '/' + spinQuota.limit + ' spins left';
        } else {
          mainBtn.disabled = true;
          mainBtn.innerHTML = '0/' + spinQuota.limit + ' spins left today';
        }
      }
    }
    fetch(runtime.apiBase + "/student/spin-practice/quota", {headers: {Accept: "application/json", Authorization: "Bearer " + runtime.token()}})
      .then(function (res) { if (!res.ok) throw Error("Quota unavailable"); return res.json(); })
      .then(function (data) { if (host.isConnected && !spinQuota && !isSpinning) updateSpinQuota(data.quota); }).catch(function () {});
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
          courseSelect.disabled = !list.length;
          renderSpinButton();
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
      var reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      var finished = false, settling = false, finishAt = null, finishFrom = 0, finishTo = 0, last = performance.now(), started = last;
      var resolveAnimation;
      var completion = new Promise(function (resolve) { resolveAnimation = resolve; });
      function frame(now) {
        if (!host.isConnected) { document.documentElement.classList.remove("ql-spin-focus"); finished = true; resolveAnimation(); return; }
        if (finishAt !== null && now >= finishAt) {
          if (!settling) { settling = true; finishFrom = currentAngle; finishTo = currentAngle + 132; }
          var progress = Math.min(1, Math.max(0, (now - finishAt) / 1100));
          currentAngle = finishFrom + (finishTo - finishFrom) * (1 - Math.pow(1 - progress, 3));
          drawWheel(currentAngle);
          if (progress >= 1) { currentAngle %= 360; finished = true; resolveAnimation(); return; }
        } else {
          var elapsed = Math.min(64, Math.max(0, now - last));
          var speed = 100 + 260 * Math.min(1, (now - started) / 800);
          currentAngle = (currentAngle + elapsed * speed / 1000) % 360;
          drawWheel(currentAngle);
        }
        last = now;
        requestAnimationFrame(frame);
      }
      if (!reduced) requestAnimationFrame(frame);
      return { finish: function () {
        if (reduced || finished) return Promise.resolve();
        if (finishAt === null) { finishAt = Math.max(performance.now(), started + 4000); }
        return completion;
      } };
    }
    function showPaperReady(paper, payload) {
      var dialog = document.createElement("dialog");
      dialog.className = "ql-spin-help-dialog ql-spin-paper-dialog";
      dialog.setAttribute("aria-labelledby", "ql-spin-ready-title");
      dialog.innerHTML = '<div class="ql-spin-help-content"><div class="ql-spin-help-top"><span><img src="/assets/quiz-lab-icon.png" alt="" width="32" height="32">Quiz LAB</span><button type="button" class="ql-spin-help-close" aria-label="Close paper details"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18"/></svg></button></div>' +
        '<p class="ql-spin-ready-eyebrow">Your paper is ready</p><h2 id="ql-spin-ready-title"></h2><dl class="ql-spin-ready-details"><div><dt>Course</dt><dd data-ready-course></dd></div><div><dt>Questions</dt><dd data-ready-count></dd></div><div><dt>Weeks</dt><dd data-ready-weeks></dd></div><div><dt>Paper types</dt><dd data-ready-types></dd></div><div data-ready-quota-row hidden><dt>Spins left today</dt><dd data-ready-quota></dd></div></dl>' +
        '<p class="ql-spin-help-free">Private paper, saved in My Papers. Only you can open it. Choose your time when you start.</p><div class="ql-spin-ready-actions"><a class="ql-spin-main-btn" data-ready-try autofocus>Try now</a><button type="button" class="ql-spin-help-button" data-ready-again>Spin again</button></div></div>';
      dialog.querySelector("#ql-spin-ready-title").textContent = paper.title || "Practice paper";
      dialog.querySelector("[data-ready-course]").textContent = courseSelect.selectedOptions[0].textContent;
      dialog.querySelector("[data-ready-count]").textContent = String(paper.question_count);
      dialog.querySelector("[data-ready-weeks]").textContent = payload.week_min + "–" + payload.week_max;
      dialog.querySelector("[data-ready-types]").textContent = host.querySelector("#ql-spin-type-summary").textContent;
      if (spinQuota) { dialog.querySelector("[data-ready-quota-row]").hidden = false; dialog.querySelector("[data-ready-quota]").textContent = String(spinQuota.remaining); }
      dialog.querySelector("[data-ready-again]").disabled = !!(spinQuota && spinQuota.remaining === 0);
      dialog.querySelector("[data-ready-try]").href = "/paper/" + encodeURIComponent(paper.id);
      dialog.querySelector(".ql-spin-help-close").addEventListener("click", function () { dialog.close(); });
      dialog.querySelector("[data-ready-again]").addEventListener("click", function () { dialog.close(); form.requestSubmit(); });
      dialog.addEventListener("click", function (event) {
        var bounds = dialog.getBoundingClientRect();
        if (event.target === dialog && (event.clientX < bounds.left || event.clientX > bounds.right || event.clientY < bounds.top || event.clientY > bounds.bottom)) dialog.close();
      });
      dialog.addEventListener("close", function () { dialog.remove(); });
      host.appendChild(dialog); dialog.showModal();
    }
    async function spinWheel(event) {
      event.preventDefault();
      if (isSpinning) return;
      if (!courseSelect.value) { courseSelect.reportValidity(); return; }
      var payload = {course_id: Number(courseSelect.value), week_min: Number(weekMinInput.value), week_max: Number(weekMaxInput.value),
        paper_types: types.filter(function (item) { return item.checked; }).map(function (item) { return item.value; }), title: host.querySelector("#ql-spin-name").value.trim()};
      isSpinning = true; settings.disabled = true; mainBtn.disabled = true; host.classList.add("ql-is-spinning");
      document.documentElement.classList.add("ql-spin-focus");
      form.inert = true; host.querySelector("#ql-spin-help").disabled = true;
      if (backBtn) backBtn.style.pointerEvents = "none";
      host.querySelector(".ql-spin-types").open = false;
      mainBtn.textContent = "Creating paper…"; outcome.className = "ql-spin-outcome"; outcome.textContent = "Creating your practice paper…";
      var controller = new AbortController(), timeout = setTimeout(function () { controller.abort(); }, 25000);
      var animation = animateSpin();
      try {
        var request = fetch(runtime.apiBase + "/student/spin-practice", {method: "POST", signal: controller.signal,
          headers: {Accept: "application/json", "Content-Type": "application/json", Authorization: "Bearer " + runtime.token()}, body: JSON.stringify(payload)})
          .then(async function (res) { var paper = await res.json(); updateSpinQuota(paper.quota); if (!res.ok) throw Error(paper.message || paper.error || "Could not create your paper.");
            if (!(Number(paper.id) > 0 && Number(paper.question_count) > 0)) throw Error("The server returned an incomplete paper. Check My Papers before trying again.");
            return paper;
          });
        var paper = await request;
        await animation.finish();
        if (!host.isConnected) return;
        host.classList.remove("ql-is-spinning");
        document.documentElement.classList.remove("ql-spin-focus");
        if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) await new Promise(function (resolve) { setTimeout(resolve, 650); });
        if (!host.isConnected) return;
        outcome.textContent = "Your paper is ready. Saved in My Papers.";
        showPaperReady(paper, payload);
      } catch (error) {
        await animation.finish();
        if (!host.isConnected) return;
        outcome.className = "ql-spin-outcome error";
        outcome.textContent = error.name === "AbortError" ? "The request timed out. Check My Papers before trying again." : (error.message || "Could not create your paper. Please try again.");
      } finally {
        clearTimeout(timeout); isSpinning = false; host.classList.remove("ql-is-spinning");
        document.documentElement.classList.remove("ql-spin-focus"); form.inert = false;
        host.querySelector("#ql-spin-help").disabled = false;
        if (backBtn) backBtn.style.pointerEvents = "";
        if (host.isConnected) { settings.disabled = false; renderSpinButton(); }
      }
    }
    function openProUpgrade(event) {
      if (event) { event.preventDefault(); event.stopPropagation(); }
      if (typeof window.openProPaywall === "function") window.openProPaywall();
      else window.location.assign("/pro");
    }
    mainBtn.addEventListener("click", function (event) {
      if (mainBtn.classList.contains("ql-spin-upgrade-btn") || (spinQuota && !spinQuota.is_pro && spinQuota.remaining === 0)) {
        openProUpgrade(event);
      }
    });
    form.addEventListener("submit", function (event) {
      if (mainBtn.classList.contains("ql-spin-upgrade-btn") || (spinQuota && !spinQuota.is_pro && spinQuota.remaining === 0)) {
        openProUpgrade(event);
        return;
      }
      spinWheel(event);
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
    addIdeTabs(tabs);
  }

  /* Coding questions (GrPA, OPPE 1, OPPE 2 ...) live in the IDE page. Show them as extra tabs after End Term. */
  var ideTypes = null, ideTypesFor = "";
  function addIdeTabs(tabs) {
    var m = window.location.pathname.match(/^\/practice\/([^/]+)/i);
    var runtime = window.QLStorefront;
    if (!m || !runtime || !runtime.token()) return;
    var slug = m[1];
    if (ideTypesFor !== slug) {
      ideTypesFor = slug; ideTypes = null;
      fetch(runtime.apiBase + "/courses/" + encodeURIComponent(slug) + "/ide-problems", { headers: { Accept: "application/json", Authorization: "Bearer " + runtime.token() } })
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (d) {
          if (!d) return;
          var solved = []; try { solved = JSON.parse(localStorage.getItem("ide.solved") || "[]"); } catch (_) {}
          var defs = [["GrPA", /^GrPA/i, "GrPA"], ["OPPE 1", /^OPPE ?1\b/i, "OPPE 1"], ["OPPE 2", /^OPPE ?2\b/i, "OPPE 2"], ["Quiz 1", /^Quiz ?1\b/i, "Quiz 1 Coding"], ["End Term", /^End ?Term/i, "End Term Coding"]];
          var out = defs.map(function (t) { return { type: t[0], label: t[2], total: 0, done: 0 }; });
          (d.weeks || []).forEach(function (w) { (w.problems || []).forEach(function (p) {
            defs.forEach(function (t, i) { if (t[1].test(p.title)) { out[i].total++; if (solved.indexOf(p.id) >= 0) out[i].done++; } });
          }); });
          ideTypes = out.filter(function (t) { return t.total > 0; });
          schedule();
        })
        .catch(function () {});
      return;
    }
    if (!ideTypes) return;
    var anchor = null;
    tabs.querySelectorAll("button:not([data-ql-ide-tab])").forEach(function (b) { if (/^End Term/i.test(b.textContent.trim())) anchor = b; });
    var last = anchor || tabs.lastElementChild;
    ideTypes.forEach(function (t) {
      var existing = tabs.querySelector('[data-ql-ide-tab="' + t.type + '"]');
      if (existing) { last = existing; return; }
      var b = document.createElement("button");
      b.type = "button"; b.setAttribute("data-ql-ide-tab", t.type); b.setAttribute("data-empty", "false");
      b.className = "whitespace-nowrap rounded-lg px-4 py-2 text-sm font-medium transition text-slate-600 hover:text-slate-900";
      b.innerHTML = "<span></span><span class=\"ml-2 inline-flex items-center rounded-full px-1.5 text-[10px] font-semibold bg-slate-100 text-slate-500\"></span>";
      b.firstChild.textContent = t.label; b.lastChild.textContent = t.done + "/" + t.total;
      b.addEventListener("click", function () { window.location.assign("/ide.html?course=" + encodeURIComponent(slug) + "&type=" + encodeURIComponent(t.type)); });
      last.insertAdjacentElement("afterend", b); last = b;
    });
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
    if (dc && /(daily\s*challenge|spin\s*(&|and)?\s*win|daily\s*rewards)/i.test(dc.textContent || "")) {
      e.preventDefault();
      e.stopPropagation();
      var rewardsNav = document.querySelector('a[href="/rewards"]');
      if (rewardsNav && rewardsNav !== dc) {
        rewardsNav.click();
      } else {
        location.assign("/rewards");
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
   * Phone top bar: the level chip is gone and the Spin & Win button
   * sits in its place, linking directly to /rewards.
   * Also hides the welcome streak pill on phone screens.
   * ------------------------------------------------------------- */
  function syncPhoneTopBar() {
    // Hide the welcome streak pill under "Welcome back, ..." on mobile view
    document.querySelectorAll("#root div.rounded-full").forEach(function (pill) {
      if (pill.closest("header")) return;
      if (/^\d+-day\s+streak$/i.test(pill.textContent.trim())) {
        tag(pill, "data-ql-streak-src", "");
        if (window.innerWidth < 1024) {
          pill.style.setProperty("display", "none", "important");
        } else {
          pill.style.removeProperty("display");
        }
      }
    });

    var header = document.querySelector("header.lg\\:hidden");
    if (!header) return;

    header.querySelectorAll(".rounded-full.tracking-wide").forEach(function (chip) {
      if (/^LVL\s*\d+$/.test(chip.textContent.trim())) tag(chip, "data-ql-lvl", "");
    });
    header.querySelectorAll('a[href*="/profile"]').forEach(function (link) {
      link.style.setProperty("display", "none", "important");
    });

    var oldStreak = header.querySelector(".ql-top-streak");
    if (oldStreak) oldStreak.remove();

    var rightGroup = header.querySelector(".flex.items-center.gap-2") || header.lastElementChild;
    var avatarMenu = rightGroup ? rightGroup.querySelector('.relative, button[aria-label="Account menu"]') : null;

    var slot = header.querySelector(".ql-top-spin-btn");
    if (!slot) {
      slot = document.createElement("a");
      slot.className = "ql-top-spin-btn";
      slot.href = "/rewards";
      slot.setAttribute("role", "button");
      slot.setAttribute("aria-label", "Spin & Win Daily Rewards");
      slot.addEventListener("click", function (e) {
        e.preventDefault();
        var nav = document.querySelector('nav a[href*="rewards"], nav button[data-ql-rewards]');
        if (nav) nav.click();
        else location.assign("/rewards");
      });
      if (rightGroup) {
        if (avatarMenu) rightGroup.insertBefore(slot, avatarMenu);
        else rightGroup.appendChild(slot);
      }
    } else if (rightGroup && slot.parentNode !== rightGroup) {
      if (avatarMenu) rightGroup.insertBefore(slot, avatarMenu);
      else rightGroup.appendChild(slot);
    }

    if (slot) {
      slot.style.cssText =
        "display:inline-flex!important;flex-direction:row!important;align-items:center!important;gap:4px!important;white-space:nowrap!important;flex-shrink:0!important;border:1px solid rgba(79,70,229,0.25)!important;background:rgba(79,70,229,0.08)!important;color:#4f46e5!important;border-radius:999px!important;padding:3px 8px!important;font-size:11px!important;font-weight:750!important;line-height:1!important;text-decoration:none!important;cursor:pointer;";
      slot.innerHTML =
        '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block!important;flex-shrink:0!important;vertical-align:middle!important"><circle cx="12" cy="12" r="10"/><path d="m4.93 4.93 4.24 4.24"/><path d="m14.83 9.17 4.24-4.24"/><path d="m14.83 14.83 4.24 4.24"/><path d="m9.17 14.83-4.24 4.24"/><circle cx="12" cy="12" r="3"/></svg>' +
        '<span style="white-space:nowrap!important;font-size:11px!important;font-weight:750!important;letter-spacing:-0.2px!important;display:inline!important;line-height:1!important">Spin &amp; Win</span>';
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


  /* ---------------------------------------------------------------
   * Daily Rewards: Lucky Wheel, Scratch Card & Collected Rewards
   * Lets every user spin once daily to win discount coupons, 30-day Free
   * Pro, paid papers, or study XP. Includes interactive scratch card,
   * 7-day coupon expiry engine, and daily prompt modal.
   * ------------------------------------------------------------- */
  function getPrizeSvgIcon(type) {
    switch (type) {
      case "free_pro":
        return '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m2 4 3 12h14l3-12-6 7-4-7-4 7-6-7zm3 16h14"/></svg>';
      case "coupon_pct":
      case "coupon_flat":
        return '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 9a3 3 0 0 1 0 6v2a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-2a3 3 0 0 1 0-6V7a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2Z"/><path d="M13 5v2"/><path d="M13 11v2"/><path d="M13 17v2"/></svg>';
      case "bonus_xp":
        return '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/></svg>';
      case "free_spin":
        return '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/></svg>';
      case "free_test":
        return '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><path d="m9 15 2 2 4-4"/></svg>';
      case "free_paper_upload":
        return '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>';
      case "try_again":
      default:
        return '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="7" r="4"/><circle cx="7" cy="12" r="4"/><circle cx="17" cy="12" r="4"/><circle cx="12" cy="17" r="4"/><path d="M12 12v9"/></svg>';
    }
  }

  var WHEEL_PRIZES = [
    { title: "UPTO ₹50 OFF", sub: "5% Discount", color: "#4f46e5", type: "coupon_pct", value: "5% OFF (Upto ₹50)", prefix: "GENZ5-" },
    { title: "30D FREE PRO", sub: "Jackpot", color: "#d97706", type: "free_pro", value: "30 Days Pro", prefix: "" },
    { title: "₹50 OFF", sub: "Coupon", color: "#059669", type: "coupon_flat", value: "₹50 OFF", prefix: "GENZ50-" },
    { title: "BETTER LUCK", sub: "Tomorrow", color: "#64748b", type: "try_again", value: "Try Tomorrow", prefix: "" },
    { title: "25% OFF", sub: "Mega Deal", color: "#7c3aed", type: "coupon_pct", value: "25% OFF", prefix: "GENZ25-" },
    { title: "FREE SPIN", sub: "Extra Spin", color: "#0284c7", type: "free_spin", value: "1 Free Spin", prefix: "" },
    { title: "₹100 OFF", sub: "Discount", color: "#db2777", type: "coupon_flat", value: "₹100 OFF", prefix: "GENZ100-" },
    { title: "+50 XP", sub: "Study Boost", color: "#2563eb", type: "bonus_xp", value: "50 XP", prefix: "" },
    { title: "TEST FREE", sub: "1 Test Pass", color: "#0d9488", type: "free_test", value: "1 Free Test Yourself", prefix: "" },
    { title: "FREE UPLOAD", sub: "Paper Pass", color: "#ea580c", type: "free_paper_upload", value: "1 Free Paper Upload", prefix: "" }
  ];
  var weights = [18, 8, 10, 9, 8, 10, 5, 12, 10, 10];

  function getTodayISTString() {
    try {
      return new Date().toLocaleDateString("en-CA", { timeZone: "Asia/Kolkata" });
    } catch (_) {
      var d = new Date();
      var utc = d.getTime() + (d.getTimezoneOffset() * 60000);
      var ist = new Date(utc + (3600000 * 5.5));
      return ist.toISOString().slice(0, 10);
    }
  }

  function getMidnightISTRemaining() {
    var now = new Date();
    var utc = now.getTime() + (now.getTimezoneOffset() * 60000);
    var ist = new Date(utc + (3600000 * 5.5));
    var midnight = new Date(ist);
    midnight.setHours(24, 0, 0, 0);
    var diff = Math.max(0, midnight.getTime() - ist.getTime());
    var h = Math.floor(diff / 3600000);
    var m = Math.floor((diff % 3600000) / 60000);
    var s = Math.floor((diff % 60000) / 1000);
    return { diff: diff, hours: h, minutes: m, seconds: s, text: h + "h " + m + "m " + s + "s" };
  }

  try {
    localStorage.removeItem("ql_rewards_global_log");
    for (var lk in localStorage) {
      if (lk && lk.indexOf("ql_rewards_v2_") === 0) {
        localStorage.removeItem(lk);
      }
    }
  } catch (_) {}

  var rewardAudioCtx = null;
  function getRewardAudioCtx() {
    if (!rewardAudioCtx && typeof window.AudioContext !== "undefined") {
      rewardAudioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (rewardAudioCtx && rewardAudioCtx.state === "suspended") {
      rewardAudioCtx.resume();
    }
    return rewardAudioCtx;
  }

  function playWheelTickSound() {
    try {
      var ctx = getRewardAudioCtx();
      if (!ctx) return;
      var osc = ctx.createOscillator();
      var gain = ctx.createGain();
      osc.type = "sine";
      osc.frequency.setValueAtTime(560, ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(220, ctx.currentTime + 0.035);
      gain.gain.setValueAtTime(0.09, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.035);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.035);
    } catch (_) {}
  }

  function playWheelWinSound() {
    try {
      var ctx = getRewardAudioCtx();
      if (!ctx) return;
      var notes = [523.25, 659.25, 783.99, 1046.50]; // C5, E5, G5, C6
      notes.forEach(function (freq, i) {
        var osc = ctx.createOscillator();
        var gain = ctx.createGain();
        osc.type = "triangle";
        osc.frequency.setValueAtTime(freq, ctx.currentTime + i * 0.08);
        gain.gain.setValueAtTime(0.12, ctx.currentTime + i * 0.08);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + i * 0.08 + 0.28);
        osc.connect(gain);
        gain.connect(ctx.destination);
        osc.start(ctx.currentTime + i * 0.08);
        osc.stop(ctx.currentTime + i * 0.08 + 0.28);
      });
    } catch (_) {}
  }

  function fireConfettiBurst() {
    var c = document.createElement("canvas");
    c.style.cssText = "position:fixed;inset:0;width:100vw;height:100vh;pointer-events:none;z-index:100001";
    document.body.appendChild(c);
    var ctx = c.getContext("2d");
    var w = c.width = window.innerWidth;
    var h = c.height = window.innerHeight;
    var colors = ["#4F46E5", "#10B981", "#F59E0B", "#EF4444", "#EC4899", "#8B5CF6", "#06B6D4", "#FDE047"];
    var particles = [];
    for (var i = 0; i < 90; i++) {
      particles.push({
        x: w * 0.5 + (Math.random() - 0.5) * 60,
        y: h * 0.45,
        vx: (Math.random() - 0.5) * 14,
        vy: -Math.random() * 12 - 4,
        size: Math.random() * 8 + 5,
        color: colors[Math.floor(Math.random() * colors.length)],
        rotation: Math.random() * 360,
        rotationSpeed: (Math.random() - 0.5) * 14,
        gravity: 0.35,
        opacity: 1
      });
    }
    var start = Date.now();
    function animate() {
      ctx.clearRect(0, 0, w, h);
      var elapsed = Date.now() - start;
      if (elapsed > 3200) { c.remove(); return; }
      particles.forEach(function (p) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += p.gravity;
        p.rotation += p.rotationSpeed;
        if (elapsed > 2000) p.opacity = Math.max(0, 1 - (elapsed - 2000) / 1200);
        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate((p.rotation * Math.PI) / 180);
        ctx.fillStyle = p.color;
        ctx.globalAlpha = p.opacity;
        ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.6);
        ctx.restore();
      });
      requestAnimationFrame(animate);
    }
    requestAnimationFrame(animate);
  }

  function syncRewardsButton() {
    document.querySelectorAll('header a, header button, nav a').forEach(function (btn) {
      if (/(daily\s*challenge|spin\s*(&|and)?\s*win|daily\s*rewards)/i.test(btn.textContent || "")) {
        if (btn.tagName === "A" && btn.getAttribute("href") !== "/rewards") {
          btn.setAttribute("href", "/rewards");
        }
        btn.setAttribute("data-ql-rewards-btn", "1");
        var svg = btn.querySelector("svg");
        if (svg) {
          if (btn.lastChild && btn.lastChild.nodeType === Node.TEXT_NODE) {
            btn.lastChild.textContent = "Spin & Win";
          } else {
            btn.replaceChildren(svg, document.createTextNode("Spin & Win"));
          }
        } else if (!btn.querySelector(".ql-rewards-label")) {
          btn.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:-2px"><circle cx="12" cy="12" r="10"/><path d="m4.93 4.93 4.24 4.24"/><path d="m14.83 9.17 4.24-4.24"/><path d="m14.83 14.83 4.24 4.24"/><path d="m9.17 14.83-4.24 4.24"/><circle cx="12" cy="12" r="3"/></svg> Spin & Win';
        }
      }
    });
  }

  function openScratchCardModal(reward, onScratchDone) {
    var overlay = document.createElement("div");
    overlay.className = "ql-scratch-overlay";
    var isInApp = reward.type === "free_test" || reward.type === "free_paper_upload" || reward.type === "free_pro";
    var modalHeadTitle = isInApp ? "You Won a Bonus Reward!" : "You Won a Reward Coupon!";
    var modalHeadSub = isInApp ? "Scratch with your mouse or finger to reveal your reward" : "Scratch with your mouse or finger to reveal your secret code";
    var copyIcon = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>';

    var secretSubHtml = "";
    if (reward.type === "free_test") {
      secretSubHtml = '<div class="ql-scratch-code" style="font-size:15px;letter-spacing:0.5px;color:#16a34a">✓ ADDED TO ACCOUNT</div>' +
                      '<div class="ql-scratch-expiry-note">Ready to use in Test Yourself immediately</div>';
    } else if (reward.type === "free_paper_upload") {
      secretSubHtml = '<div class="ql-scratch-code" style="font-size:15px;letter-spacing:0.5px;color:#16a34a">✓ ADDED TO ACCOUNT</div>' +
                      '<div class="ql-scratch-expiry-note">Ready to use in Upload Paper immediately</div>';
    } else if (reward.type === "free_pro") {
      secretSubHtml = '<div class="ql-scratch-code" style="font-size:15px;letter-spacing:0.5px;color:#b45309">👑 30 DAYS PRO</div>' +
                      '<div class="ql-scratch-expiry-note">Ready to activate on your account</div>';
    } else {
      secretSubHtml = '<div class="ql-scratch-code-row"><div class="ql-scratch-code" id="ql-scratch-secret-code">' + escapeHtml(reward.code || "") + '</div>' +
                      '<button type="button" class="ql-copy-code-btn" id="ql-scratch-copy-btn" aria-label="Copy coupon code" title="Copy coupon code" style="display:none">' + copyIcon + '</button></div>' +
                      '<div class="ql-scratch-expiry-note">Valid for 7 days only · Expires if unused</div>';
    }

    var actionsHtml = "";
    if (reward.type === "free_test") {
      actionsHtml =
        '<div class="ql-claim-steps-card">' +
          '<div style="display:flex;align-items:center;gap:12px;margin-bottom:10px">' +
            '<div style="width:38px;height:38px;border-radius:50%;background:#dcfce7;color:#16a34a;display:grid;place-items:center;flex-shrink:0">' +
              '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>' +
            '</div>' +
            '<div>' +
              '<strong style="display:block;font-size:15px;color:#0f172a">1 Free Practice Test Credited!</strong>' +
              '<span style="font-size:12px;color:#64748b">Added directly to your balance · No coupon code needed</span>' +
            '</div>' +
          '</div>' +
          '<a href="/try-practice" class="ql-visit-courses-cta" style="background:#4f46e5;color:#fff;text-decoration:none;display:inline-flex;align-items:center;justify-content:center;gap:6px;padding:12px 18px;border-radius:8px;font-weight:700;font-size:14px;width:100%">Test Yourself Now →</a>' +
          '<button type="button" class="ql-scratch-done-btn" id="ql-scratch-done-btn">✕ Close</button>' +
        '</div>';
    } else if (reward.type === "free_paper_upload") {
      actionsHtml =
        '<div class="ql-claim-steps-card">' +
          '<div style="display:flex;align-items:center;gap:12px;margin-bottom:10px">' +
            '<div style="width:38px;height:38px;border-radius:50%;background:#dcfce7;color:#16a34a;display:grid;place-items:center;flex-shrink:0">' +
              '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg>' +
            '</div>' +
            '<div>' +
              '<strong style="display:block;font-size:15px;color:#0f172a">1 Free Paper Upload Credited!</strong>' +
              '<span style="font-size:12px;color:#64748b">Added directly to your balance · No coupon code needed</span>' +
            '</div>' +
          '</div>' +
          '<a href="/upload-paper" class="ql-visit-courses-cta" style="background:#4f46e5;color:#fff;text-decoration:none;display:inline-flex;align-items:center;justify-content:center;gap:6px;padding:12px 18px;border-radius:8px;font-weight:700;font-size:14px;width:100%">Upload a Paper Now →</a>' +
          '<button type="button" class="ql-scratch-done-btn" id="ql-scratch-done-btn">✕ Close</button>' +
        '</div>';
    } else if (reward.type === "free_pro") {
      actionsHtml =
        '<div class="ql-claim-steps-card pro">' +
          '<strong class="ql-claim-steps-title" style="color:#92400e">Claim Your 30 Days Free Pro:</strong>' +
          '<p style="font-size:13px;color:#475569;margin:6px 0 12px">Click below to activate 30 full days of Quiz LAB Pro on your account.</p>' +
          '<button type="button" class="ql-claim-pro-btn" id="ql-scratch-claim-pro-btn" style="padding:12px 18px;font-weight:700;font-size:14px;width:100%">Activate 30 Days Free Pro Now →</button>' +
          '<button type="button" class="ql-scratch-done-btn" id="ql-scratch-done-btn">✕ Close &amp; Claim Later</button>' +
        '</div>';
    } else {
      actionsHtml =
        '<div class="ql-claim-steps-card">' +
          '<div class="ql-coupon-claim-header"><strong class="ql-claim-steps-title">How to Claim Your Coupon:</strong>' +
            '<button type="button" class="ql-card-terms-toggle" id="ql-scratch-claim-toggle" aria-expanded="false" aria-controls="ql-scratch-claim-details">View</button></div>' +
          '<div class="ql-card-claim-details" id="ql-scratch-claim-details" style="display:none">' +
          '<ol class="ql-claim-steps-list">' +
            '<li><strong>Visit:</strong> <a href="https://genziitian.in/courses" target="_blank" rel="noopener noreferrer">Genziitian.in/courses</a></li>' +
            '<li><strong>Choose:</strong> Pick any course of your choice</li>' +
            '<li><strong>Apply Code:</strong> Apply your coupon code at checkout.</li>' +
          '</ol>' +
          '<div class="ql-claim-terms-box">' +
            '<div class="ql-claim-term-row"><strong>Applicability:</strong> Valid only on <a href="https://genziitian.in/courses" target="_blank" rel="noopener noreferrer">Genziitian.in/courses</a>.</div>' +
            '<div class="ql-claim-term-row"><strong>7-Day Expiry:</strong> Auto-disables in 7 days counting from day scratched or spinned.</div>' +
            '<div class="ql-claim-term-row"><strong>No Payment:</strong> No payment required to get this coupon.</div>' +
            '<div class="ql-claim-term-row"><strong>Minimum Purchase:</strong> Minimum order amount is ₹350.</div>' +
            '<div class="ql-claim-term-row"><strong>Discount Cap:</strong> Max discount on any percentage is ₹100.</div>' +
            '<div class="ql-claim-term-row"><strong>Terms Agreement:</strong> By continuing you accept all our <a href="/terms.html#rewards-promotions" target="_blank">terms, conditions and rules</a>.</div>' +
          '</div>' +
          '</div>' +
          '<div class="ql-coupon-actions"><a href="https://genziitian.in/courses" target="_blank" rel="noopener noreferrer" class="ql-visit-courses-cta">Redeem</a>' +
          '<button type="button" class="ql-scratch-done-btn" id="ql-scratch-done-btn">Close</button></div>' +
        '</div>';
    }

    overlay.innerHTML =
      '<div class="ql-scratch-dialog" role="dialog" aria-modal="true">' +
        '<button type="button" class="ql-scratch-dialog-close" aria-label="Close">✕</button>' +
        '<div class="ql-scratch-dialog-head">' +
          '<h2>' + escapeHtml(modalHeadTitle) + '</h2>' +
          '<p>' + escapeHtml(modalHeadSub) + '</p>' +
        '</div>' +
        '<div class="ql-scratch-card-body">' +
          '<div class="ql-scratch-stage">' +
            '<div class="ql-scratch-secret' + (reward.type === "free_pro" ? " pro" : "") + '">' +
              '<div class="ql-scratch-val">' + escapeHtml(reward.title) + '</div>' +
              secretSubHtml +
            '</div>' +
            '<canvas class="ql-scratch-canvas" width="380" height="180"></canvas>' +
          '</div>' +
          '<div class="ql-scratch-actions" id="ql-scratch-actions" style="display:none">' +
            actionsHtml +
          '</div>' +
        '</div>' +
      '</div>';
    document.body.appendChild(overlay);

    var canvas = overlay.querySelector(".ql-scratch-canvas");
    var ctx = canvas.getContext("2d");
    var copyBtn = overlay.querySelector("#ql-scratch-copy-btn");
    var closeBtn = overlay.querySelector(".ql-scratch-dialog-close");
    var claimToggle = overlay.querySelector("#ql-scratch-claim-toggle");
    var claimDetails = overlay.querySelector("#ql-scratch-claim-details");
    if (claimToggle && claimDetails) {
      claimToggle.addEventListener("click", function () {
        var expanded = claimToggle.getAttribute("aria-expanded") !== "true";
        claimToggle.setAttribute("aria-expanded", String(expanded));
        claimToggle.textContent = expanded ? "Hide" : "View";
        claimDetails.style.display = expanded ? "block" : "none";
      });
    }

    function paintFoil() {
      var w = canvas.width;
      var h = canvas.height;
      var grad = ctx.createLinearGradient(0, 0, w, h);
      grad.addColorStop(0, "#cbd5e1");
      grad.addColorStop(0.25, "#f1f5f9");
      grad.addColorStop(0.5, "#94a3b8");
      grad.addColorStop(0.75, "#cbd5e1");
      grad.addColorStop(1, "#64748b");
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, w, h);

      ctx.fillStyle = "rgba(255, 255, 255, 0.22)";
      for (var y = 0; y < h; y += 8) {
        ctx.fillRect(0, y, w, 2);
      }

      ctx.fillStyle = "#1e293b";
      ctx.font = "bold 15px sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("SCRATCH HERE TO REVEAL", w / 2, h / 2 - 10);
      ctx.font = "12px sans-serif";
      ctx.fillStyle = "#475569";
      ctx.fillText("Drag mouse or swipe finger", w / 2, h / 2 + 14);
    }
    paintFoil();
    if (reward.is_scratched) {
      setTimeout(autoReveal, 10);
    }

    var isScratching = false;
    var isRevealed = false;
    var scratchCount = 0;

    function scratchAt(clientX, clientY) {
      if (isRevealed) return;
      var rect = canvas.getBoundingClientRect();
      var x = (clientX - rect.left) * (canvas.width / rect.width);
      var y = (clientY - rect.top) * (canvas.height / rect.height);
      ctx.globalCompositeOperation = "destination-out";
      ctx.beginPath();
      ctx.arc(x, y, 22, 0, Math.PI * 2);
      ctx.fill();

      scratchCount++;
      if (scratchCount % 8 === 0) {
        checkClearedPercent();
      }
    }

    function checkClearedPercent() {
      if (isRevealed) return;
      try {
        var imgData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        var pixels = imgData.data;
        var transparentCount = 0;
        var step = 16;
        var total = pixels.length / (4 * step);
        for (var i = 3; i < pixels.length; i += 4 * step) {
          if (pixels[i] < 128) transparentCount++;
        }
        var ratio = transparentCount / total;
        if (ratio > 0.38) {
          autoReveal();
        }
      } catch (_) {}
    }

    function autoReveal() {
      if (isRevealed) return;
      isRevealed = true;
      canvas.style.pointerEvents = "none";
      canvas.style.opacity = "0";
      setTimeout(function () { if (canvas.isConnected) canvas.remove(); }, 350);
      var actionsEl = overlay.querySelector("#ql-scratch-actions");
      if (actionsEl) actionsEl.style.display = "flex";
      if (copyBtn) copyBtn.style.display = "flex";
      reward.is_scratched = true;
      playWheelWinSound();
      fireConfettiBurst();
      if (typeof onScratchDone === "function") onScratchDone(reward);
    }

    canvas.addEventListener("mousedown", function (e) { isScratching = true; scratchAt(e.clientX, e.clientY); });
    window.addEventListener("mousemove", function (e) { if (isScratching) scratchAt(e.clientX, e.clientY); });
    window.addEventListener("mouseup", function () { isScratching = false; });

    canvas.addEventListener("touchstart", function (e) {
      isScratching = true;
      if (e.touches[0]) scratchAt(e.touches[0].clientX, e.touches[0].clientY);
    }, { passive: false });
    canvas.addEventListener("touchmove", function (e) {
      if (!isScratching) return;
      e.preventDefault();
      if (e.touches[0]) scratchAt(e.touches[0].clientX, e.touches[0].clientY);
    }, { passive: false });
    window.addEventListener("touchend", function () { isScratching = false; });

    if (copyBtn) {
      copyBtn.addEventListener("click", function () {
        if (!reward.code) return;
        navigator.clipboard.writeText(reward.code).then(function () {
          copyBtn.innerHTML = '<span aria-hidden="true">✓</span>';
          copyBtn.setAttribute("aria-label", "Coupon code copied");
          copyBtn.title = "Copied!";
          setTimeout(function () {
            copyBtn.innerHTML = copyIcon;
            copyBtn.setAttribute("aria-label", "Copy coupon code");
            copyBtn.title = "Copy coupon code";
          }, 2200);
        });
      });
    }

    var scratchClaimPro = overlay.querySelector("#ql-scratch-claim-pro-btn");
    if (scratchClaimPro) {
      scratchClaimPro.addEventListener("click", function () {
        scratchClaimPro.disabled = true;
        scratchClaimPro.textContent = "Activating Pro...";
        claimProMembership(reward, function () {
          scratchClaimPro.textContent = "✓ 30 Days Pro Activated!";
          setTimeout(close, 1200);
        });
      });
    }

    function close() {
      window.removeEventListener("keydown", onKeyDown);
      if (overlay.isConnected) overlay.remove();
    }
    function onKeyDown(e) {
      if (e.key === "Escape") close();
    }
    window.addEventListener("keydown", onKeyDown);

    closeBtn.addEventListener("click", close);
    overlay.addEventListener("click", function (e) { if (e.target === overlay) close(); });
    var doneBtn = overlay.querySelector("#ql-scratch-done-btn");
    if (doneBtn) doneBtn.addEventListener("click", close);
  }

  function openProJackpotModal(reward, onClaimDone) {
    var overlay = document.createElement("div");
    overlay.className = "ql-scratch-overlay";
    overlay.innerHTML =
      '<div class="ql-scratch-dialog" role="dialog" aria-modal="true">' +
        '<button type="button" class="ql-scratch-dialog-close" aria-label="Close">✕</button>' +
        '<div class="ql-scratch-dialog-head" style="background:linear-gradient(135deg,#78350f,#b45309,#d97706)">' +
          '<div style="width:54px;height:54px;border-radius:50%;background:rgba(255,255,255,0.2);display:grid;place-items:center;margin:0 auto 10px;color:#fff"><svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 4l3 12h14l3-12-6 7-4-7-4 7-6-7zm3 16h14"/></svg></div>' +
          '<h2>JACKPOT! 30 Days Free Pro!</h2>' +
          '<p>You won 1 full month of complimentary Quiz LAB Pro membership!</p>' +
        '</div>' +
        '<div class="ql-scratch-card-body">' +
          '<div class="ql-claim-steps-card pro">' +
            '<strong class="ql-claim-steps-title" style="color:#92400e">How to Claim Your 30 Days Free Pro Plan:</strong>' +
            '<ol class="ql-claim-steps-list">' +
              '<li><strong>Click to Claim:</strong> Click the <strong>Claim 30 Days Free Pro Now</strong> button below.</li>' +
              '<li><strong>Instant Activation:</strong> 30 consecutive days of Quiz LAB Pro membership are automatically credited to your student account.</li>' +
              '<li><strong>Enjoy Benefits:</strong> Unlimited practice spins, private paper creation, offline tests, and pro discussions.</li>' +
            '</ol>' +
            '<div class="ql-claim-terms-box">' +
              '<div class="ql-claim-term-row"><strong>Zero Payment:</strong> No payment, credit card, or billing info required. 100% free daily reward.</div>' +
              '<div class="ql-claim-term-row"><strong>Duration:</strong> Valid for exactly 30 consecutive calendar days from activation.</div>' +
              '<div class="ql-claim-term-row"><strong>No Auto-Renewal:</strong> Auto-expires cleanly after 30 days — no hidden charges or recurring bills.</div>' +
              '<div class="ql-claim-term-row"><strong>Account Bound:</strong> Non-transferable; tied directly to your logged-in student account.</div>' +
              '<div class="ql-claim-term-row"><strong>Terms Agreement:</strong> By continuing you accept all our <a href="/terms.html#rewards-promotions" target="_blank">terms, conditions and rules</a>.</div>' +
            '</div>' +
          '</div>' +
          '<div class="ql-scratch-actions">' +
            '<button type="button" class="ql-claim-pro-btn" id="ql-jackpot-claim-cta">' +
              '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:-3px"><path d="M2 4l3 12h14l3-12-6 7-4-7-4 7-6-7zm3 16h14"/></svg> Claim 30 Days Free Pro Now' +
            '</button>' +
            '<button type="button" class="ql-scratch-done-btn" id="ql-jackpot-done-btn">✕ Close &amp; Claim Later</button>' +
          '</div>' +
        '</div>' +
      '</div>';
    document.body.appendChild(overlay);

    var closeBtn = overlay.querySelector(".ql-scratch-dialog-close");
    var jackpotDoneBtn = overlay.querySelector("#ql-jackpot-done-btn");
    function close() {
      window.removeEventListener("keydown", onKeyDown);
      if (overlay.isConnected) overlay.remove();
    }
    function onKeyDown(e) {
      if (e.key === "Escape") close();
    }
    window.addEventListener("keydown", onKeyDown);

    closeBtn.addEventListener("click", close);
    if (jackpotDoneBtn) jackpotDoneBtn.addEventListener("click", close);
    overlay.addEventListener("click", function (e) { if (e.target === overlay) close(); });

    overlay.querySelector("#ql-jackpot-claim-cta").addEventListener("click", function () {
      claimProMembership(reward, function () {
        overlay.querySelector(".ql-scratch-card-body").innerHTML =
          '<div style="text-align:center;padding:16px 0"><div style="width:52px;height:52px;border-radius:50%;background:#dcfce7;color:#16a34a;display:grid;place-items:center;margin:0 auto 10px"><svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6L9 17l-5-5"/></svg></div><strong style="display:block;font-size:18px;color:#15803d;margin-top:8px">Pro Plan Activated!</strong><p style="font-size:13px;color:#64748b;margin:6px 0 16px">Your account has been granted 30 days of Pro access.</p><button type="button" class="ql-copy-code-btn" id="ql-pro-ok-btn">Awesome!</button></div>';
        overlay.querySelector("#ql-pro-ok-btn").addEventListener("click", close);
        playWheelWinSound();
        fireConfettiBurst();
        if (typeof onClaimDone === "function") onClaimDone();
      });
    });
  }

  function claimProMembership(reward, onDone) {
    var runtime = window.QLStorefront || {};
    var tok = runtime.token ? runtime.token() : (localStorage.getItem("lab_token") || "");
    var apiBase = runtime.apiBase || "https://labapi.genziitian.in/public/api";

    function updateLocalPro() {
      try {
        var user = JSON.parse(localStorage.getItem("lab_user") || "{}");
        user.is_pro = true;
        var until = new Date(Date.now() + 30 * 86400 * 1000).toISOString();
        user.pro_expires_at = until;
        localStorage.setItem("lab_user", JSON.stringify(user));
      } catch (_) {}
    }

    function finishClaim() {
      updateLocalPro();
      reward.is_claimed = true;
      if (typeof onDone === "function") onDone();
    }

    if (tok) {
      fetch(apiBase + "/student/rewards/claim-pro", {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer " + tok
        },
        body: JSON.stringify({ id: reward ? reward.id : "" })
      }).then(function (res) {
        return res.json().catch(function () { return {}; });
      }).then(function () {
        finishClaim();
      }).catch(function () {
        finishClaim();
      });
    } else {
      finishClaim();
    }
  }

  function formatRewardCard(reward, nowTime, onScratchClick, onClaimProClick) {
    var isExpired = reward.expires_at ? nowTime > new Date(reward.expires_at).getTime() : false;
    var isScratched = Boolean(reward.is_scratched);
    var isPro = reward.type === "free_pro";
    var isClaimed = Boolean(reward.is_claimed);
    var isInApp = reward.type === "free_test" || reward.type === "free_paper_upload";

    var card = document.createElement("div");
    card.className = "ql-user-reward-card" + (isExpired ? " expired" : "") + (isPro ? " pro" : "");

    var statusHtml = "";
    if (isPro) {
      statusHtml = isClaimed ? '<span class="ql-tag-claimed">Pro Claimed</span>' : '<span class="ql-tag-unscratched">Unclaimed Pro</span>';
    } else if (isInApp) {
      statusHtml = '<span class="ql-tag-claimed">Credited to Account</span>';
    } else if (isExpired) {
      statusHtml = isScratched ? '<span class="ql-tag-expired">Outdated · Expired</span>' : '<span class="ql-tag-expired">Expired · Unscratched</span>';
    } else if (isScratched) {
      statusHtml = '<span class="ql-tag-active">Active · 7d limit</span>';
    } else {
      statusHtml = '<span class="ql-tag-unscratched">Unscratched</span>';
    }

    var codeRowHtml = "";
    if (isPro) {
      if (isClaimed) {
        codeRowHtml = '<div class="ql-card-code-row"><span>Status</span><strong>Active (30-day Access)</strong></div>';
      } else {
        codeRowHtml = '<button type="button" class="ql-claim-pro-btn" style="padding:10px 14px;font-size:13px">Claim 30 Days Free Pro</button>';
      }
    } else if (isInApp) {
      if (!isScratched) {
        codeRowHtml = '<button type="button" class="ql-copy-code-btn" style="padding:10px 14px;font-size:13px;background:#4f46e5">Scratch to Reveal</button>';
      } else if (reward.type === "free_test") {
        codeRowHtml =
          '<div class="ql-card-code-row" style="display:flex;align-items:center;justify-content:space-between;gap:8px">' +
            '<span style="font-size:13px;font-weight:600;color:#16a34a">✓ Ready to use</span>' +
            '<a href="/try-practice" class="ql-card-copy-btn" style="background:#4f46e5;color:#fff;text-decoration:none;display:inline-flex;align-items:center;padding:7px 12px;border-radius:6px;font-size:12px;font-weight:700">Test Yourself Now →</a>' +
          '</div>';
      } else {
        codeRowHtml =
          '<div class="ql-card-code-row" style="display:flex;align-items:center;justify-content:space-between;gap:8px">' +
            '<span style="font-size:13px;font-weight:600;color:#16a34a">✓ Ready to use</span>' +
            '<a href="/upload-paper" class="ql-card-copy-btn" style="background:#4f46e5;color:#fff;text-decoration:none;display:inline-flex;align-items:center;padding:7px 12px;border-radius:6px;font-size:12px;font-weight:700">Upload Paper Now →</a>' +
          '</div>';
      }
    } else if (isExpired) {
      codeRowHtml = '<div class="ql-card-code-row"><span class="ql-card-code-masked">••••••••</span><span style="font-size:11px;color:#94a3b8">Code hidden (expired)</span></div>';
    } else if (isScratched) {
      codeRowHtml =
        '<div class="ql-card-code-row">' +
          '<span class="ql-card-code-text">' + escapeHtml(reward.code || "") + '</span>' +
          '<button type="button" class="ql-card-copy-btn">Copy</button>' +
        '</div>';
    } else {
      codeRowHtml = '<button type="button" class="ql-copy-code-btn" style="padding:10px 14px;font-size:13px;background:#4f46e5">Scratch to Reveal</button>';
    }

    var expiryText = "";
    if (isInApp) {
      expiryText = "Credited to Account";
    } else if (reward.expires_at) {
      if (isExpired) {
        expiryText = "Expired after 7 days";
      } else {
        var diff = Math.max(0, new Date(reward.expires_at).getTime() - nowTime);
        var daysLeft = Math.floor(diff / (86400 * 1000));
        var hoursLeft = Math.floor((diff % (86400 * 1000)) / (3600 * 1000));
        expiryText = "Expires in " + daysLeft + "d " + hoursLeft + "h";
      }
    } else if (isPro) {
      expiryText = isClaimed ? "30 Days Access Active" : "Click to activate 30 days";
    } else {
      expiryText = "Claimed";
    }

    card.innerHTML =
      '<div class="ql-card-top-row">' +
        '<div class="ql-card-title-row">' +
          '<span class="ql-card-icon" style="display:grid;place-items:center;width:28px;height:28px;border-radius:6px;background:#f1f5f9;color:#4f46e5">' + getPrizeSvgIcon(reward.type) + '</span>' +
          '<div>' +
            '<strong>' + escapeHtml(reward.title) + '</strong>' +
            '<small>Won ' + new Date(reward.created_at).toLocaleDateString() + '</small>' +
          '</div>' +
        '</div>' +
        statusHtml +
      '</div>' +
      codeRowHtml +
      '<button type="button" class="ql-card-terms-toggle">How to use &amp; rules ▾</button>' +
      '<div class="ql-card-claim-details" style="display:none">' +
        (isInApp ?
          '<div class="ql-claim-terms-box" style="margin-top:4px">' +
            '<div class="ql-claim-term-row"><strong>Auto-Credited:</strong> Added directly to your account balance. No coupon code needed.</div>' +
            '<div class="ql-claim-term-row"><strong>Usage:</strong> Click ' + (reward.type === "free_test" ? '"Test Yourself Now"' : '"Upload Paper Now"') + ' to use your bonus session.</div>' +
            '<div class="ql-claim-term-row"><strong>100% Free:</strong> No payment required.</div>' +
          '</div>' :
        isPro ?
          '<div class="ql-claim-terms-box" style="margin-top:4px">' +
            '<div class="ql-claim-term-row"><strong>Claim:</strong> Click the Claim button to activate 30 days of Pro.</div>' +
            '<div class="ql-claim-term-row"><strong>Zero Cost:</strong> No payment or card required. No recurring charge.</div>' +
            '<div class="ql-claim-term-row"><strong>Duration:</strong> Valid for exactly 30 consecutive calendar days.</div>' +
            '<div class="ql-claim-term-row"><strong>Terms:</strong> <a href="/terms.html#rewards-promotions" target="_blank">View Promotional Terms</a></div>' +
          '</div>' :
          '<div class="ql-claim-terms-box" style="margin-top:4px">' +
            '<div class="ql-claim-term-row"><strong>1. Visit:</strong> <a href="https://genziitian.in/courses" target="_blank" rel="noopener">Genziitian.in/courses</a> &amp; pick any course.</div>' +
            '<div class="ql-claim-term-row"><strong>2. Apply Code:</strong> <strong>' + (isExpired ? 'Masked (Expired)' : escapeHtml(reward.code || 'Scratch card above')) + '</strong></div>' +
            '<div class="ql-claim-term-row"><strong>Min Order:</strong> Minimum amount purchase is ₹350.</div>' +
            '<div class="ql-claim-term-row"><strong>Discount Cap:</strong> Max discount you get on any percentage is 100 rupees.</div>' +
            '<div class="ql-claim-term-row"><strong>Expiry:</strong> Auto-disables in 7 days counting from day scratched or spinned.</div>' +
            '<div class="ql-claim-term-row"><strong>Free:</strong> No payment required to get this coupon.</div>' +
            '<div class="ql-claim-term-row"><strong>Terms:</strong> By continuing you accept all our <a href="/terms.html#rewards-promotions" target="_blank">terms &amp; rules</a>.</div>' +
          '</div>'
        ) +
      '</div>' +
      '<div class="ql-card-footer">' +
        '<span>' + expiryText + '</span>' +
        '<span style="font-weight:700;color:' + (isExpired ? '#94a3b8' : '#15803d') + '">' + (isExpired ? 'Outdated' : (isInApp ? 'In-App Ready' : 'Valid on Website')) + '</span>' +
      '</div>';

    var toggleBtn = card.querySelector(".ql-card-terms-toggle");
    var detailsBox = card.querySelector(".ql-card-claim-details");
    if (toggleBtn && detailsBox) {
      toggleBtn.addEventListener("click", function () {
        var isHidden = detailsBox.style.display === "none";
        detailsBox.style.display = isHidden ? "block" : "none";
        toggleBtn.innerHTML = isHidden ? "Hide claim rules ▴" : "How to use &amp; rules ▾";
      });
    }

    var copyBtn = card.querySelector(".ql-card-copy-btn");
    if (copyBtn && copyBtn.tagName === "BUTTON") {
      copyBtn.addEventListener("click", function () {
        if (!reward.code) return;
        navigator.clipboard.writeText(reward.code).then(function () {
          copyBtn.textContent = "Copied!";
          setTimeout(function () { copyBtn.textContent = "Copy"; }, 2000);
        });
      });
    }

    var scratchBtn = card.querySelector(".ql-copy-code-btn");
    if (scratchBtn) {
      scratchBtn.addEventListener("click", function () {
        if (typeof onScratchClick === "function") onScratchClick(reward);
      });
    }

    var claimBtn = card.querySelector(".ql-claim-pro-btn");
    if (claimBtn) {
      claimBtn.addEventListener("click", function () {
        if (typeof onClaimProClick === "function") onClaimProClick(reward);
      });
    }

    return card;
  }

  var lastPromptServerCheck = 0;
  function ensureDailySpinPrompt() {
    var runtime = window.QLStorefront || {};
    var tok = runtime.token ? runtime.token() : (localStorage.getItem("lab_token") || "");
    if (!tok) return;

    var onRewards = /^\/(rewards|spin-rewards|daily-rewards)(\/|$)/i.test(window.location.pathname);
    if (onRewards) return;

    var today = getTodayISTString();
    var dismissedDate = "";
    try { dismissedDate = localStorage.getItem("ql_daily_spin_prompt_dismissed") || ""; } catch (_) {}
    if (dismissedDate === today) return;

    if (document.getElementById("ql-daily-prompt-overlay")) return;

    var now = Date.now();
    if (now - lastPromptServerCheck < 30000) return;
    lastPromptServerCheck = now;

    var apiBase = runtime.apiBase || "https://labapi.genziitian.in/public/api";
    fetch(apiBase + "/student/rewards", {
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer " + tok
      }
    }).then(function (res) {
      if (!res.ok) return null;
      return res.json();
    }).then(function (data) {
      if (!data || !data.quota) return;
      if (data.quota.remaining <= 0) return; // User already spun today on server!
      if (document.getElementById("ql-daily-prompt-overlay")) return;

      var overlay = document.createElement("div");
      overlay.id = "ql-daily-prompt-overlay";
      overlay.className = "ql-daily-prompt-overlay";
      overlay.innerHTML =
        '<div class="ql-daily-prompt-dialog" role="dialog" aria-modal="true">' +
          '<div class="ql-daily-prompt-hero">' +
            '<div class="ql-daily-prompt-icon" aria-hidden="true">' +
              '<svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m4.93 4.93 4.24 4.24"/><path d="m14.83 9.17 4.24-4.24"/><path d="m14.83 14.83 4.24 4.24"/><path d="m9.17 14.83-4.24 4.24"/><circle cx="12" cy="12" r="3"/></svg>' +
            '</div>' +
            '<h2>Daily Spin Available</h2>' +
            '<p>Spin today\'s Lucky Wheel to win Free Pro, discounts, and study perks!</p>' +
          '</div>' +
          '<div class="ql-daily-prompt-body">' +
            '<button type="button" class="ql-daily-prompt-spin-btn" id="ql-prompt-spin-cta">Spin Now</button>' +
            '<button type="button" class="ql-daily-prompt-later-btn" id="ql-prompt-later-cta">Maybe later</button>' +
          '</div>' +
        '</div>';
      document.body.appendChild(overlay);

      overlay.querySelector("#ql-prompt-spin-cta").addEventListener("click", function () {
        overlay.remove();
        var rewardsNav = document.querySelector('a[href="/rewards"]');
        if (rewardsNav) {
          rewardsNav.click();
        } else {
          location.assign("/rewards");
        }
      });

      function dismiss() {
        try { localStorage.setItem("ql_daily_spin_prompt_dismissed", today); } catch (_) {}
        overlay.remove();
      }
      overlay.querySelector("#ql-prompt-later-cta").addEventListener("click", dismiss);
      overlay.addEventListener("click", function (e) { if (e.target === overlay) dismiss(); });
    }).catch(function () {});
  }

  function getRulesDropdownHtml() {
    return '<details class="ql-rules-dropdown">' +
      '<summary class="ql-rules-summary">' +
        '<span class="ql-rules-summary-left">' +
          '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>' +
          ' Rules and Conditions' +
        '</span>' +
        '<svg class="ql-dropdown-chevron" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"/></svg>' +
      '</summary>' +
      '<div class="ql-rules-body">' +
        '<ul class="ql-rules-list">' +
          '<li><strong>Daily Free Spin Allowance:</strong> Every registered account receives 1 free spin every calendar day. No payment, deposit, or billing information is ever required. Daily spin quota resets at 12:00 AM IST (midnight).</li>' +
          '<li><strong>7-Day Automatic Expiry:</strong> All discount coupons and feature passes auto-disable exactly 7 days from the moment spun or scratched (claimed or unclaimed). Expired codes are masked and locked.</li>' +
          '<li><strong>Redemption Venue:</strong> Course discount coupons are valid exclusively at <a href="https://genziitian.in/courses" target="_blank" rel="noopener noreferrer" style="color:#4f46e5;font-weight:700">Genziitian.in/courses</a>. Choose any course and enter your coupon code at checkout.</li>' +
          '<li><strong>Order Value &amp; Max Cap:</strong> Minimum course purchase requirement is ₹350. The maximum discount on percentage coupons is capped at ₹100.</li>' +
          '<li><strong>30 Days Free Pro Membership:</strong> Claim instantly with one click. Provides 30 days of full Pro access with zero recurring billing or credit card requirements.</li>' +
          '<li><strong>Feature Passes &amp; Study XP:</strong> Test Yourself and Paper Upload passes provide 1-time waivers on Quiz Lab. XP boosters credit automatically to your profile progress.</li>' +
          '<li><strong>Platform Rules Agreement:</strong> By participating you accept all our <a href="/terms.html#rewards-promotions" target="_blank" style="color:#4f46e5;text-decoration:underline">terms, conditions and promotional rules</a>.</li>' +
        '</ul>' +
      '</div>' +
    '</details>';
  }

  function openPrizesDrawer() {
    if (document.getElementById("ql-prizes-overlay")) return;
    var overlay = document.createElement("div");
    overlay.id = "ql-prizes-overlay";
    overlay.className = "ql-prizes-overlay";
    var shuffled = WHEEL_PRIZES.slice().sort(function () { return Math.random() - 0.5; });
    overlay.innerHTML =
      '<div class="ql-prizes-drawer" role="dialog" aria-modal="true">' +
        '<div class="ql-prizes-drawer-head">' +
          '<h2>' +
            '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m4.93 4.93 4.24 4.24"/><path d="m14.83 9.17 4.24-4.24"/><path d="m14.83 14.83 4.24 4.24"/><path d="m9.17 14.83-4.24 4.24"/><circle cx="12" cy="12" r="3"/></svg>' +
            ' Wheel Prizes' +
          '</h2>' +
          '<button type="button" class="ql-prizes-drawer-close" aria-label="Close">' +
            '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>' +
          '</button>' +
        '</div>' +
        '<div class="ql-prizes-drawer-body">' +
          shuffled.map(function (p) {
            return '<div class="ql-prize-drawer-item">' +
              '<div class="ql-prize-drawer-icon" style="background:' + p.color + '">' +
                getPrizeSvgIcon(p.type) +
              '</div>' +
              '<div class="ql-prize-drawer-info">' +
                '<strong>' + escapeHtml(p.title) + '</strong>' +
                '<span>' + escapeHtml(p.sub) + ' · ' + escapeHtml(p.value) + '</span>' +
              '</div>' +
            '</div>';
          }).join('') +
        '</div>' +
      '</div>';
    document.body.appendChild(overlay);

    function close() {
      overlay.remove();
    }
    overlay.querySelector(".ql-prizes-drawer-close").addEventListener("click", close);
    overlay.addEventListener("click", function (e) { if (e.target === overlay) close(); });
  }

  function openResultModal(cfg) {
    var overlay = document.createElement("div");
    overlay.className = "ql-result-overlay";
    overlay.innerHTML =
      '<div class="ql-result-dialog" role="dialog" aria-modal="true">' +
        '<div class="ql-result-icon-bubble" style="background:' + (cfg.iconBg || '#4f46e5') + '">' +
          cfg.iconSvg +
        '</div>' +
        '<h2 class="ql-result-title">' + escapeHtml(cfg.title) + '</h2>' +
        '<p class="ql-result-desc">' + escapeHtml(cfg.desc) + '</p>' +
        '<button type="button" class="ql-result-action-btn" id="ql-result-cta">' + escapeHtml(cfg.btnText || 'Got It') + '</button>' +
      '</div>';
    document.body.appendChild(overlay);

    function close() {
      overlay.remove();
      if (typeof cfg.onClose === "function") cfg.onClose();
    }
    overlay.querySelector("#ql-result-cta").addEventListener("click", close);
    overlay.addEventListener("click", function (e) { if (e.target === overlay) close(); });
  }

  function fillRewardsPage() {
    var onRewards = /^\/(rewards|spin-rewards|daily-rewards)(\/|$)/i.test(window.location.pathname);
    var host = document.getElementById("ql-rewards-page");
    if (!onRewards) {
      if (host) {
        host.dataset.qlLoaded = "";
        host.innerHTML = "";
      }
      var existingRew = document.querySelector(".ql-rewards-page");
      if (existingRew && (!host || !host.contains(existingRew))) {
        existingRew.remove();
      }
      return;
    }

    var stalePractice = document.getElementById("ql-try-practice") || document.querySelector(".ql-spin-container");
    if (stalePractice && stalePractice !== host) stalePractice.remove();
    var staleUpload = document.getElementById("ql-upload-paper-page") || document.querySelector(".ql-upload-page-container");
    if (staleUpload && staleUpload !== host) staleUpload.remove();

    if (!host) {
      var outlet = document.querySelector("#root main .page-enter, #root main");
      if (outlet && !outlet.querySelector("#ql-rewards-page")) {
        host = document.createElement("div");
        host.id = "ql-rewards-page";
        outlet.appendChild(host);
      }
    }
    if (!host || host.dataset.qlLoaded) return;
    host.dataset.qlLoaded = "1";
    document.title = "Spin & Win · Daily Rewards · Quiz LAB";

    var runtime = window.QLStorefront || {};
    var apiBase = runtime.apiBase || "https://labapi.genziitian.in/public/api";
    var tok = runtime.token ? runtime.token() : (localStorage.getItem("lab_token") || "");

    var serverQuota = null;
    var serverRewards = [];
    var isSpunToday = false;
    var isLoadingQuota = Boolean(tok);
    var quotaError = false;
    var today = getTodayISTString();

    host.innerHTML =
      '<div class="ql-rewards-page">' +
        '<div class="ql-rewards-top-bar">' +
          '<div class="ql-rewards-corner-actions">' +
            '<button type="button" class="ql-corner-btn" id="ql-btn-open-prizes">' +
              '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m4.93 4.93 4.24 4.24"/><path d="m14.83 9.17 4.24-4.24"/><path d="m14.83 14.83 4.24 4.24"/><path d="m9.17 14.83-4.24 4.24"/><circle cx="12" cy="12" r="3"/></svg>' +
              ' View Prizes' +
            '</button>' +
            '<button type="button" class="ql-corner-btn primary" id="ql-tab-rewards">' +
              '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="8" width="18" height="4" rx="1"/><path d="M12 8v13"/><path d="M19 12v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7"/><path d="M7.5 8a2.5 2.5 0 0 1 0-5A4.8 8 0 0 1 12 8a4.8 8 0 0 1 4.5-5 2.5 2.5 0 0 1 0 5"/></svg>' +
              ' My Rewards <span class="ql-rewards-pill" id="ql-rewards-badge-count">0</span>' +
            '</button>' +
            '<button type="button" class="ql-corner-btn" id="ql-tab-wheel" style="display:none">' +
              '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></svg>' +
              ' Back to Wheel' +
            '</button>' +
          '</div>' +
        '</div>' +

        // Tab View 1: Lucky Wheel
        '<div id="ql-view-wheel" class="ql-wheel-layout">' +
          '<div class="ql-wheel-card">' +
            '<div class="ql-wheel-stage-wrap">' +
              '<svg class="ql-wheel-pointer-top" viewBox="0 0 24 32" aria-hidden="true"><path d="M12 30 L3 6 Q1 2 5 2 L19 2 Q23 2 21 6 Z"/></svg>' +
              '<canvas id="ql-rewards-canvas" class="ql-wheel-canvas" width="680" height="680"></canvas>' +
            '</div>' +
            '<div class="ql-wheel-controls">' +
              '<button type="button" class="ql-spin-main-cta" id="ql-rewards-spin-btn">' +
                (tok ? 'Checking Daily Allowance…' : '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:-3px"><circle cx="12" cy="12" r="10"/><path d="m4.93 4.93 4.24 4.24"/><path d="m14.83 9.17 4.24-4.24"/><path d="m14.83 14.83 4.24 4.24"/><path d="m9.17 14.83-4.24 4.24"/><circle cx="12" cy="12" r="3"/></svg> Sign in to Spin') +
              '</button>' +
              '<div class="ql-spin-quota-text" id="ql-rewards-timer-label" style="display:none">' +
              '</div>' +
            '</div>' +
          '</div>' +
          getRulesDropdownHtml() +
        '</div>' +

        // Tab View 2: My Rewards List
        '<div id="ql-view-rewards" class="ql-my-rewards-view" style="display:none">' +
          '<div class="ql-rewards-filter-bar">' +
            '<button type="button" class="ql-filter-pill" data-filter="all" aria-selected="true">All Rewards</button>' +
            '<button type="button" class="ql-filter-pill" data-filter="active">Active Coupons</button>' +
            '<button type="button" class="ql-filter-pill" data-filter="pro">Pro Membership</button>' +
            '<button type="button" class="ql-filter-pill" data-filter="expired">Outdated / Expired</button>' +
          '</div>' +
          '<div class="ql-reward-cards-grid" id="ql-rewards-grid"></div>' +
          getRulesDropdownHtml() +
        '</div>' +
      '</div>';

    // Elements
    var canvas = host.querySelector("#ql-rewards-canvas");
    var ctx = canvas.getContext("2d");
    var spinBtn = host.querySelector("#ql-rewards-spin-btn");
    var timerVal = host.querySelector("#ql-timer-val");
    var timerLabel = host.querySelector("#ql-rewards-timer-label");
    var tabWheel = host.querySelector("#ql-tab-wheel");
    var tabRewards = host.querySelector("#ql-tab-rewards");
    var btnOpenPrizes = host.querySelector("#ql-btn-open-prizes");
    var viewWheel = host.querySelector("#ql-view-wheel");
    var viewRewards = host.querySelector("#ql-view-rewards");
    var rewardsGrid = host.querySelector("#ql-rewards-grid");
    var badgeCount = host.querySelector("#ql-rewards-badge-count");

    if (btnOpenPrizes) {
      btnOpenPrizes.addEventListener("click", openPrizesDrawer);
    }

    var isSpinning = false;
    var currentAngle = 0;
    var timerInterval = null;

    function updateTimer() {
      var rem = getMidnightISTRemaining();
      if (timerVal) timerVal.textContent = rem.text;
      if (rem.diff <= 0) {
        if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }
        if (tok) {
          fetchQuota();
        } else {
          isSpunToday = false;
          renderButtonState();
        }
      }
    }

    function renderButtonState() {
      if (!tok) {
        spinBtn.disabled = false;
        spinBtn.innerHTML = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:-3px"><circle cx="12" cy="12" r="10"/><path d="m4.93 4.93 4.24 4.24"/><path d="m14.83 9.17 4.24-4.24"/><path d="m14.83 14.83 4.24 4.24"/><path d="m9.17 14.83-4.24 4.24"/><circle cx="12" cy="12" r="3"/></svg> Sign in to Spin';
        timerLabel.style.display = "none";
        timerLabel.innerHTML = '';
        return;
      }
      if (isLoadingQuota) {
        spinBtn.disabled = true;
        spinBtn.innerHTML = '<svg class="animate-spin" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" style="display:inline-block;vertical-align:-3px"><circle cx="12" cy="12" r="10" stroke-opacity="0.25"/><path d="M12 2a10 10 0 0 1 10 10" stroke-linecap="round"/></svg> Checking Daily Allowance…';
        timerLabel.style.display = "none";
        timerLabel.innerHTML = '';
        return;
      }
      if (quotaError || !serverQuota) {
        spinBtn.disabled = false;
        spinBtn.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:-3px"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg> Check Allowance · Tap to Retry';
        timerLabel.style.display = "none";
        timerLabel.innerHTML = '';
        return;
      }
      if (isSpunToday || (serverQuota && serverQuota.remaining <= 0)) {
        spinBtn.disabled = true;
        spinBtn.innerHTML = '✓ Spun Today · Come Back Tomorrow';
        timerLabel.style.display = "block";
        timerLabel.innerHTML = 'Next spin resets in: <span class="ql-spin-timer-badge" id="ql-timer-val">calculating…</span>';
        timerVal = host.querySelector("#ql-timer-val");
        updateTimer();
        if (!timerInterval) timerInterval = setInterval(updateTimer, 1000);
      } else {
        if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }
        spinBtn.disabled = isSpinning;
        spinBtn.innerHTML = isSpinning
          ? '<svg class="animate-spin" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" style="display:inline-block;vertical-align:-3px"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg> Spinning the Lucky Wheel…'
          : '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;vertical-align:-3px"><path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/></svg> SPIN NOW';
        timerLabel.style.display = "none";
        timerLabel.innerHTML = '';
      }
    }
    renderButtonState();

    function fetchQuota() {
      if (!tok) return;
      isLoadingQuota = true;
      quotaError = false;
      renderButtonState();

      fetch(apiBase + "/student/rewards", {
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer " + tok
        }
      }).then(function (res) {
        if (!res.ok) {
          isLoadingQuota = false;
          quotaError = true;
          renderButtonState();
          return null;
        }
        return res.json();
      }).then(function (data) {
        isLoadingQuota = false;
        if (!data || !data.quota) {
          quotaError = true;
          renderButtonState();
          return;
        }
        quotaError = false;
        serverQuota = data.quota || {};
        serverRewards = Array.isArray(data.rewards) ? data.rewards : [];
        isSpunToday = Boolean(serverQuota.remaining <= 0);
        badgeCount.textContent = serverRewards.length;
        renderButtonState();
        renderRewardsList();
      }).catch(function () {
        isLoadingQuota = false;
        quotaError = true;
        renderButtonState();
      });
    }

    if (tok) {
      fetchQuota();
    }

    // Wheel drawing
    function drawWheel(angle, lightTick) {
      var w = canvas.width;
      var h = canvas.height;
      var cx = w / 2;
      var cy = h / 2;
      var r = cx - 24;
      var numSlices = WHEEL_PRIZES.length;
      var arc = (Math.PI * 2) / numSlices;

      ctx.clearRect(0, 0, w, h);

      // Outer gold rim
      ctx.save();
      ctx.beginPath();
      ctx.arc(cx, cy, r + 18, 0, Math.PI * 2);
      ctx.fillStyle = "#1e293b";
      ctx.fill();
      ctx.lineWidth = 14;
      ctx.strokeStyle = "#eab308";
      ctx.stroke();

      // Outer lights (24 bulbs)
      var numLights = 24;
      for (var k = 0; k < numLights; k++) {
        var lightAngle = (k * (Math.PI * 2)) / numLights;
        var lx = cx + (r + 18) * Math.cos(lightAngle);
        var ly = cy + (r + 18) * Math.sin(lightAngle);
        var isLit = ((k + Math.floor(lightTick || 0)) % 2 === 0);
        ctx.beginPath();
        ctx.arc(lx, ly, 5, 0, Math.PI * 2);
        ctx.fillStyle = isLit ? "#fef08a" : "#ca8a04";
        ctx.shadowColor = isLit ? "#fef08a" : "transparent";
        ctx.shadowBlur = isLit ? 10 : 0;
        ctx.fill();
      }
      ctx.restore();

      // Slices
      for (var i = 0; i < numSlices; i++) {
        var startAngle = angle + (i * arc);
        var endAngle = startAngle + arc;
        var p = WHEEL_PRIZES[i];

        ctx.save();
        ctx.beginPath();
        ctx.moveTo(cx, cy);
        ctx.arc(cx, cy, r, startAngle, endAngle);
        ctx.closePath();
        var sliceMid = startAngle + arc / 2;
        var sliceGrad = ctx.createRadialGradient(cx, cy, r * 0.12, cx + Math.cos(sliceMid) * r * 0.4, cy + Math.sin(sliceMid) * r * 0.4, r);
        sliceGrad.addColorStop(0, "rgba(0,0,0,.38)");
        sliceGrad.addColorStop(0.35, p.color);
        sliceGrad.addColorStop(1, p.color);
        ctx.fillStyle = sliceGrad;
        ctx.fill();

        // Edge separator
        ctx.lineWidth = 2.5;
        ctx.strokeStyle = "rgba(255, 255, 255, 0.4)";
        ctx.stroke();

        // Inner shadow
        ctx.clip();
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.lineWidth = 16;
        ctx.strokeStyle = "rgba(0, 0, 0, 0.14)";
        ctx.stroke();
        ctx.restore();

        // Slice text
        ctx.save();
        ctx.translate(cx, cy);
        ctx.rotate(startAngle + arc / 2);
        ctx.textAlign = "right";
        ctx.fillStyle = "#ffffff";
        ctx.font = p.title.length > 8 ? "bold 15px sans-serif" : "bold 18px sans-serif";
        ctx.shadowColor = "rgba(0, 0, 0, 0.4)";
        ctx.shadowBlur = 4;
        ctx.fillText(p.title, r - 32, 5);

        ctx.font = "11px sans-serif";
        ctx.fillStyle = "#fde047";
        ctx.fillText(p.sub, r - 32, 20);
        ctx.restore();
      }

      // Gold pearls on every slice edge and a soft glass reflection
      for (var pe = 0; pe < numSlices; pe++) {
        var pa = angle + pe * arc;
        ctx.beginPath();
        ctx.arc(cx + Math.cos(pa) * (r - 9), cy + Math.sin(pa) * (r - 9), 4, 0, Math.PI * 2);
        ctx.fillStyle = "#fde68a";
        ctx.fill();
      }
      var glass = ctx.createLinearGradient(cx - r, cy - r, cx + r, cy + r);
      glass.addColorStop(0, "rgba(255,255,255,.2)");
      glass.addColorStop(0.45, "rgba(255,255,255,0)");
      glass.addColorStop(1, "rgba(0,0,0,.14)");
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, Math.PI * 2);
      ctx.fillStyle = glass;
      ctx.fill();

      // Center Hub
      ctx.save();
      ctx.beginPath();
      ctx.arc(cx, cy, 54, 0, Math.PI * 2);
      ctx.fillStyle = "#0f172a";
      ctx.shadowColor = "rgba(0, 0, 0, 0.35)";
      ctx.shadowBlur = 12;
      ctx.fill();
      ctx.lineWidth = 6;
      ctx.strokeStyle = "#eab308";
      ctx.stroke();

      ctx.beginPath();
      ctx.arc(cx, cy, 38, 0, Math.PI * 2);
      ctx.fillStyle = "#facc15";
      ctx.fill();

      ctx.fillStyle = "#713f12";
      ctx.font = "bold 20px sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("QUIZ", cx, cy - 6);
      ctx.font = "bold 13px sans-serif";
      ctx.fillText("LAB", cx, cy + 10);
      ctx.restore();
    }
    drawWheel(0, 0);

    // Spin animation execution
    function startSpin() {
      if (!tok) {
        location.assign("/login");
        return;
      }
      if (quotaError || !serverQuota) {
        fetchQuota();
        return;
      }
      if (isSpinning || isSpunToday || (serverQuota && serverQuota.remaining <= 0)) {
        isSpunToday = true;
        renderButtonState();
        return;
      }

      isSpinning = true;
      spinBtn.disabled = true;
      spinBtn.innerHTML = '<svg class="animate-spin" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" style="display:inline-block;vertical-align:-3px"><circle cx="12" cy="12" r="10" stroke-opacity="0.25"/><path d="M12 2a10 10 0 0 1 10 10" stroke-linecap="round"/></svg> Contacting server…';

      fetch(apiBase + "/student/rewards/spin", {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer " + tok
        }
      }).then(function (res) {
        if (res.status === 429) {
          return res.json().then(function (err) {
            isSpinning = false;
            isSpunToday = true;
            if (err.quota) serverQuota = err.quota;
            else if (serverQuota) serverQuota.remaining = 0;
            renderButtonState();
            alert(err.error || "You have already used your daily spin for today. Come back tomorrow after midnight IST!");
            return null;
          });
        }
        if (!res.ok) {
          return res.json().catch(function () { return {}; }).then(function (err) {
            var msg = err.error || err.message;
            if (!msg && res.status === 404) msg = "Daily spin service is updating on the server. Please try again shortly.";
            throw new Error(msg || "Could not spin the wheel.");
          });
        }
        return res.json();
      }).then(function (data) {
        if (!data) return;
        var chosenIndex = (typeof data.segment === "number") ? data.segment : 0;
        var chosenPrize = WHEEL_PRIZES[chosenIndex] || data.prize;
        var serverReward = data.reward;
        serverQuota = data.quota || {};

        var numSlices = WHEEL_PRIZES.length;
        var arc = (Math.PI * 2) / numSlices;
        var targetAngle = (Math.PI * 1.5) - (chosenIndex * arc + arc / 2);
        var fullRotations = 6 + Math.floor(Math.random() * 3);
        var totalAngleDelta = (fullRotations * Math.PI * 2) + (targetAngle - (currentAngle % (Math.PI * 2)));
        if (totalAngleDelta < fullRotations * Math.PI * 2) totalAngleDelta += Math.PI * 2;

        var startAngle = currentAngle;
        var duration = 4600;
        var startTime = Date.now();
        var lastSliceTick = -1;
        var lightTick = 0;

        spinBtn.innerHTML = '<svg class="animate-spin" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" style="display:inline-block;vertical-align:-3px"><circle cx="12" cy="12" r="10" stroke-opacity="0.25"/><path d="M12 2a10 10 0 0 1 10 10" stroke-linecap="round"/></svg> Spinning the Lucky Wheel…';

        function frame() {
          var now = Date.now();
          var t = Math.min(1, (now - startTime) / duration);
          var ease = 1 - Math.pow(1 - t, 3.8);
          currentAngle = startAngle + totalAngleDelta * ease;
          lightTick += 0.35;

          var currentSlice = Math.floor((currentAngle % (Math.PI * 2)) / arc);
          if (currentSlice !== lastSliceTick) {
            lastSliceTick = currentSlice;
            playWheelTickSound();
          }

          drawWheel(currentAngle, lightTick);

          if (t < 1) {
            requestAnimationFrame(frame);
          } else {
            isSpinning = false;
            if (chosenPrize.type !== "free_spin") {
              isSpunToday = true;
            }
            if (serverReward) {
              serverRewards.unshift(serverReward);
            }
            badgeCount.textContent = serverRewards.length;
            renderButtonState();
            renderRewardsList();

            playWheelWinSound();
            fireConfettiBurst();

            if (chosenPrize.type === "free_pro") {
              openProJackpotModal(serverReward, function () {
                renderRewardsList();
              });
            } else if (chosenPrize.type === "free_spin") {
              openResultModal({
                iconBg: "linear-gradient(135deg,#0284c7,#2563eb)",
                iconSvg: '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/></svg>',
                title: "1 Free Extra Spin Won!",
                desc: "You unlocked a free instant re-spin! Spin the lucky wheel again right now without consuming your daily quota.",
                btnText: "Spin Again Now"
              });
            } else if (serverReward && chosenPrize.type !== "bonus_xp") {
              openScratchCardModal(serverReward, function () {
                if (serverReward.id && tok) {
                  fetch(apiBase + "/student/rewards/scratch", {
                    method: "POST",
                    headers: {
                      "Accept": "application/json",
                      "Content-Type": "application/json",
                      "Authorization": "Bearer " + tok
                    },
                    body: JSON.stringify({ id: serverReward.id })
                  }).catch(function () {});
                }
                renderRewardsList();
              });
            } else if (chosenPrize.type === "bonus_xp") {
              openResultModal({
                iconBg: "linear-gradient(135deg,#2563eb,#4f46e5)",
                iconSvg: '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/></svg>',
                title: "+50 Study XP Earned!",
                desc: "Awesome! 50 bonus Study XP has been added to your profile to boost your learning rank.",
                btnText: "Awesome!"
              });
            } else {
              openResultModal({
                iconBg: "linear-gradient(135deg,#64748b,#475569)",
                iconSvg: '<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="7" r="4"/><circle cx="7" cy="12" r="4"/><circle cx="17" cy="12" r="4"/><circle cx="12" cy="17" r="4"/><path d="M12 12v9"/></svg>',
                title: "Better Luck Next Time!",
                desc: "Your daily spin resets tomorrow at midnight IST. Come back tomorrow to spin again!",
                btnText: "Got It"
              });
            }
          }
        }
        requestAnimationFrame(frame);
      }).catch(function (err) {
        isSpinning = false;
        renderButtonState();
        alert(err.message || "Could not spin the wheel. Please check your connection.");
      });
    }

    // Tab switcher
    tabRewards.addEventListener("click", function () {
      viewWheel.style.display = "none";
      viewRewards.style.display = "block";
      tabRewards.style.display = "none";
      tabWheel.style.display = "inline-flex";
      renderRewardsList();
    });

    tabWheel.addEventListener("click", function () {
      viewWheel.style.display = "flex";
      viewRewards.style.display = "none";
      tabRewards.style.display = "inline-flex";
      tabWheel.style.display = "none";
    });

    // Filter pills
    var currentFilter = "all";
    host.querySelectorAll(".ql-filter-pill").forEach(function (pill) {
      pill.addEventListener("click", function () {
        host.querySelectorAll(".ql-filter-pill").forEach(function (p) { p.setAttribute("aria-selected", "false"); });
        pill.setAttribute("aria-selected", "true");
        currentFilter = pill.dataset.filter || "all";
        renderRewardsList();
      });
    });

    function renderRewardsList() {
      var nowTime = Date.now();
      rewardsGrid.replaceChildren();

      var list = serverRewards.filter(function (r) {
        var isExpired = r.expires_at ? nowTime > new Date(r.expires_at).getTime() : false;
        if (currentFilter === "active") return !isExpired && r.type !== "free_pro";
        if (currentFilter === "pro") return r.type === "free_pro";
        if (currentFilter === "expired") return isExpired;
        return true;
      });

      if (!list.length) {
        var empty = document.createElement("div");
        empty.style.cssText = "grid-column:1/-1;text-align:center;padding:60px 20px;color:#64748b";
        empty.innerHTML =
          '<div style="width:48px;height:48px;border-radius:14px;background:#eef2ff;color:#4f46e5;display:grid;place-items:center;margin:0 auto 12px"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="8" width="18" height="4" rx="1"/><path d="M12 8v13"/><path d="M19 12v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7"/><path d="M7.5 8a2.5 2.5 0 0 1 0-5A4.8 8 0 0 1 12 8a4.8 8 0 0 1 4.5-5 2.5 2.5 0 0 1 0 5"/></svg></div>' +
          '<strong style="font-size:16px;color:#0f172a;display:block">No rewards in this view</strong>' +
          '<p style="font-size:13px;margin:6px 0 0">Spin the Lucky Wheel daily to collect coupon codes and free plans.</p>';
        rewardsGrid.appendChild(empty);
        return;
      }

      list.forEach(function (reward) {
        var card = formatRewardCard(
          reward,
          nowTime,
          function onScratch(r) {
            openScratchCardModal(r, function () {
              if (r.id && tok) {
                fetch(apiBase + "/student/rewards/scratch", {
                  method: "POST",
                  headers: {
                    "Accept": "application/json",
                    "Content-Type": "application/json",
                    "Authorization": "Bearer " + tok
                  },
                  body: JSON.stringify({ id: r.id })
                }).catch(function () {});
              }
              renderRewardsList();
            });
          },
          function onClaimPro(r) {
            claimProMembership(r, function () {
              renderRewardsList();
            });
          }
        );
        rewardsGrid.appendChild(card);
      });
    }

    spinBtn.addEventListener("click", startSpin);
  }

  /* One failing step must never stop the page-specific steps after it. */
  function guard(step) {
    try { step(); } catch (error) { if (window.console) console.error("[Quiz LAB]", error); }
  }

  function run() {
    var paper = paperRoomPath(window.location.pathname);
    if (paper) { window.location.replace(paper); return; }
    guard(syncBrandName);
    guard(simplifyLogin);
    guard(syncAdminShell);
    guard(syncPaperPricingLink);
    guard(removeStudentWeakSpotCard);
    guard(decorateDashboard);
    guard(syncPhoneTopBar);
    guard(decorateManagerConsole);
    guard(fillMyPapers);
    guard(fillTryPractice);
    guard(fillUploadPaperPage);
    guard(syncTryPracticeNav);
    guard(syncUploadPaperNav);
    guard(decoratePracticeCards);
    guard(decoratePracticeList);
    guard(syncConsoleNav);
    guard(syncHomeLink);
    guard(decorateCoursePage);
    guard(decorateCoursePapers);
    guard(updateExamNav);
    guard(renderAnnouncements);
    guard(syncBellNotifications);
    guard(lockVideoSolutions);
    guard(decorateLeaderboard);
    guard(syncQuizBackLink);
    guard(syncRewardsButton);
    guard(fillRewardsPage);
    guard(ensureDailySpinPrompt);
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
  window.addEventListener("resize", schedule);

  var lastPath = window.location.pathname;
  setInterval(function () {
    if (window.location.pathname !== lastPath) {
      lastPath = window.location.pathname;
      schedule();
    }
  }, 200);
})();
