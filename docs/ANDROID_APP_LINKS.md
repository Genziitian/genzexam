# Android App Links website verification

Prepared for review on 18 October 2026. No commit, push or deployment was performed.

## Website statement

- Host: `quiz.genziitian.in`, inferred from the project's website references.
- Public URL: `https://quiz.genziitian.in/.well-known/assetlinks.json`.
- Package: `in.genziitian.quizlab`, confirmed in `mobile/android/app/build.gradle`.
- Relation: `delegate_permission/common.handle_all_urls`.
- Namespace: `android_app`.
- The JSON includes the three unique SHA-256 fingerprints supplied by the owner, with the current fingerprint first. The repeated current fingerprint was removed. These are treated as the installed-app signing fingerprints as requested; their Play Console certificate provenance has not been independently checked. Do not substitute an upload-key fingerprint.

There was no existing local `assetlinks.json`. The live URL returned HTTP 403, so a hosted statement, if present behind the access block, could not be inspected. Before replacing a hosted file, inspect it through the hosting file manager and preserve every existing valid statement by merging the new association. Do not overwrite an unseen hosted file.

## Exact change scope

1. `.well-known/assetlinks.json`: public association with all three fingerprints.
2. `.htaccess`: allow only this exact hidden path before the hidden-path denial; explicitly serve `assetlinks.json` as `application/json`.
3. `server.js`: permit the exact path in the Node local preview.
4. `serve.py`: permit the exact path in the Python local preview.
5. `docs/ANDROID_APP_LINKS.md`: this review and deployment guide.

Other hidden paths remain denied. The application code and Android manifest are not changed by this task.

## Local validation

Passed checks:

- JSON parses and contains the expected package, namespace, relation and three unique, correctly formatted fingerprints.
- JavaScript and Python syntax checks pass.
- A temporary Apache server using the updated `.htaccess` and JSON returns HTTP 200 over HTTPS, with certificate verification using a temporary local CA, `Content-Type: application/json`, the exact JSON body, no Location header and no authentication challenge.
- Node and Python local previews return the same HTTP 200 JSON over local HTTP.
- GET, HEAD and a query-string request succeed on each server. HEAD has no response body.
- `/.env`, `/.git/config`, `/.well-known/private.json`, a child path under `assetlinks.json` and a traversal path remain blocked on each server.
- The scoped diff has no whitespace errors.

The Apache HTTPS test used a temporary isolated document root, not production hosting. It does not prove Hostinger/CDN behavior after upload.

## Commit and push only the reviewed task changes

Review these five paths, then stage only them; do not use `git add .` or include other workspace edits:

```sh
git add -- .htaccess .well-known/assetlinks.json server.js serve.py docs/ANDROID_APP_LINKS.md
git diff --cached --stat
git diff --cached
git commit -m "Configure Android App Links website association"
```

Push that reviewed commit to the intended website deployment branch. Check that pushing the branch will not publish other unreviewed commits or trigger an unrelated release. No push has been performed here.

## Deploy after review

1. In the hosting configuration, confirm the website document root for `quiz.genziitian.in`. Use the directory containing the deployed `landing.html` and root `.htaccess`, commonly that domain's `public_html`. This is the website host, not `labapi.genziitian.in` or Laravel's `backend/public` directory.
2. Back up the deployed `.htaccess` and inspect any existing `.well-known/assetlinks.json` using the hosting file manager, with hidden files visible. Merge valid hosted statements if needed. Apply the six-line App Links block from this patch before the hidden-path denial in the deployed `.htaccess`; preserve other deployed server rules.
3. Upload the reviewed JSON as `<website-document-root>/.well-known/assetlinks.json`. Do not accidentally upload it as `.well-known/assetlinks.json.txt`. Only this JSON and the scoped `.htaccess` change are needed on the Apache-compatible website host. The preview scripts and this guide need not be publicly deployed.
4. Keep the endpoint public, without password protection or HTTPS-to-other-host redirects. If hosting or CDN rules still block the exact URL, allow it there too. Purge the endpoint's cached 403 response if necessary.
5. Validate the live response below. A local result is not deployment verification.

## Required live check after deployment

Run an unauthenticated HTTPS GET with TLS verification enabled and without following redirects:

```sh
curl --max-time 30 --silent --show-error \
  --dump-header /tmp/quizlab-assetlinks-headers.txt \
  --output /tmp/quizlab-assetlinks.json \
  --write-out 'HTTP %{http_code}\nContent-Type %{content_type}\nRedirect %{redirect_url}\nTLS verify %{ssl_verify_result}\n' \
  https://quiz.genziitian.in/.well-known/assetlinks.json
python3 -m json.tool /tmp/quizlab-assetlinks.json
```

Require HTTP 200, `application/json`, no redirect, TLS verification result 0 and no authentication requirement. Inspect the parsed JSON for the exact package and all three supplied fingerprints, plus any preserved valid statements. Check the response headers for a Location header or authentication challenge. Do not use `curl -L` or `curl -k` to bypass a failure.

Observed before deployment: HTTP 403, `Content-Type: text/html`, no redirect, TLS verification result 0. Post-deployment verification remains pending because publication has not been authorized/performed.

## Separate Android app update

The app source is available. `mobile/android/app/src/main/AndroidManifest.xml` has no verified App Links intent filter and no `android:host` for `quiz.genziitian.in`. The VIEW/HTTPS entry under `<queries>` is package visibility configuration, not an inbound App Links declaration.

An Android release must add an appropriate exported-activity VIEW intent filter with DEFAULT and BROWSABLE categories, `android:autoVerify="true"`, and the exact host `quiz.genziitian.in` with the appropriate HTTP/HTTPS schemes and supported paths. The Flutter app must handle incoming URLs and navigate to the intended content, including links received while already running and links requiring sign-in. Its current `MaterialApp` uses `home: AppRouter(...)`; this website patch does not implement URL routing.

Build and release that Android update separately, then test domain verification and actual link navigation on an installed app signed with a listed certificate. Website verification alone does not make links open the right in-app screen.

Reference: [Android Developers: configure website associations](https://developer.android.com/training/app-links/configure-assetlinks).
