(function (global) {
  "use strict";

  const MAX_CONTENT_LENGTH = 20000;
  const MAX_BLOCKS = 100;
  const MAX_MATH_LENGTH = 4000;

  function escapeHtml(value) {
    return String(value).replace(
      /[&<>"']/g,
      (char) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[char],
    );
  }

  function safeLanguage(value) {
    const language = String(value || "text");
    return /^[a-zA-Z0-9_+.-]{1,32}$/.test(language)
      ? language.toLowerCase()
      : "text";
  }

  function safeImageUrl(value) {
    if (
      typeof value !== "string" ||
      value.length > 2048 ||
      /[\u0000-\u0020\\]/.test(value)
    )
      return null;
    if (
      /^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/.test(value) &&
      !value.includes("..")
    )
      value = "/uploads/" + value;
    if (/^https:\/\//i.test(value)) {
      try {
        const url = new URL(value);
        return url.protocol === "https:" &&
          !url.username &&
          !url.password &&
          !/\.svg$/i.test(url.pathname)
          ? url.href
          : null;
      } catch (_) {
        return null;
      }
    }
    if (
      /^\/(storage|uploads|assets\/exam-examples)\//.test(value) &&
      !/^\/\//.test(value) &&
      !/(^|\/)\.\.(\/|$)/.test(decodeURIComponentSafe(value)) &&
      !/[?#%]/.test(value) &&
      !/\.svg$/i.test(value)
    ) {
      return value;
    }
    return null;
  }

  function decodeURIComponentSafe(value) {
    try {
      return decodeURIComponent(value);
    } catch (_) {
      return value;
    }
  }

  function renderInline(text) {
    // Split math before escaping and applying the small Markdown subset. Raw HTML
    // is always escaped; only the fixed tags below can enter the returned HTML.
    const parts = String(text)
      .slice(0, MAX_CONTENT_LENGTH)
      .split(
        /(\$\$[\s\S]*?\$\$|\\\[[\s\S]*?\\\]|\\\([\s\S]*?\\\)|\$(?!\$)[^\n$]+\$)/g,
      );
    return parts
      .map((part) => {
        let display = false;
        let tex = part;
        if (part.startsWith("$$") && part.endsWith("$$")) {
          display = true;
          tex = part.slice(2, -2);
        } else if (part.startsWith("\\[") && part.endsWith("\\]")) {
          display = true;
          tex = part.slice(2, -2);
        } else if (part.startsWith("\\(") && part.endsWith("\\)")) {
          tex = part.slice(2, -2);
        } else if (
          part.startsWith("$") &&
          part.endsWith("$") &&
          part.length > 2
        ) {
          tex = part.slice(1, -1);
        } else {
          let html = escapeHtml(part);
          html = html.replace(/`([^`\n]{1,500})`/g, "<code>$1</code>");
          html = html.replace(
            /\*\*([^*\n][\s\S]*?)\*\*/g,
            "<strong>$1</strong>",
          );
          html = html.replace(
            /(^|[^*])\*([^*\n][^*]*?)\*(?!\*)/g,
            "$1<em>$2</em>",
          );
          return html.replace(/\r?\n/g, "<br>");
        }
        if (tex.length > MAX_MATH_LENGTH) return escapeHtml(part);
        return (
          '<span class="exam-math" data-exam-tex="' +
          escapeHtml(tex) +
          '" data-exam-display="' +
          (display ? "true" : "false") +
          '">' +
          escapeHtml(tex) +
          "</span>"
        );
      })
      .join("");
  }

  function renderText(text) {
    const source = String(text).slice(0, MAX_CONTENT_LENGTH);
    const fence = /```([a-zA-Z0-9_+.-]{0,32})\r?\n([\s\S]*?)```/g;
    let result = "";
    let last = 0;
    let match;
    while ((match = fence.exec(source)) !== null) {
      result += renderInline(source.slice(last, match.index));
      result +=
        '<pre class="exam-code"><code class="language-' +
        safeLanguage(match[1] || "text") +
        '">' +
        escapeHtml(match[2]) +
        "</code></pre>";
      last = fence.lastIndex;
    }
    return result + renderInline(source.slice(last));
  }

  function toBlocks(content) {
    if (typeof content === "string") return [{ kind: "text", value: content }];
    if (!Array.isArray(content))
      return content && typeof content === "object" ? [content] : [];
    return content
      .slice(0, MAX_BLOCKS)
      .map((block) =>
        typeof block === "string" ? { kind: "text", value: block } : block,
      );
  }

  function renderBlock(block) {
    if (!block || typeof block !== "object") return "";
    const kind = String(block.kind || block.type || "text").toLowerCase();
    if (kind === "text")
      return (
        '<div class="exam-rich-text">' +
        renderText(block.value || "") +
        "</div>"
      );
    if (kind === "math") {
      const value = String(block.value || "").slice(0, MAX_MATH_LENGTH);
      return (
        '<div class="exam-math-block exam-math" data-exam-tex="' +
        escapeHtml(value) +
        '" data-exam-display="' +
        (block.display ? "true" : "false") +
        '">' +
        escapeHtml(value) +
        "</div>"
      );
    }
    if (kind === "code") {
      return (
        '<pre class="exam-code"><code class="language-' +
        safeLanguage(block.language) +
        '">' +
        escapeHtml(String(block.value || "").slice(0, MAX_CONTENT_LENGTH)) +
        "</code></pre>"
      );
    }
    if (kind === "image") {
      const url = safeImageUrl(block.url || block.asset);
      if (!url)
        return '<span class="exam-image-unavailable">Image unavailable</span>';
      const caption = block.caption
        ? "<figcaption>" + renderInline(block.caption) + "</figcaption>"
        : "";
      return (
        '<figure class="exam-rich-image"><img src="' +
        escapeHtml(url) +
        '" alt="' +
        escapeHtml(block.alt || "") +
        '" loading="lazy" referrerpolicy="no-referrer">' +
        caption +
        "</figure>"
      );
    }
    if (kind === "table") {
      const headers = Array.isArray(block.headers)
        ? block.headers.slice(0, 30)
        : [];
      const rows = Array.isArray(block.rows) ? block.rows.slice(0, 500) : [];
      if (!headers.length) return "";
      const head = headers
        .map((cell) => '<th scope="col">' + renderInline(cell) + "</th>")
        .join("");
      const body = rows
        .map((row) => {
          if (!Array.isArray(row)) return "";
          return (
            "<tr>" +
            headers
              .map(
                (_, index) =>
                  "<td>" +
                  renderInline(row[index] == null ? "" : row[index]) +
                  "</td>",
              )
              .join("") +
            "</tr>"
          );
        })
        .join("");
      const caption = block.caption
        ? "<caption>" + renderInline(block.caption) + "</caption>"
        : "";
      return (
        '<div class="exam-table-scroll"><table class="exam-rich-table">' +
        caption +
        "<thead><tr>" +
        head +
        "</tr></thead><tbody>" +
        body +
        "</tbody></table></div>"
      );
    }
    return "";
  }

  function render(content) {
    return toBlocks(content).map(renderBlock).join("");
  }

  function typeset(container) {
    if (!container || typeof container.querySelectorAll !== "function") return;
    const katex = global.katex;
    container
      .querySelectorAll(".exam-math[data-exam-tex]")
      .forEach((element) => {
        const tex = element.getAttribute("data-exam-tex") || "";
        const displayMode =
          element.getAttribute("data-exam-display") === "true";
        if (
          tex.length > MAX_MATH_LENGTH ||
          !katex ||
          typeof katex.renderToString !== "function"
        ) {
          element.textContent = displayMode
            ? "$$" + tex + "$$"
            : "$" + tex + "$";
          element.classList.add("exam-math-fallback");
          return;
        }
        try {
          element.innerHTML = katex.renderToString(tex, {
            displayMode,
            throwOnError: true,
            trust: false,
            strict: "warn",
            maxExpand: 1000,
            maxSize: 20,
            output: "htmlAndMathml",
          });
          element.classList.remove("exam-math-fallback");
        } catch (_) {
          element.textContent = displayMode
            ? "$$" + tex + "$$"
            : "$" + tex + "$";
          element.classList.add("exam-math-fallback");
        }
      });
  }

  global.ExamRichContent = Object.freeze({ render, typeset });
})(window);
