/*
 * Manager announcements: add, schedule, edit, switch off and delete the
 * announcements that slide across the top of the student dashboard.
 */
(function () {
  "use strict";
  const API = ((window.QLStorefront && window.QLStorefront.apiBase) || "https://labapi.genziitian.in/public/api").replace(/\/+$/, "");
  const $ = (id) => document.getElementById(id);
  const esc = (v) => String(v == null ? "" : v).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
  const st = { rows: [], editing: null, armed: null, toastTimer: null };

  function token() { try { return localStorage.getItem("lab_token") || ""; } catch (_) { return ""; } }
  async function api(path, method, body) {
    const res = await fetch(API + path, {
      method: method || "GET",
      headers: { Accept: "application/json", ...(body ? { "Content-Type": "application/json" } : {}), Authorization: "Bearer " + token() },
      body: body ? JSON.stringify(body) : undefined,
    });
    let data = null; try { data = await res.json(); } catch (_) {}
    if (res.status === 401) { location.assign("/login"); throw new Error("Your session expired."); }
    if (!res.ok) {
      const errs = data && data.errors ? Object.values(data.errors).flat().join(" ") : "";
      throw new Error(errs || (data && (data.message || data.error)) || "Request failed (" + res.status + ")");
    }
    return data;
  }
  function toast(msg) { const t = $("toast"); t.textContent = msg; t.classList.add("show"); clearTimeout(st.toastTimer); st.toastTimer = setTimeout(() => t.classList.remove("show"), 2600); }
  // datetime-local <-> ISO (browser local time, India for this team)
  const toLocal = (iso) => { if (!iso) return ""; const d = new Date(iso); if (isNaN(d)) return ""; const p = (n) => String(n).padStart(2, "0"); return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "T" + p(d.getHours()) + ":" + p(d.getMinutes()); };
  const fromLocal = (v) => (v ? new Date(v).toISOString() : null);
  const when = (iso) => (iso ? new Date(iso).toLocaleString("en-IN", { day: "numeric", month: "short", hour: "numeric", minute: "2-digit" }) : "");

  function swatch(a) {
    return '<div class="' + (a.cls || "swatch") + " tone-" + esc(a.tone || "brand") + '"><b>' + esc(a.title || "Your title") + "</b>" +
      (a.body ? "<p>" + esc(a.body) + "</p>" : "") + (a.link_url ? '<span class="cta">' + esc(a.link_label || "Open") + " →</span>" : "") + "</div>";
  }
  function formData() {
    return {
      title: $("f-title").value.trim(), body: $("f-body").value.trim() || null,
      link_label: $("f-label").value.trim() || null, link_url: $("f-url").value.trim() || null,
      starts_at: fromLocal($("f-start").value), ends_at: fromLocal($("f-end").value),
      tone: $("f-tone").value, sort_order: Number($("f-order").value || 0), is_active: $("f-active").checked,
    };
  }
  function preview() { const d = formData(); $("preview").outerHTML = swatch({ ...d, cls: "ann-preview" }).replace('class="ann-preview', 'id="preview" class="ann-preview'); }
  function fill(a) {
    st.editing = a ? a.id : null;
    $("f-title").value = a ? a.title : ""; $("f-body").value = a ? a.body || "" : "";
    $("f-label").value = a ? a.link_label || "" : ""; $("f-url").value = a ? a.link_url || "" : "";
    $("f-start").value = a ? toLocal(a.starts_at) : ""; $("f-end").value = a ? toLocal(a.ends_at) : "";
    $("f-tone").value = a ? a.tone || "brand" : "brand"; $("f-order").value = a ? a.sort_order || 0 : 0;
    $("f-active").checked = a ? !!a.is_active : true;
    $("form-title").textContent = a ? "Edit announcement" : "New announcement";
    $("save").textContent = a ? "Save changes" : "Publish";
    $("cancel").hidden = !a; preview();
  }
  function status(a) {
    const now = Date.now();
    if (!a.is_active) return ["Off", ""];
    if (a.starts_at && new Date(a.starts_at) > now) return ["Scheduled · " + when(a.starts_at), ""];
    if (a.ends_at && new Date(a.ends_at) <= now) return ["Ended", ""];
    return ["Live" + (a.ends_at ? " · until " + when(a.ends_at) : ""), "live"];
  }
  function render() {
    const list = $("list");
    if (!st.rows.length) { list.innerHTML = '<p class="ann-empty">No announcements yet. Add one on the left and it appears on every student dashboard.</p>'; return; }
    list.innerHTML = st.rows.map((a) => {
      const [label, cls] = status(a);
      return '<article class="ann-item">' + swatch(a) + '<div class="meta"><span class="pill ' + cls + '">' + esc(label) + "</span><span>Order " + esc(a.sort_order) + "</span>" +
        (a.link_url ? "<span>→ " + esc(a.link_url) + "</span>" : "") + '</div><div class="btns">' +
        '<button type="button" class="quiet" data-edit="' + a.id + '">Edit</button>' +
        '<button type="button" class="quiet" data-toggle="' + a.id + '">' + (a.is_active ? "Switch off" : "Switch on") + "</button>" +
        '<button type="button" class="danger' + (st.armed === a.id ? " armed" : "") + '" data-del="' + a.id + '">' + (st.armed === a.id ? "Click again to delete" : "Delete") + "</button></div></article>";
    }).join("");
  }
  async function load(isRetry) {
    try {
      const d = await api("/manager/announcements");
      st.rows = d.announcements || [];
      render();
    } catch (err) {
      if (!isRetry) {
        try {
          await api("/manager/system/migrate", "POST");
          return await load(true);
        } catch (_) {}
      }
      $("list").innerHTML = '<div class="ann-empty"><p>Could not load announcements: ' + esc(err.message) + '</p><button type="button" class="primary" style="margin-top:12px;padding:8px 16px;font-weight:600;cursor:pointer;" id="ann-repair-btn">Run Database Update</button></div>';
      const b = $("ann-repair-btn");
      if (b) b.onclick = async () => {
        b.disabled = true; b.textContent = "Updating database...";
        try {
          await api("/manager/system/migrate", "POST");
          toast("Database updated!");
          await load(true);
        } catch (e) {
          toast("Update failed: " + e.message);
          b.disabled = false; b.textContent = "Run Database Update";
        }
      };
    }
  }

  $("form").addEventListener("input", preview);
  $("form").addEventListener("change", preview);
  $("cancel").addEventListener("click", () => fill(null));
  $("form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const d = formData();
    if (!d.title) return toast("Add a title first.");
    if (d.link_url && !/^(https:\/\/|\/)/.test(d.link_url)) return toast("The link must start with / or https://");
    $("save").disabled = true;
    try {
      if (st.editing) await api("/manager/announcements/" + st.editing, "PATCH", d); else await api("/manager/announcements", "POST", d);
      toast(st.editing ? "Saved" : "Published"); fill(null); await load();
    } catch (err) { toast(err.message); } finally { $("save").disabled = false; }
  });
  $("list").addEventListener("click", async (e) => {
    const b = e.target.closest("button"); if (!b) return;
    const id = Number(b.dataset.edit || b.dataset.toggle || b.dataset.del);
    const row = st.rows.find((r) => r.id === id); if (!row) return;
    if (b.dataset.edit) { fill(row); window.scrollTo({ top: 0, behavior: "smooth" }); return; }
    try {
      if (b.dataset.toggle) { await api("/manager/announcements/" + id, "PATCH", { is_active: !row.is_active }); toast(row.is_active ? "Switched off" : "Switched on"); }
      if (b.dataset.del) {
        if (st.armed !== id) { st.armed = id; render(); setTimeout(() => { if (st.armed === id) { st.armed = null; render(); } }, 4000); return; }
        st.armed = null; await api("/manager/announcements/" + id, "DELETE"); toast("Deleted"); if (st.editing === id) fill(null);
      }
      await load();
    } catch (err) { toast(err.message); }
  });

  async function boot() {
    const gate = $("gate");
    if (!token()) return location.assign("/login");
    try {
      const me = await api("/auth/me"); const user = me.user || me;
      if (!user || user.role !== "manager") { gate.textContent = "Only manager accounts can manage announcements."; gate.classList.add("error"); return; }
      $("me").textContent = user.name || user.email || "";
    } catch (err) { gate.textContent = "Could not verify your account: " + err.message; gate.classList.add("error"); return; }
    gate.hidden = true; $("workspace").hidden = false; fill(null);
    await load();
  }
  boot();
})();
