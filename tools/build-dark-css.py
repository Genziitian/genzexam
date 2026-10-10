#!/usr/bin/env python3
"""Build the dark-mode stylesheets for Quiz Lab.

The site's styles are written for light mode with fixed colours (a compiled
Tailwind bundle plus hand-written CSS and inline styles in template strings).
This script reads those sources and writes, for every rule that sets a colour,
a matching rule under :root[data-theme=dark] with the colour remapped.

Run it from the repo root after changing any stylesheet it reads:

    python3 tools/build-dark-css.py

Hand-written fixes live in tools/dark-extra/<name>.css and are appended last.
"""
import colorsys
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DARK = ':root[data-theme=dark]'


def index_assets():
    html = open(os.path.join(ROOT, 'index.html')).read()
    css = re.search(r'href="/(assets/index-[\w-]+\.css)(?:\?[^"]*)?"', html).group(1)
    js = re.search(r'src="/(assets/index-[\w-]+\.js)(?:\?[^"]*)?"', html).group(1)
    return css, js


INDEX_CSS, INDEX_JS = index_assets()

# output file -> (stylesheets, scripts whose inline style="" attributes are covered, options)
TARGETS = {
    'ql-dark-app.css': dict(
        # ql-redesign.css comes last so its dark variants are emitted last and
        # therefore beat the bundle's own (still green) generated rules.
        css=[INDEX_CSS, 'assets/ql-theme.css', 'storefront-dashboard.css', 'ql-redesign.css'],
        js=['app-enhancements.js'],
        bundle=[INDEX_JS],
    ),
    'ql-dark-exam.css': dict(
        css=['exam-platform.css', 'paper-room.css'],
        js=['exam-platform.js', 'paper-room.js', 'exam-calculator.js'],
    ),
    'ql-dark-sales.css': dict(
        css=['manager-sales.css'], js=[],
        grey_hue=222,
        vars={'--green': '#6d93cf', '--danger': '#e58a80'},
        on_accent={'--green': '#0b1222'},
    ),
    'ql-dark-discussions.css': dict(
        css=['manager-discussions.css'], js=[],
    ),
}

COLOR_RE = re.compile(
    r'#[0-9a-fA-F]{3,8}(?![0-9a-zA-Z_-])'
    r'|rgba?\((?:[^()]|\([^()]*\))*\)'
    r'|(?<![-\w])(?:white|black)(?![-\w(])'
)

BG_PROPS = ('background', 'background-color', 'background-image', '--tw-ring-offset-color')
TEXT_PROPS = ('color', 'caret-color', '-webkit-text-fill-color',
              'text-decoration-color')
BORDER_PROPS = ('outline', 'outline-color', '--tw-ring-color', 'column-rule', 'column-rule-color')


def role_of(prop):
    p = prop.lower()
    if p in BG_PROPS or p.startswith('--tw-gradient-'):
        return 'bg'
    if p in TEXT_PROPS:
        return 'text'
    if p in ('fill', 'stroke'):
        return 'svg'
    if p in BORDER_PROPS or (p.startswith('border') and 'radius' not in p and 'spacing' not in p
                             and 'collapse' not in p and 'width' not in p and 'style' not in p):
        return 'border'
    return None


def var_role(name):
    n = name.lower()
    if n in ('--bg', '--page'):
        return 'page'
    if re.search(r'bg|surface|card|raised|tint|soft|paper', n):
        return 'bg'
    if re.search(r'ink|text|muted', n):
        return 'text'
    if re.search(r'border|line', n):
        return 'border'
    return None


def parse_color(tok):
    """-> (r, g, b, alpha_text or None) with r/g/b in 0..255, or None."""
    t = tok.strip()
    if t.lower() == 'white':
        return 255, 255, 255, None
    if t.lower() == 'black':
        return 0, 0, 0, None
    if t.startswith('#'):
        h = t[1:]
        if len(h) in (3, 4):
            h = ''.join(c * 2 for c in h)
        if len(h) not in (6, 8):
            return None
        r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
        a = None
        if len(h) == 8:
            a = ('%.3f' % (int(h[6:8], 16) / 255)).rstrip('0').rstrip('.')
        return r, g, b, a
    m = re.match(r'rgba?\((.*)\)$', t, re.S)
    if not m:
        return None
    body = m.group(1).strip()
    alpha = None
    if '/' in body:
        body, alpha = body.split('/', 1)
        alpha = alpha.strip()
    parts = [p for p in re.split(r'[\s,]+', body.strip()) if p]
    if alpha is None and len(parts) == 4:
        alpha = parts.pop()
    if len(parts) != 3:
        return None
    try:
        vals = []
        for p in parts:
            vals.append(float(p[:-1]) * 2.55 if p.endswith('%') else float(p))
    except ValueError:
        return None
    return vals[0], vals[1], vals[2], alpha


def fmt(rgb, alpha):
    r, g, b = [max(0, min(255, int(round(v * 255)))) for v in rgb]
    if alpha is None:
        return '#%02x%02x%02x' % (r, g, b)
    return 'rgb(%d %d %d/%s)' % (r, g, b, alpha)


GREY_HUE = 222          # hue given to pure greys and white; set per target
ALWAYS_DARK = re.compile(r'ql-sidebar|ql-home-link|ql-nav|ql-login-banner|ql-modal(?!-)|\\\[\\#|\.ep-(side|brand)')
PAGE_SELECTORS = re.compile(r'^((body|html)(?![\w-]).*|#ep-app|\.bg-surface|\.ep-shell|\.bg-\\\[\\#f1f5f9\\\])$')


def is_slate(h):
    return 195 <= h <= 255


def surface_sat(h, c):
    if is_slate(h):
        return min(0.34, 0.27 + c * 0.6)
    return min(0.5, 0.07 + c * 2.4)


def text_lightness(h):
    """Readable lightness for coloured text on a dark surface, by hue (degrees)."""
    if h < 20 or h >= 330:
        return 0.70, 0.85     # red, rose
    if h < 70:
        return 0.60, 0.85     # orange, amber
    if h < 180:
        return 0.56, 0.62     # green, teal
    if h < 215:
        return 0.62, 0.75     # cyan, sky
    if h < 260:
        return 0.72, 0.85     # blue, indigo
    return 0.76, 0.85         # violet, pink


def is_neutral(r, g, b):
    """Greys and the blue-grey slate family (r/g/b 0..1)."""
    c = max(r, g, b) - min(r, g, b)
    if c < 0.1:
        return True
    return c < 0.17 and is_slate(colorsys.rgb_to_hls(r, g, b)[0] * 360)


def is_light_surface(r, g, b):
    """True for backgrounds that dark mode turns into a dark surface (r/g/b 0..255)."""
    r, g, b = r / 255, g / 255, b / 255
    l = (max(r, g, b) + min(r, g, b)) / 2
    c = max(r, g, b) - min(r, g, b)
    if is_neutral(r, g, b):
        return l >= 0.78
    return l >= 0.6 and not (c >= 0.35 and l < 0.82)


def remap(role, r, g, b):
    """-> new (r,g,b) floats 0..1, or None to keep the colour."""
    light = is_light_surface(r, g, b)
    if role == 'svg':       # chart tracks and grid lines are light, icons and labels dark
        role = 'border' if light else 'text'
    r, g, b = r / 255, g / 255, b / 255
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    hd = h * 360
    c = max(r, g, b) - min(r, g, b)
    if c < 0.012:           # pure grey: lean on the hue the page's surfaces use
        h, hd = GREY_HUE / 360, GREY_HUE
    if role == 'page':      # the page behind the cards is the darkest surface
        if not light:
            return None
        return colorsys.hls_to_rgb(h, 0.07, surface_sat(hd, c))
    if role == 'bg':
        if light:
            if is_neutral(r, g, b):
                lo = min(0.36, 0.115 + (1 - l) * 1.05)
            else:
                lo = 0.15 + (1 - l) * 0.7
            return colorsys.hls_to_rgb(h, lo, surface_sat(hd, c))
        if l < 0.2 and c < 0.2:         # near-black buttons would vanish: lift them
            return colorsys.hls_to_rgb(h, 0.24, min(s, 0.34))
        return None
    if role == 'text':
        if l > 0.52:
            return None
        if c < 0.2:
            return colorsys.hls_to_rgb(h, 0.93 - l * 0.55, min(s, 0.22))
        base, cap = text_lightness(hd)
        return colorsys.hls_to_rgb(h, base + (0.5 - l) * 0.12, min(s, cap))
    if role == 'border':
        if l >= 0.6:
            if is_neutral(r, g, b):
                return colorsys.hls_to_rgb(h, 0.17 + (1 - l) * 0.8, surface_sat(hd, c) * 0.8)
            if c >= 0.35 and l < 0.65:
                return None
            return colorsys.hls_to_rgb(h, 0.32, min(s, 0.45))
        if l < 0.3 and c < 0.2:
            return colorsys.hls_to_rgb(h, 0.58, min(s, 0.2))
        return None
    return None


def bg_is_kept(value):
    """True when a background value holds a solid colour that stays a colour in dark mode."""
    kept = False
    for tok in COLOR_RE.findall(value):
        p = parse_color(tok)
        if not p:
            continue
        if p[3] is not None:
            try:
                if float(p[3]) < 0.5:
                    continue
            except ValueError:
                pass
        if is_light_surface(*p[:3]):
            return False
        kept = True
    return kept


def convert(value, role):
    changed = False

    def sub(m):
        nonlocal changed
        p = parse_color(m.group(0))
        if not p:
            return m.group(0)
        new = remap(role, *p[:3])
        if new is None:
            return m.group(0)
        if role == 'bg' and p[3] is not None and not is_light_surface(*p[:3]):
            return m.group(0)       # translucent dark overlays stay as they are
        changed = True
        return fmt(new, p[3])

    out = COLOR_RE.sub(sub, value)
    return out if changed else None


SHORTHAND_BORDERS = {'border', 'border-top', 'border-right', 'border-bottom', 'border-left',
                     'border-block', 'border-inline', 'border-block-start', 'border-block-end',
                     'border-inline-start', 'border-inline-end', 'outline', 'column-rule'}


def longhand(prop, value, new_value):
    """Override only the colour of a shorthand, so widths, clipping and images stay as written."""
    p = prop.lower()
    imp = '!important' if '!important' in value else ''
    core = new_value.replace('!important', '').strip()
    if p == 'background':
        if COLOR_RE.fullmatch(core):
            return 'background-color', core + imp
        if re.match(r'^(repeating-)?(linear|radial|conic)-gradient\(', core) and core.endswith(')') \
                and 'url(' not in core:
            return 'background-image', core + imp
    if p in SHORTHAND_BORDERS:
        toks = COLOR_RE.findall(core)
        if len(toks) == 1:
            return p + '-color', toks[0] + imp
    return prop, new_value


# ---------------------------------------------------------------- CSS parsing
def strip_comments(css):
    return re.sub(r'/\*.*?\*/', '', css, flags=re.S)


def parse_blocks(css, i=0):
    """Tiny CSS parser -> list of ('rule', selector, decl_text) / ('at', prelude, children)."""
    out = []
    n = len(css)
    while i < n:
        j = i
        depth_paren = 0
        while j < n:
            ch = css[j]
            if ch == '(':
                depth_paren += 1
            elif ch == ')':
                depth_paren -= 1
            elif ch in '{};' and depth_paren <= 0:
                break
            elif ch in '"\'':
                k = css.find(ch, j + 1)
                j = n if k < 0 else k
            j += 1
        if j >= n:
            break
        ch = css[j]
        prelude = css[i:j].strip()
        if ch == '}':
            return out, j + 1
        if ch == ';':
            i = j + 1
            continue
        if prelude.startswith('@') and re.match(r'@(media|supports|layer|container)\b', prelude):
            children, i = parse_blocks(css, j + 1)
            out.append(('at', prelude, children))
            continue
        # plain block: find its end (no nesting expected, but stay balanced)
        depth, k = 1, j + 1
        while k < n and depth:
            if css[k] == '{':
                depth += 1
            elif css[k] == '}':
                depth -= 1
            k += 1
        body = css[j + 1:k - 1]
        if not prelude.startswith('@'):
            out.append(('rule', prelude, body))
        i = k
    return out, i


def split_decls(body):
    decls, buf, depth = [], '', 0
    for ch in body:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
        if ch == ';' and depth <= 0:
            decls.append(buf)
            buf = ''
        else:
            buf += ch
    decls.append(buf)
    res = []
    for d in decls:
        if ':' in d:
            p, v = d.split(':', 1)
            res.append((p.strip(), v.strip()))
    return res


def split_selectors(sel):
    parts, buf, depth = [], '', 0
    for ch in sel:
        if ch in '([':
            depth += 1
        elif ch in ')]':
            depth -= 1
        if ch == ',' and depth <= 0:
            parts.append(buf.strip())
            buf = ''
        else:
            buf += ch
    parts.append(buf.strip())
    return [p for p in parts if p]


def darken_selector(sel):
    out = []
    for s in split_selectors(sel):
        m = re.match(r'(:root|html)(?![\w-])', s)
        if m:
            out.append(DARK + s[m.end():])
        else:
            out.append(DARK + ' ' + s)
    return ','.join(out)


def convert_rule(sel, body, opts):
    decls = split_decls(body)
    is_root = any(re.match(r'(:root|html)\s*$', s) for s in split_selectors(sel))
    is_page = any(PAGE_SELECTORS.match(x) for x in split_selectors(sel))
    keep_text = any(role_of(p) == 'bg' and not p.startswith('--') and bg_is_kept(v) for p, v in decls)
    out = []
    changed = False
    accent_on = None
    for p, v in decls:
        if role_of(p) == 'bg':
            for var, on in opts.get('on_accent', {}).items():
                if 'var(%s)' % var in v:
                    accent_on = on
    for p, v in decls:
        if p.startswith('--') and not p.startswith('--tw-'):
            if p in opts.get('vars', {}):
                out.append((p, opts['vars'][p]))
                continue
            role = var_role(p) if is_root else None
        else:
            role = role_of(p)
        if role is None:
            continue
        if role == 'bg' and is_page:
            role = 'page'
        new = None
        plain = v.replace('!important', '').strip()
        if role == 'text' and accent_on and parse_color(plain) and parse_color(plain)[:3] == (255, 255, 255):
            out.append((p, accent_on))
            continue
        leave = False
        if role in ('border', 'bg') and ALWAYS_DARK.search(sel):
            # Parts designed dark in both modes (sidebar, login banner). Their
            # surfaces are left exactly as written, including translucent white
            # overlays drawn on top of them, which would otherwise be inverted
            # into dark-on-dark and disappear.
            leave = True
        if role in ('text', 'border', 'svg') and keep_text:
            leave = True        # sits on a colour that stays, so it stays too
        if not leave:
            new = convert(v, role)
        if new is not None:
            out.append(longhand(p, v, new))
        elif not p.startswith('--') and (p.lower() not in SHORTHAND_BORDERS or COLOR_RE.search(v)):
            # Unchanged colours are repeated so a variant such as .btn.primary still
            # wins over the dark version of .btn, exactly as it does in light mode.
            out.append(longhand(p, v, v))
    if not out:
        return ''
    return '%s{%s}' % (darken_selector(sel), ';'.join('%s:%s' % d for d in out))


def convert_blocks(blocks, opts):
    out = []
    for b in blocks:
        if b[0] == 'rule':
            r = convert_rule(b[1], b[2], opts)
            if r:
                out.append(r)
        else:
            inner = convert_blocks(b[2], opts)
            if inner:
                out.append('%s{%s}' % (b[1], '\n'.join(inner)))
    return out


# ------------------------------------------------- inline style="" attributes
HEX_IN_JS = re.compile(r'#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-zA-Z])')


def inline_rules(js_text, seen):
    """Scripts build style="" attributes from colour literals, sometimes picked at run time
    (checked ? "#f0fdf4" : "#ffffff"). Cover every literal for each way it can be used."""
    toks = []
    for tok in HEX_IN_JS.findall(js_text):
        if tok.lower() not in seen:
            seen.add(tok.lower())
            toks.append(tok)
    out = []
    for tok in sorted(toks, key=len):       # #fff before #fff7ed, so the longer match wins
        p = parse_color(tok)
        ser = serialized(tok)       # the form the browser keeps once a script edits the style
        new = remap('bg', *p[:3])
        if new is not None:
            sels = ['[style*="background:%s"]' % tok, '[style*="background: %s"]' % tok,
                    '[style*="background-color:%s"]' % tok, '[style*="background: %s"]' % ser,
                    '[style*="background-color: %s"]' % ser]
            out.append('%s{background-color:%s!important}'
                       % (','.join(DARK + ' ' + x for x in sels), fmt(new, None)))
        new = remap('text', *p[:3])
        if new is not None:
            sels = ['[style*="color:%s"]' % tok, '[style*="color: %s"]' % tok,
                    '[style*="color: %s"]' % ser]
            out.append('%s{color:%s!important}'
                       % (','.join(DARK + ' ' + x for x in sels), fmt(new, None)))
        new = remap('border', *p[:3])
        if new is not None:
            sels = ['[style*="solid %s"]' % tok, '[style*="dashed %s"]' % tok,
                    '[style*="border-color:%s"]' % tok, '[style*="solid %s"]' % ser,
                    '[style*="dashed %s"]' % ser, '[style*="border-color: %s"]' % ser]
            out.append('%s{border-color:%s!important}'
                       % (','.join(DARK + ' ' + x for x in sels), fmt(new, None)))
    return out


STYLE_KEYS = {'background': 'bg', 'backgroundColor': 'bg', 'color': 'text',
              'border': 'border', 'borderTop': 'border', 'borderRight': 'border',
              'borderBottom': 'border', 'borderLeft': 'border', 'borderColor': 'border',
              'outline': 'border'}


def serialized(tok):
    """How the browser writes a colour back into a style attribute."""
    t = tok.strip()
    if not t.startswith('#') and not t.startswith('rgb'):
        return t
    r, g, b, a = parse_color(t)
    if a is None:
        return 'rgb(%d, %d, %d)' % (r, g, b)
    return 'rgba(%d, %d, %d, %s)' % (r, g, b, '%g' % float(a))


def bundle_rules(js_text):
    """Colours the compiled app sets through React style objects and SVG attributes."""
    found = {}          # (role, token) in first-seen order
    for m in re.finditer(r'style:\{', js_text):
        i, depth = m.end(), 1
        while depth and i < len(js_text):
            depth += {'{': 1, '}': -1}.get(js_text[i], 0)
            i += 1
        span = js_text[m.end():i - 1]
        keys = [(k.start(), k.group(1)) for k in re.finditer(r'(?<![\w$.])([A-Za-z]+):', span)]
        for c in COLOR_RE.finditer(span):
            before = [k for k in keys if k[0] < c.start()]
            if not before:
                continue
            role = STYLE_KEYS.get(before[-1][1])
            if role and 'gradient' not in span[before[-1][0]:c.start()]:
                found.setdefault((role, c.group(0)), 1)
    out = []
    for role, tok in found:
        p = parse_color(tok)
        if not p:
            continue
        try:
            new = remap(role, *p[:3])
        except TypeError:
            continue
        if new is None or (role == 'bg' and p[3] is not None and not is_light_surface(*p[:3])):
            continue
        ser, val = serialized(tok), fmt(new, p[3])
        if role == 'bg':
            sels = ['[style*="background: %s"]' % ser, '[style*="background-color: %s"]' % ser]
            prop = 'background-color'
        elif role == 'text':
            sels = ['[style*=" color: %s"]' % ser, '[style^="color: %s"]' % ser]
            prop = 'color'
        else:
            sels = ['[style*="solid %s"]' % ser, '[style*="dashed %s"]' % ser,
                    '[style*="border-color: %s"]' % ser]
            prop = 'border-color'
        out.append('%s{%s:%s!important}' % (','.join(DARK + ' ' + x for x in sels), prop, val))
    svg = {}
    for m in re.finditer(r'(?<![\w$.])(stroke|fill):`(#[0-9a-fA-F]{3,8})`', js_text):
        svg.setdefault((m.group(1), m.group(2)), 1)
    for attr, tok in svg:
        p = parse_color(tok)
        r, g, b = [x / 255 for x in p[:3]]
        if not is_neutral(r, g, b):
            continue
        new = remap('border', *p[:3]) if is_light_surface(*p[:3]) else remap('text', *p[:3])
        if new is not None:
            out.append('%s [%s="%s"]{%s:%s}' % (DARK, attr, tok, attr, fmt(new, p[3])))
    return out


def build(name, cfg):
    global GREY_HUE
    GREY_HUE = cfg.get('grey_hue', 222)
    parts = ['/* Generated by tools/build-dark-css.py. Do not edit: change the sources or '
             'tools/dark-extra/%s and run the script again. */' % name]
    for path in cfg['css']:
        css = strip_comments(open(os.path.join(ROOT, path)).read())
        blocks, _ = parse_blocks(css)
        rules = convert_blocks(blocks, cfg)
        parts.append('/* from %s */' % path)
        parts.extend(rules)
    seen = set()
    for path in cfg['js']:
        rules = inline_rules(open(os.path.join(ROOT, path)).read(), seen)
        if rules:
            parts.append('/* inline styles in %s */' % path)
            parts.extend(rules)
    for path in cfg.get('bundle', []):
        parts.append('/* styles the app bundle sets inline */')
        parts.extend(bundle_rules(open(os.path.join(ROOT, path)).read()))
    extra = os.path.join(ROOT, 'tools', 'dark-extra', name)
    if os.path.exists(extra):
        parts.append('/* hand-written: tools/dark-extra/%s */' % name)
        parts.append(open(extra).read().strip())
    text = '\n'.join(parts) + '\n'
    open(os.path.join(ROOT, name), 'w').write(text)
    return len(text)


if __name__ == '__main__':
    for name, cfg in TARGETS.items():
        size = build(name, cfg)
        sys.stdout.write('%s  %d bytes\n' % (name, size))
