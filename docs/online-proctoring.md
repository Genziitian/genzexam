# Online exams: operation and deployment

## What this release provides

Laptop/desktop browser access only. Phones and tablets are shown an unavailable message in the web interface. Device classification is a usability restriction, not a tamper-resistant security boundary.

Independent exams owned by their manager, enrollment by verified account email, immutable published questions, a server-controlled timer, pause/resume/extension, candidate answer autosave with revisions, submission, scoring, result publication, CSV exports, manager announcements, private candidate messages, browser-event warnings, session locking, and an audit history. Persistent exam data lives in Laravel database tables. The previous shared JSON/demo endpoints return HTTP 410; local preview servers cannot run exam APIs.

This is browser-event proctoring. It does **not** record camera/audio, verify identity, inspect other devices, or guarantee cheating prevention. Browser telemetry can be suppressed by a modified client. Treat warnings as evidence for a human review, not proof of misconduct. A camera or identity service would be a separate, consent-based integration.

## Manager: complete workflow

1. Sign in with an active, email-verified **manager** account and open `/exams`. Admin accounts retain their existing user/content privileges; only managers own proctored exams.
2. Select **Create exam**, enter title, subject, duration (1–600 minutes), warning limit (1–100), optional start time, and instructions. Save the draft. Scheduled time is an earliest permitted start; the manager starts the exam explicitly.
3. Download the JSON template. Upload a file or paste JSON, then **Preview JSON**. Review every formula, option, diagram and table. **Import all questions** validates the complete set on the server and replaces the draft’s question set atomically. Invalid imports leave saved questions intact. Use **Edit imported JSON** to revise a draft. See [question-import.md](question-import.md).
4. Enter candidate emails, one per line, and **Save enrollment**. This replaces the complete roster; an empty list clears it. Candidates may register later using that email, but must verify their email before access. Up to 1,000 emails can be enrolled per exam.
5. Review saved question keys and explanations, instructions and enrollment. **Publish exam** freezes configuration and questions. Enrollment remains editable until the exam starts. Copy the candidate link and distribute it through your usual channel.
6. Select the published exam and **Start exam** when its scheduled time has arrived. The shared clock begins now. Late joiners receive only the remaining time.
7. Monitor joined candidates, answered counts, warnings, status and last activity. Pause/resume affects everyone. Add 5 minutes as needed (API permits 1–180 per request, 600 total extension). Lock or unlock individual active sessions. Unlocking grants one additional warning before another automatic lock.
8. Open **Messages** for candidate requests. Manager messages are announcements to all enrolled candidates. Candidate messages are private to that candidate and the owning manager. Do not put individual student information in announcements.
9. **End exam** finalizes each active/locked session using its last server-saved answers. The server also finalizes expired exams. **Publish results** releases scores, answer keys and explanations to joined candidates. Export results to CSV; review recent audit events. CSV text is escaped to prevent spreadsheet formulas.
10. Archive ended exams to mark them complete. Archiving retains enrollment, answers, results, messages and audit records. Records remain accessible in the list. There is no destructive “reset all students” action.

## Candidate workflow

1. Sign in using the enrolled, verified email, open `/exams`, and select the exam or follow its shared link. Before the exam starts, questions are unavailable.
2. Read the instructions, monitoring disclosure and shared-clock rule. Accept the rules to join a live exam. The browser requests fullscreen when supported.
3. Answer questions. Single choice, multiple select, true/false, numerical answers and short text are supported; comprehension passages provide context. Clear an answer with **Clear answer**. Acknowledge the **Answers saved on server** status before leaving the page.
4. Interrupted saves show **Not saved** and retry when the connection returns. **Save now** retries immediately. Refresh recovers server-saved answers; unsaved edits cannot survive closing the browser. Different sessions use revision checks to avoid overwriting unrelated answers.
5. Focus/visibility/fullscreen exits generate warnings while the exam is live. The warning threshold locks the session for manager review. Paused and locked sessions cannot save or submit; the existing saved answers remain intact. Use Messages to contact the manager.
6. Submit once ready. Submission is irreversible and repeated requests are idempotent. At the deadline, the server finalizes saved answers even if the browser is closed. Scores and answer review remain hidden until the manager publishes them.

Short answers use trimmed, case-insensitive exact matches; they are not essay or symbolic algebra grading. Multi-select requires the exact set. Numerical questions support absolute tolerance. Blank questions earn zero. Wrong attempted questions incur the configured penalty and the overall score is floored at zero.

## Math and rich content

Local KaTeX 0.19.0 assets render inline/display LaTeX, fractions, roots, matrices, cases, aligned equations, sums, integrals, probability/statistics notation, and mhchem chemistry syntax. Text, code, accessible images and tables can be mixed in prompts, choices and explanations. There is no CDN dependency. Raw HTML is escaped; trusted HTML commands are disabled. Macro expansion and rendered size are bounded. Unsupported TeX stays visible as source instead of silently disappearing. This is mathematical LaTeX support, not a full TeX document compiler or support for arbitrary packages such as TikZ; use an image for such diagrams.

Online proctoring is available only through the laptop/desktop web room. The mobile application has no proctoring screen or API client. Managers use `/exams` in a desktop browser for setup, monitoring, exports and audit history.

## Deployment procedure

Deploy the backend and web assets together. This is a replacement of the old singleton protocol; old web caches and mobile APKs must be refreshed or updated.

1. Back up the production database and test a restore. Preserve the old private JSON state for operator reference if an earlier demo ran; it is not silently imported into the new exam tables. Do not perform this cutover during a live exam.
2. Use a supported PHP 8.2+ runtime with Laravel's extensions and PDO MySQL or PostgreSQL. The lockfile now uses Laravel 12.69.3 and patched dependencies. Review the broader application regression tests because the framework was upgraded from 11 for published security fixes. Reference: [Laravel 12 upgrade guide](https://laravel.com/docs/12.x/upgrade).
3. Install the committed lockfile with `composer install --no-dev --prefer-dist --optimize-autoloader` in `backend`. Never run dependency updates as part of production deployment. Run `composer audit --locked --no-dev` in the release pipeline.
4. Set `APP_ENV=production`, `APP_DEBUG=false`, a generated private `APP_KEY`, the real HTTPS `APP_URL`, database credentials, and a shared `CACHE_STORE=database` or `redis`. Cache is required for rate limits and the scheduler lock. Configure explicit `CORS_ALLOWED_ORIGINS` matching the actual frontend host(s). The existing runtime uses `https://labapi.genziitian.in/public/api`; if changing it, update `storefront-runtime.js` and the exam page CSP connect-src together. Do not put secrets in frontend files.
5. Review `php artisan migrate:status`, then run `php artisan migrate --force`. This release adds six `proctored_*` tables. If deploying only this feature into an already migrated installation, its migration is `2026_10_06_000001_create_proctored_exam_tables.php`. Then run `php artisan config:cache` and `php artisan route:cache`.
6. Install the Laravel scheduler on one host: `* * * * * cd /path/to/backend && php artisan schedule:run >> /path/to/private/scheduler.log 2>&1`. The exam finalizer runs every minute with an overlap lock. Monitor scheduler failures. Lazy deadline checks also prevent late saves between scheduled runs.
7. Run `php artisan proctored-exams:check`. It exits nonzero for unsafe environment settings, missing schema/cache, or a missing scheduler heartbeat. `--skip-scheduler` is only for the initial installation check. A pass is a configuration check, not a load test or production certification.
8. Serve Laravel from `backend/public` at the API host. Serve only public frontend artifacts at the frontend host. If using this repository's combined Apache setup, retain both `.htaccess` files and enable rewrite/headers modules. Do not expose backend source, `.env`, `.git`, `data`, tests or mobile source. The Node/Python scripts are loopback-only static previews and intentionally return 503 for APIs.
9. Use HTTPS, disable CDN/proxy caching for all authenticated API responses, and allow request bodies up to 5 MB at the web server/PHP layer (the API rejects larger requests). For MySQL, set `max_allowed_packet` above the largest import body with room for JSON overhead. Ensure uploaded diagrams are publicly readable only when intended; allow only image content in image upload locations and never execute uploaded scripts. API responses use private/no-store headers; the exam page restricts scripts and connections with a content security policy.
10. Run a staging manager/candidate rehearsal and load test for the intended concurrent candidate count on the deployment database. Monitor 5xx/429 responses, answer-save latency, database locks, scheduler heartbeat and backup success. Compact polling occurs every six seconds; provision workers/database connections accordingly. Rehearse offline recovery and timing with actual candidate browsers, fullscreen permissions and assistive technology.
11. Deploy the web assets without stale service-worker/CDN caches. Distribute the rebuilt mobile app to remove the old manager proctor cockpit from installed copies. Verify both a permitted account and an unenrolled account from the real HTTPS frontend before opening registration.

Retain exam records according to the institution's privacy and retention policy, with restricted database/backup access and encrypted storage. There is no public deletion endpoint. Account deletion is blocked when it would destroy exam records; deactivate accounts instead. Archival does not delete records. For incidents, pause/end the exam, preserve audit data, and communicate through the manager announcements. Roll back application code only before new exams begin, or retain the new protocol for active records; never roll back the exam migration against valuable submissions.

## Verification commands

From the repository root, after installing Composer development dependencies:

```sh
php backend/vendor/bin/phpunit -c backend/phpunit.xml
php tests/proctored_question_service_test.php
node tests/exam-rich-content.test.cjs
node tests/exam-static-security.cjs
```

For the real API/browser test, install Playwright 1.62.1 and Chromium as local development tools. Create a fresh temporary directory, never an application database:

```sh
export EXAM_BROWSER_TEST=1
export EXAM_TEST_DIR="$(mktemp -d)"
php tests/support/exam-browser-server.php
php -S 127.0.0.1:8137 tests/support/exam-browser-server.php
# In a second terminal with the same EXAM_TEST_DIR:
node tests/exam-device-gate.cjs
node tests/proctored-exam-browser.cjs
```

The test creates private temporary manager/candidate tokens and SQLite records, exercises real HTTP routes, and captures screenshots. Do not upload its tokens or database. The CI workflow runs backend/renderer/static checks and the browser journey; it never deploys. Local verification does not establish production MySQL/PostgreSQL concurrency behavior or load capacity.
