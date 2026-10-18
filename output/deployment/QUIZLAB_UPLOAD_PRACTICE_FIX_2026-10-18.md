# Upload a paper and Test yourself: current fix

Daily Rewards belongs to another ongoing task. This update does not replace its screens, controller or route registrations.

## Native app changes

Upload a paper now handles native picker cancellation, picker failures, repeated taps, and content-based files that have no ordinary local filesystem path. It checks the actual file size, enforces the existing 10 MB limit, validates the server's paper/quota responses, and handles the follow-up refresh after a successful or failed upload. The last successfully loaded paper list stays visible after a failed refresh, with its state explained.

Test yourself now surfaces failed quota requests and retries them, waits for a confirmed allowance before generation, refreshes courses and quota together, preserves valid selections, and checks quota after uncertain generation failures without resending the generation request. It remains a native Flutter screen with a single header.

## Backend conversion patch

`quizlab-upload-conversion-fix-2026-10-18.zip` contains only:

```
app/Services/DeepSeekQuizGenerator.php
```

A provider connection failure or timeout is now reported as a conversion-service failure. The previous handler could classify it as an unreadable/invalid PDF even when parsing had succeeded.

This patch has not been deployed. Compare and back up the current deployed service before replacing it. Extract into the existing Laravel backend directory so the file merges into `app/Services/`. The archive deliberately has no outer backend directory and contains no routes, `.env`, credentials, vendor files, storage or database files. No migration is required for this service-only change. Keep any hosting-specific source changes when reviewing the replacement. If production uses persistent PHP worker/opcode caches, reload the application through its normal deployment process after replacement.

The backend patch does not resolve a Hostinger CDN challenge, which happens before this code runs.

## Verified locally

- 23 Flutter checks passed: 8 upload transport/picker checks, 12 practice/quota checks, and 3 upload load/recovery checks.
- Scoped Flutter analysis passed for the changed Upload/Practice/shared API files and tests.
- 11 backend checks passed with 147 assertions: private practice generation/opening, shared quota behavior, JSON upload usage and provider connection/timeout handling. The provider responses in these checks are mocked; they do not spend real conversion credits.
- Android debug build installed and launched on emulator-5554.

Actual signed-in production PDF conversion and successful paper generation are still required after the hosting block is resolved. The checks above do not establish successful production behavior.

## Current hosting evidence

The running app recorded HTML 403 responses from Hostinger for courses, practice quota and uploaded papers, including this authenticated Uploads request:

- 18 October 2026, 14:35:43 IST
- GET `https://labapi.genziitian.in/public/api/student/uploaded-papers`
- status 403, content-type `text/html`
- `x-hcdn-request-id`: `ecb456ee89faf30f5faba5639370943d-mum-edge6`

The app also recorded an HTML 403 at 14:36:44 IST for `/public/api/student/dashboard`, request ID `8a94eb54b41587ea0ed1f58564c99492-mum-edge6`.

Public requests without a login token at about 14:36 IST reached Laravel and returned JSON 401 for courses, uploaded papers and practice quota. This is expected without a token and does not prove authenticated app requests succeed. No login tokens were copied or logged.

The owner showed Hostinger security level “Essentially off” and then changed country filtering from “Allow only specific countries” with an empty allowlist to “Block specific countries.” That setting change alone has not yet established successful app access. The owner then disabled CDN for the API hostname and confirmed both screens load. Live app logs verify that the three affected read requests now return HTTP 200 JSON; see the recovery evidence below.

Official references:

- https://www.hostinger.com/support/hostinger-cdn-the-browser-verification-page/
- https://www.hostinger.com/support/7931101-hostinger-cdn-how-to-block-countries/
- https://www.hostinger.com/support/hostinger-cdn-how-to-fix-blocked-legitimate-requests/


## Recovery confirmed after CDN disable

On 18 October 2026, the owner reported that both screens load after disabling CDN specifically for `labapi.genziitian.in`. Their screenshot shows CDN status Inactive. The running authenticated app then recorded:

| IST time | GET endpoint | Result |
| --- | --- | --- |
| 14:41:51 | `/public/api/student/uploaded-papers` | 200, application/json |
| 14:42:15 | `/public/api/student/uploaded-papers` | 200, application/json |
| 14:44:33 | `/public/api/courses` | 200, application/json |
| 14:44:33 | `/public/api/student/spin-practice/quota` | 200, application/json |

This confirms that the native screen-loading failure was caused by Hostinger CDN filtering. No database, Laravel authentication, upload limits or practice quotas were changed to obtain these successful responses.

The dashboard still showed zero websites opted out of automatic CDN. Expand its opt-out control and select only the API hostname if it should stay disabled, or arrange an API-specific exception with Hostinger before re-enabling CDN.

Recovery confirms successful screen data loading. A real PDF conversion, persisted uploaded paper and generated practice-paper attempt remain separate end-to-end checks. The conversion-service timeout patch in the ZIP is still not deployed.
