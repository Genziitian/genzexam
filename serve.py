#!/usr/bin/env python3
"""Local public-file preview. All exam APIs belong to authenticated Laravel."""
import http.server
import json
import mimetypes
import pathlib
import re
import sys
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parent
ROOT_FILES = set(('index.html exams.html ql-theme.js ql-dark-app.css ql-dark-exam.css ql-dark-sales.css ql-dark-discussions.css paper-room.html paper-room.js paper-room.css landing.html papers.html paper-pricing.html terms.html privacy.html delete-account.html refund-policy.html manager-sales.html manager-sales.js manager-sales.css manager-discussions.html manager-discussions.js manager-discussions.css exam-platform.js exam-rich-content.js exam-calculator.js '
    'exam-platform.css app-enhancements.js more-web.js storefront-runtime.js storefront-dashboard.css papers.js papers.css '
    'paper-pricing.js paper-pricing.css icons.svg site.webmanifest favicon.ico favicon-16x16.png favicon-32x32.png '
    'apple-touch-icon.png android-chrome-192x192.png android-chrome-512x512.png').split())
ASSET_EXTENSIONS = {'.html','.js','.css','.json','.png','.jpg','.jpeg','.webp','.svg','.ico','.woff','.woff2','.ttf','.webmanifest'}
APP_ROUTES = re.compile(r'^/(login|register|forgot-password|reset-password|dashboard|my-papers|practice|manager|admin|exams?|courses|quizzes|profile|leaderboard|discussions)(/[^.]*)?/?$')

class PublicHandler(http.server.BaseHTTPRequestHandler):
    def reply(self, code, body=b'', content_type='text/plain; charset=utf-8'):
        self.send_response(code)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'strict-origin-when-cross-origin')
        self.send_header('X-Frame-Options', 'SAMEORIGIN')
        self.end_headers()
        if self.command != 'HEAD': self.wfile.write(body)

    def dispatch(self):
        url = urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)
        if re.match(r'^/(public/)?api(/|$)', url):
            return self.reply(503, json.dumps({'message': 'The authenticated Laravel API must be running. This server only previews public pages.'}).encode(), 'application/json')
        if self.command not in ('GET', 'HEAD'): return self.reply(405)
        if any(part.startswith('.') or '\\' in part for part in url.split('/')) or '\x00' in url:
            return self.reply(404)
        name = url.lstrip('/')
        if url == '/': name = 'landing.html'
        elif url.rstrip('/') == '/papers': name = 'papers.html'
        elif re.fullmatch(r'/paper/\d+/?', url): name = 'paper-room.html'
        elif url.rstrip('/') == '/manager/sales': name = 'manager-sales.html'
        elif url.rstrip('/') == '/manager/discussions': name = 'manager-discussions.html'
        elif url.rstrip('/') == '/paper-pricing': name = 'paper-pricing.html'
        elif url.rstrip('/') == '/privacy-policy': name = 'privacy.html'
        elif url.rstrip('/') == '/terms-and-conditions': name = 'terms.html'
        elif url.rstrip('/') == '/refund-policy': name = 'refund-policy.html'
        elif url.rstrip('/') == '/delete-account': name = 'delete-account.html'
        elif re.fullmatch(r'/exams?(/[^.]*)?/?', url): name = 'exams.html'
        elif APP_ROUTES.fullmatch(url): name = 'index.html'
        asset = name.startswith('assets/') and pathlib.Path(name).suffix.lower() in ASSET_EXTENSIONS and not name.endswith('package.json')
        if not (name in ROOT_FILES or asset or re.fullmatch(r'templates/[\w-]+\.json', name)): return self.reply(404)
        file = (ROOT / name).resolve()
        if ROOT not in file.parents or not file.is_file(): return self.reply(404)
        kind = mimetypes.guess_type(str(file))[0] or 'application/octet-stream'
        if file.suffix == '.js': kind = 'text/javascript; charset=utf-8'
        return self.reply(200, file.read_bytes(), kind)

    do_GET = dispatch
    do_HEAD = dispatch
    do_POST = dispatch
    do_PUT = dispatch
    do_PATCH = dispatch
    do_DELETE = dispatch

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    print(f'Static preview: http://127.0.0.1:{port}; exams require Laravel.', flush=True)
    http.server.ThreadingHTTPServer(('127.0.0.1', port), PublicHandler).serve_forever()
