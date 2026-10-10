/*
 * Basic and scientific calculator for the exam screens (paper room and online
 * exams). Same panel and keys as the exam portal's calculator. Arithmetic is
 * evaluated by a small parser, not eval, so it works under the pages' CSP.
 */
(function (global) {
  "use strict";

  let mode = "basic";
  let expression = "";
  let current = "0";
  let history = "";
  let open = false;
  let typed = false; // has the current number been entered since the last operator?

  const ICON_CALC =
    '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#29467a" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="2" width="16" height="20" rx="2"/><path d="M8 6h8M8 11h.01M12 11h.01M16 11h.01M8 15h.01M12 15h.01M16 15h.01M8 19h.01M12 19h.01M16 19h.01"/></svg>';
  const ICON_X =
    '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#64748b" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18"/></svg>';

  /* ---- expression evaluation: + - * / % ^ and parentheses ---- */
  function evaluate(text) {
    const tokens = String(text).match(/\d+\.?\d*(?:e[+-]?\d+)?|\.\d+|[-+*/%^()]/gi);
    if (!tokens || tokens.join("") !== String(text).replace(/\s+/g, "")) throw new Error("bad expression");
    let pos = 0;
    const peek = () => tokens[pos];
    const take = () => tokens[pos++];
    function primary() {
      const token = take();
      if (token === "(") {
        const value = sum();
        if (take() !== ")") throw new Error("missing )");
        return value;
      }
      if (token === "-") return -primary();
      if (token === "+") return primary();
      const value = Number(token);
      if (token === undefined || Number.isNaN(value)) throw new Error("bad number");
      return value;
    }
    function power() {
      const base = primary();
      return peek() === "^" ? (take(), Math.pow(base, power())) : base;
    }
    function product() {
      let value = power();
      while (peek() === "*" || peek() === "/" || peek() === "%") {
        const op = take();
        const right = power();
        value = op === "*" ? value * right : op === "/" ? value / right : value % right;
      }
      return value;
    }
    function sum() {
      let value = product();
      while (peek() === "+" || peek() === "-") value = take() === "+" ? value + product() : value - product();
      return value;
    }
    const result = sum();
    if (pos !== tokens.length || !Number.isFinite(result)) throw new Error("bad expression");
    return result;
  }
  const tidy = (value) => String(Number.isInteger(value) ? value : Number(value.toFixed(6)));

  function key(k) {
    const wasTyped = typed;
    typed = !["C", "+", "-", "*", "/", "%", "pow", "(", ")", "="].includes(k);
    if (["DEL", "±"].includes(k)) typed = wasTyped;
    key2(k, wasTyped);
  }
  function key2(k, wasTyped) {
    const closed = /\)\s*$/.test(expression) && !wasTyped;
    if (k === "C") {
      current = "0";
      expression = "";
      history = "";
    } else if (k === "DEL") {
      current = current.length > 1 && current !== "Error" ? current.slice(0, -1) : "0";
    } else if (k === "±") {
      if (current !== "0" && current !== "Error") current = current.startsWith("-") ? current.slice(1) : "-" + current;
    } else if (k === "pi") {
      current = String(Math.PI.toFixed(6));
    } else if (k === "e") {
      current = String(Math.E.toFixed(6));
    } else if (["sin", "cos", "tan", "log", "ln", "sqrt", "sqr", "inv", "abs"].includes(k)) {
      const v = parseFloat(current) || 0;
      let res = 0;
      if (k === "sin") res = Math.sin((v * Math.PI) / 180);
      else if (k === "cos") res = Math.cos((v * Math.PI) / 180);
      else if (k === "tan") res = Math.tan((v * Math.PI) / 180);
      else if (k === "log") res = Math.log10(v);
      else if (k === "ln") res = Math.log(v);
      else if (k === "sqrt") res = Math.sqrt(v);
      else if (k === "sqr") res = v * v;
      else if (k === "inv") res = v !== 0 ? 1 / v : NaN;
      else if (k === "abs") res = Math.abs(v);
      history = k + "(" + v + ") =";
      current = Number.isFinite(res) ? tidy(res) : "Error";
    } else if (["+", "-", "*", "/", "%", "pow"].includes(k)) {
      expression += (closed ? "" : current === "Error" ? "0" : current) + " " + (k === "pow" ? "^" : k) + " ";
      history = expression;
      current = "0";
    } else if (k === "(" || k === ")") {
      if (k === ")") {
        expression += (closed ? "" : current) + " ) ";
        current = "0";
      } else expression += " ( ";
      history = expression;
    } else if (k === "=") {
      const tail = closed ? "" : current;
      const full = (expression + tail).trim();
      history = full + " =";
      try {
        current = tidy(evaluate(full.replace(/\s+/g, "")));
      } catch (_) {
        current = "Error";
      }
      expression = "";
    } else {
      if (current === "Error") current = "0";
      if (k === "." && current.includes(".")) return;
      current = current === "0" && k !== "." ? k : current + k;
    }
    const display = document.getElementById("ep-calc-disp-text");
    if (display) display.textContent = current;
    const hist = document.getElementById("ep-calc-hist-text");
    if (hist) hist.textContent = history;
  }

  const keyButton = (k, label, cls, span) =>
    '<button type="button" class="ep-calc-key' +
    (cls ? " " + cls : "") +
    '" data-k="' +
    k +
    '"' +
    (span ? ' style="grid-column: span 2;"' : "") +
    ">" +
    (label || k) +
    "</button>";

  function draw(panel) {
    panel.className = "ep-calc-panel" + (mode === "pro" ? " pro-mode" : "");
    const basic =
      '<div class="ep-calc-grid-basic">' +
      keyButton("C", "C", "action-clear") + keyButton("DEL", "DEL", "action-clear") + keyButton("±", "±", "op") + keyButton("/", "÷", "op") +
      keyButton("7") + keyButton("8") + keyButton("9") + keyButton("*", "×", "op") +
      keyButton("4") + keyButton("5") + keyButton("6") + keyButton("-", "−", "op") +
      keyButton("1") + keyButton("2") + keyButton("3") + keyButton("+", "+", "op") +
      keyButton("0", "0", "", true) + keyButton(".") + keyButton("=", "=", "action-equals") +
      "</div>";
    const pro =
      '<div class="ep-calc-grid-pro">' +
      ["sin", "cos", "tan", "log", "ln"].map((k) => keyButton(k, k, "fn")).join("") +
      keyButton("sqrt", "√", "fn") + keyButton("sqr", "x²", "fn") + keyButton("pow", "^", "fn") + keyButton("pi", "π", "fn") + keyButton("e", "e", "fn") +
      keyButton("(", "(", "fn") + keyButton(")", ")", "fn") + keyButton("inv", "1/x", "fn") + keyButton("abs", "abs", "fn") + keyButton("%", "%", "fn") +
      keyButton("C", "C", "action-clear") + keyButton("DEL", "DEL", "action-clear") + keyButton("±", "±", "op") + keyButton("/", "÷", "op") + keyButton("*", "×", "op") +
      keyButton("7") + keyButton("8") + keyButton("9") + keyButton("-", "−", "op") + keyButton("+", "+", "op") +
      keyButton("4") + keyButton("5") + keyButton("6") + keyButton("0") + keyButton(".") +
      keyButton("1") + keyButton("2") + keyButton("3") + keyButton("=", "=", "action-equals", true) +
      "</div>";
    panel.innerHTML =
      '<div class="ep-calc-header"><div style="display:flex;align-items:center;gap:6px;color:#0f172a;font-weight:700;font-size:12px;">' +
      ICON_CALC +
      "<span>" +
      (mode === "pro" ? "Scientific (Pro)" : "Basic") +
      ' Calculator</span></div><div style="display:flex;align-items:center;gap:8px;"><div class="ep-calc-tabs"><button type="button" class="ep-calc-tab-btn' +
      (mode === "basic" ? " active" : "") +
      '" data-calc-mode="basic">Basic</button><button type="button" class="ep-calc-tab-btn' +
      (mode === "pro" ? " active" : "") +
      '" data-calc-mode="pro">Pro</button></div><button type="button" data-calc-close aria-label="Close calculator" style="background:transparent;border:none;color:#64748b;cursor:pointer;padding:4px;display:flex;">' +
      ICON_X +
      '</button></div></div><div class="ep-calc-screen"><div class="ep-calc-history" id="ep-calc-hist-text"></div><div class="ep-calc-display" id="ep-calc-disp-text" aria-live="polite"></div></div><div class="ep-calc-body">' +
      (mode === "basic" ? basic : pro) +
      "</div>";
    panel.querySelector("#ep-calc-hist-text").textContent = history;
    panel.querySelector("#ep-calc-disp-text").textContent = current;
    panel.dataset.mode = mode;
  }

  function panelNode() {
    let panel = document.getElementById("ep-calc-widget");
    if (!panel) {
      panel = document.createElement("div");
      panel.id = "ep-calc-widget";
      panel.setAttribute("role", "dialog");
      panel.setAttribute("aria-label", "Calculator");
      panel.addEventListener("click", (ev) => {
        const target = ev.target.closest("button");
        if (!target) return;
        if (target.dataset.k !== undefined) key(target.dataset.k);
        else if (target.dataset.calcMode) {
          mode = target.dataset.calcMode;
          draw(panel);
        } else if ("calcClose" in target.dataset) close();
      });
      document.body.appendChild(panel);
    }
    return panel;
  }
  function close() {
    const panel = document.getElementById("ep-calc-widget");
    if (panel) panel.style.display = "none";
    open = false;
  }
  function toggle(wanted) {
    const panel = panelNode();
    if (open && (!wanted || panel.dataset.mode === wanted)) return close();
    if (wanted) mode = wanted;
    open = true;
    panel.style.display = "flex";
    draw(panel);
  }

  global.ExamCalculator = Object.freeze({ toggle, close, evaluate });
})(window);
