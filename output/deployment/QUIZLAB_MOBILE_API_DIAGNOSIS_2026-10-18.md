# Quiz LAB app: Uploads and Daily Rewards failure

The screenshots show native Flutter screens. They still need the Laravel API for the account's papers, upload allowance, daily spins and rewards.

## Live checks on 18 October 2026

Requests used `Accept: application/json` and `X-QuizLab-Client: mobile`, without an account token. No credentials were read or included.

At 14:03 IST, the following responses were recorded:

| GET endpoint under `https://labapi.genziitian.in/public/api` | Response | Meaning |
| --- | --- | --- |
| `/courses` | 401 JSON `Unauthenticated.` | Route reaches the application's authentication middleware. |
| `/student/spin-practice/quota` | 401 JSON `Unauthenticated.` | Route reaches the application's authentication middleware. |
| `/student/uploaded-papers` | 401 JSON `Unauthenticated.` | Route reaches the application's authentication middleware. |
| `/student/rewards` | 404 JSON `The route public/api/student/rewards could not be found.` | The deployed route set does not contain the Rewards endpoint. |

Rewards 404 request ID: `2cbaf184d389b2b219db828dd7fac26f-mum-edge8`.
Uploads 401 request ID: `04fffd6120f456b2934f3458192704a4-mum-edge9`.

An earlier request to `/courses` also returned a Hostinger CDN HTML 403 browser-verification page, matching the app screenshot. That request ID was `33693e03b036c6ae45fa57380fee9773-mum-edge6`, at 13:33 IST. This demonstrates an intermittent/traffic-dependent challenge, rather than proving that every request is always blocked. Its exact trigger is not known.

The authenticated Uploads response has not been inspected, so its screenshot cannot establish whether the signed-in failure was a hosting challenge or a separate backend error. A successful unauthenticated route check is not an authenticated workflow test.

## Backend action required

The workspace already registers `/student/rewards`, `/student/rewards/spin`, `/student/rewards/scratch` and `/student/rewards/claim-pro` in `backend/routes/api.php` using `StudentRewardController`.

Compare the deployed backend route file and controller with the intended release before updating them. Confirm the deployed application has the expected controller and dependencies; deploy the reviewed backend release, then clear the stale route cache from the backend directory:

```sh
php artisan route:clear
```

Do not replace `.env`, `vendor`, database or storage directories while updating source. The missing route is not repaired by changing Flutter screens or rebuilding the APK.

Afterward, an unauthenticated GET to `/public/api/student/rewards` should reach authentication and return 401 JSON, rather than the route-not-found 404. Then verify the same signed-in account in the app: reward list and quota, spin result, refresh, and paper list/upload allowance. Do not consume a user's real daily spin just to check whether a route exists.

Review reward entitlement checks before enabling a new backend deployment: Pro activation must require an owned, eligible, unclaimed reward and reject duplicate claims. The existing local claim handler needs that review before being treated as deployment-ready. This document does not package or deploy the controller.

## Hosting action required

Ask Hostinger to investigate the API hostname/path's browser-verification challenge using the failing URL, method, timestamp and request ID above. Native HTTP clients cannot complete an interactive browser check. Keep Laravel authentication and authorization enabled.

Hostinger's official guidance says specific endpoint/service exceptions require Hostinger support: https://www.hostinger.com/support/hostinger-cdn-how-to-fix-blocked-legitimate-requests/

Chrome access was not approved during this investigation, so hosting settings were not inspected or changed. No backend deployment was performed.

## App changes

- Initial load failures no longer appear as `0 papers` or `0 rewards`.
- Uploads preserve the last successfully loaded paper list after a refresh failure and mark it as last-loaded data.
- Upload/reward operations stay disabled when the server has not confirmed availability.
- Errors have concise messages and native retry/support controls.
- The native reward wheel remains visible while the spin operation is unavailable.
- A failed pull-to-refresh is rendered in the screen and does not escape as an unhandled error.
- An incomplete upload-list response is treated as an error rather than an empty account.


## Later recovery of Uploads and Test yourself

After the owner disabled CDN for `labapi.genziitian.in`, both screens loaded. The authenticated app recorded HTTP 200 JSON for uploaded papers at 14:41:51 and 14:42:15 IST, and for courses plus practice quota at 14:44:33 IST. This resolves the earlier loading block for those two flows. No backend/database/rule changes were needed for this recovery. The earlier Rewards snapshot above is historical; that feature is being handled by a separate task and was not rechecked here.
