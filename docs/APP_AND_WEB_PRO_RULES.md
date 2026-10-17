# Quiz LAB Pro: shared app and website rules

Updated 17 October 2026. These are the local source rules and checks, not a claim that the updated files are deployed.

## One account, one entitlement calculation

The website and Android app use the same `/membership` API and Laravel `User::hasProAccess()` calculation. Buying through Google Play can unlock the same Quiz LAB account on the website; buying through Razorpay can unlock it in the app. The user must sign into the same account. Payment confirmation must reach the backend first, and the client must refresh its membership data.

The payment providers differ: Android checkout uses Google Play; website checkout uses Razorpay. This does not create separate Pro feature entitlements.

| Rule | Shared behavior |
| --- | --- |
| Trial or active subscription | Access until its valid period ends |
| Cancellation | Stop renewal and preserve remaining valid access |
| Expired, pending, on hold, paused, or revoked subscription | Does not grant Pro access |
| Another valid membership/grant exists | That other entitlement remains valid |
| Trial eligibility | Uses the same account subscription history, including trials from the other provider |
| New subscriptions disabled by manager | Website hides checkout; app disables new purchase while keeping Restore available |
| Upload allowance | Free: 1 successful upload; Pro: 5 successful uploads per rolling 7 days, combined across web and app. A free upload already used counts toward the five after upgrading |
| Upload failures | Do not create a paper or consume the successful-upload allowance |
| Paid papers sold separately | Pro does not bypass a paper's separate purchase requirement |

## Features enforced by the backend

- Pro video playback is checked by `VideoSolution::isAccessibleBy()` before issuing the signed player URL. Free videos remain free; existing staff access rules are unchanged.
- New offline downloads use the Pro-gated `/quizzes/{id}/offline-download` endpoint, which also checks access to separately sold papers.
- Uploaded PDFs/JSON use `/student/uploaded-papers` for both clients. The same membership-based allowance, file limits, PDF page limit, and AI safety rules apply. Defaults are 10 MB per file, 30 PDF pages, and up to 100 questions. The separate AI conversion rate limit remains server-controlled.
- Both upload screens read the same `quota` response. The server rechecks the allowance under an account lock immediately before saving, preventing two concurrent conversions from both consuming the final slot.

## Display corrections in this update

- Website checkout no longer always promises a new seven-day trial. It uses account eligibility and the configured web trial duration.
- Cancelling from the website refreshes the shared membership status and retains the access-end date, instead of making valid remaining Pro appear immediately removed.
- Complimentary memberships no longer display a recurring-renewal cancellation action in either client.
- Android uses the configured monthly base plan and does not fall back to an annual plan returned first by Google Play.
- Android displays Google's actual free-trial period and recurring price. A zero-priced trial phase is not displayed as the ongoing monthly price.
- Android's new-purchase button honors the manager's enabled setting; restoring an already purchased subscription remains possible.

## Differences that must be understood

1. Google Play controls its actual region prices and offer eligibility; Razorpay uses the backend's web plan settings. Editing web trial days does not automatically edit the Play trial offer. Keep the intended trial duration aligned in both dashboards. Store eligibility can be stricter than account eligibility, so an account may see a regular paid plan when no eligible Play offer is returned.
2. A locally cached offline paper cannot receive immediate server changes while the device is offline. Existing downloaded copies remain readable; this change does not introduce expiry-based deletion. New downloads and online Pro operations are checked by the backend.
3. Backend entitlement changes appear when a client refreshes membership/feature data. This does not add a live push-to-phone mechanism.
4. No automatic cancellation of an independently purchased second provider subscription is implemented. Do not imply that a payment on one provider cancels another provider's recurring charge.
5. Trial/annual offer activation, real payments, live RTDN delivery, and the deployed upload-controller version still need production verification. Annual purchasing remains unavailable through this monthly-only selector.

## Deployment files

Use the new [Hostinger upload instructions](../output/deployment/QUIZLAB_PRO_UPLOAD_INSTRUCTIONS.md). The new backend ZIP has paths relative to `public_html/backend`, unlike the earlier ZIP that included a `backend/` parent folder. Do not mix their extraction instructions.

The three existing server files supplied by the owner were compared:

- `routes/api.php`: preserves the supplied server routes and adds only the RTDN route/import; unrelated local manager publishing routes are excluded.
- `config/services.php`: preserves supplied settings and adds RTDN authentication fields plus shared upload allowance configuration.
- `app/Http/Controllers/ProMembershipController.php`: includes RTDN membership synchronization, preserved trial history, and the configured Play base-plan identifier.

The package also includes the current shared upload controller. That fourth existing controller was not downloaded from Hostinger for comparison; back up its deployed copy before replacing it. Its included source uses the existing personal-upload schema and does not need the separate manager publishing migration.

## Local verification

- PHP 8.4.23 isolated SQLite checks against the final merged deployment package: 37 tests / 355 assertions passed, covering RTDN, Google mobile sign-in, and app/web membership parity.
- Seven parity tests include both payment providers' access states, shared trial history, disabled sales, expired-user free allowance/download restrictions, independent grants, a shared free upload across clients, upgrading after a free upload, and five successful Pro uploads alternating between website and app followed by shared quota exhaustion/reset.
- Four Flutter offer tests passed: correct monthly trial/renewal price, previously used trial, annual-only availability, and missing-trial fallback. Flutter analysis reported no issues.
- Web membership checks passed for eligible/used/zero-day trials, disabled sales, cancellation access dates, and complimentary memberships. JavaScript syntax passed.
- These checks use fixtures and mocked payment services. They do not exercise real Google/Razorpay payments, simultaneous MySQL requests, physical-device offline behavior, or live Hostinger delivery.

No new production payment or deployment was performed by these checks.
