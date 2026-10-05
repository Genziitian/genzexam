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
    var badgeText = role === "manager" ? "Manager" : "Admin";
    document.querySelectorAll("#root aside h1 > span:last-child, #root header h1 > span:last-child").forEach(function (badge) {
      if (badge.textContent.trim() !== badgeText) badge.textContent = badgeText;
    });

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
    }
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

  function run() {
    syncBrandName();
    syncAdminShell();
    removeStudentWeakSpotCard();
    if (!/\/discussions/i.test(window.location.pathname)) return;
    injectStyles();
    ROWS.forEach(convertRow);
    convertDiscussionSortRow();
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
