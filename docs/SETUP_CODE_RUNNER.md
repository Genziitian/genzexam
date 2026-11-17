# Setup your own code runner (Piston) – free

Why: the free public runner (emkc.org) now blocks everyone, so "Run Code" shows
"Execution service unavailable". We run our own copy instead.

## What you need
A small **VPS** (Linux Ubuntu, 2 GB RAM or more). Hostinger *shared hosting* can NOT do this;
the VPS plan can (cheapest one is enough). Do NOT put it on the same machine as your website database.

## Step 1 – Install Docker (on the VPS, copy-paste)
```bash
curl -fsSL https://get.docker.com | sh
```

## Step 2 – Start Piston
```bash
docker run -d --name piston --restart always --privileged \
  -p 127.0.0.1:2000:2000 \
  -v piston_data:/piston \
  ghcr.io/engineer-man/piston
```

## Step 3 – Install Python, Java, C++ into it
```bash
git clone https://github.com/engineer-man/piston /opt/piston-cli
cd /opt/piston-cli/cli && npm install
node index.js -u http://127.0.0.1:2000 ppman install python 3.10.0
node index.js -u http://127.0.0.1:2000 ppman install java 15.0.2
node index.js -u http://127.0.0.1:2000 ppman install gcc 10.2.0
```
(If `npm` is missing: `apt install -y nodejs npm git`.)

## Step 4 – Test on the VPS
```bash
curl -s -X POST http://127.0.0.1:2000/api/v2/execute -H 'content-type: application/json' \
  -d '{"language":"python","version":"3.10.0","files":[{"content":"print(1+1)"}]}'
```
You should see `"stdout":"2\n"`.

## Step 5 – Let the website reach it (safely)
Piston has no password. Never open port 2000 to everyone. Put it behind HTTPS with a secret key:
install Caddy/nginx on the VPS, proxy `https://runner.genziitian.in` -> `127.0.0.1:2000`,
and only allow requests that carry the header `X-Runner-Key: <long random secret>`.
(Or: firewall port 2000 so only your website server's IP can connect.)

## Step 6 – Point the website to it
In the production `backend/.env` change:
```
PISTON_API_URL=https://runner.genziitian.in/api/v2
```
then run `php artisan config:clear`.

## Note
If you use the secret-header option, tell me and I'll add the header to
`CodeExecutionService.php` (one line).
