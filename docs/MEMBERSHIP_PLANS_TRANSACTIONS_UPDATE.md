# Membership plans, upload allowance and transaction history

## Purpose

Present two billing choices with the same Pro benefits on the website and Android app. Keep billing disclosures clear and show real account records instead of treating a subscription row as a receipt for every renewal.

## Plan rules

- Google Play product: `quiz_lab_pro_monthly` (the existing ID is retained).
- Monthly base plan: `monthly`. Eligible accounts can use offer `trial-7-days`.
- Yearly base plan: `annual`, with no trial.
- Intended India prices: monthly ₹99; yearly ₹999. Confirm the saved prices in Play Console. Android displays the actual localized recurring price returned by Play, never a fixed rupee replacement when the catalog is unavailable.
- Web monthly price and trial days come from existing plan settings; yearly price is `PRO_ANNUAL_PRICE_PAISE` (default 99900).
- Web checkout uses Razorpay; Android checkout uses Google Play. Regional prices/payment authorisation behaviour can differ, but membership access and upload rules belong to the same Quiz LAB account.
- A previously used trial on either provider is not offered again by Quiz LAB. Google may impose additional eligibility restrictions on Play offers.
- Monthly's eligible trial is part of the monthly choice, not a third plan. Its button says “Try for free”.
- The summary shows the recurring price, equal trial discount, “FREE today”, and the estimated first billing date if checkout is completed today. Checkout confirms the exact billing time. Pro access begins with the trial, not only after the first charge.
- Yearly shows the full yearly charge and has no free-trial wording.
- Both plans provide the same access: Pro 5 uploads per rolling 7 days, Free 1. These are shared totals across app and web, not separate allowances. Failed conversions do not consume a completed-upload slot.

## Upload screen

The marketing subtitle under the Pro hero is removed. The comparison table remains. Uploaded papers are the main content, ordered newest first, with a compact allowance strip and Upload paper button. All upload rules are hidden behind Upload rules · See all. They collapse after 30 seconds, on page exit, or when the app/browser goes to the background. The large hero, quota ring and conversion diagram are removed. Empty accounts receive a clear Upload your first paper action. The app shows a simple spinner during conversion. Once the free upload is used, a live countdown uses the server-provided `resets_at`; the app refreshes the server allowance when it reaches zero. Get Pro to upload now opens the real membership checkout flow. Clicking Claim alone does not consume quota: successful test creation does.

## Manager cancellation

The manager's existing Cancel renewal action calls the actual payment provider first. For Google Play it uses `subscriptionsv2.cancel` with `DEVELOPER_REQUESTED_STOP_PAYMENTS`; for Razorpay it requests provider cancellation. A successful API response is required before local cancellation is recorded. If credentials or the provider request fail, the API returns an error; it must not claim billing has stopped.

Cancel renewal stops the next payment and preserves access through the verified current trial or paid expiry. Google developer cancellation cannot be restored as the same renewal subscription; the student may need a new purchase later.

Revoke now is a different action. For Google Play it requests immediate revocation and a prorated refund. For Razorpay it cancels immediately without automatically issuing a refund. Complimentary access has no external billing to cancel. Read the confirmation before applying these actions.

## Research used

- [Google subscription disclosures](https://support.google.com/googleplay/android-developer/answer/9900533): show trial duration, subsequent charge, billing frequency, and cancellation information.
- [Spotify subscription terms](https://www.spotify.com/us/legal/paid-subscription-terms/): distinguishes trial and subsequent recurring billing.
- [Adobe trial terms](https://helpx.adobe.com/in/account/individual/terms-policies-and-regulations/adobe-subscription-terms.html): explicitly states when trial billing starts and how to avoid the subscription charge.
- [Google developer cancellation](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2/cancel).
- [Google revocation](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2/revoke).

## Checks for the owner after deployment

No Android Studio session or app was opened by this change. At the owner's request, final changes are code-only; the owner should perform the following checks:

1. Run `flutter analyze --no-pub` from `mobile`, then `flutter test --no-pub test/pro_play_offer_test.dart test/pro_paywall_screen_test.dart`.
2. Install a new test build from Google Play using a license tester. Confirm monthly uses the eligible trial offer, yearly uses the annual plan and is charged immediately, and both prices match Google's checkout.
3. Confirm the same Quiz LAB account shows the same trial eligibility, Pro state, and upload allowance on web and Android.
4. Use one free upload. Confirm the countdown appears and remains consistent with the server allowance. Expand and collapse the upload rules.
5. Complete test subscription payments and renewals, open membership history, and verify provider reference, amount, currency, and date. Check a different student cannot view that history.
6. Confirm manager history links resolve to the intended student, manager-only access is enforced, and cancellation affects the provider as described above.
7. Run the backend feature tests including ProMembershipParityTest and the transaction history tests after applying the new migration to a test database. Real provider purchase, renewal, refund, and cancellation tests remain required.

This source update is not a production deployment and is not proof that a real payment or cancellation succeeded.


## Transaction history deployment

The earlier membership UI, manager history, provider receipt recorder and authenticated history endpoints are implemented in source. They still require deployment and owner testing. Apply the new migration from the Hostinger backend directory:

```sh
php artisan migrate --path=database/migrations/2026_10_17_000003_create_membership_transactions_table.php --force
php artisan optimize:clear
```

Use the **000003** filename currently in this repository. The earlier draft filename 000002 is outdated.

Student history uses `/membership/history`; manager history uses `/manager/pro/transactions`. The student endpoint always uses the signed-in account. Manager history supports user/search filters and pagination. The ledger records verified provider receipts and existing paper orders, not invented historical renewals. Previous renewals are not automatically backfilled. Google Orders API access must succeed for its latest receipt to appear; membership access is not blocked by an unavailable receipt lookup.

History amounts preserve the provider currency and its minor-unit precision. Free trial access is a membership record; it is not a fabricated payment receipt.

Final changes were reviewed in source only, as requested. JavaScript syntax checks passed and the edited Dart files were parsed and formatted. No new app, Android Studio, browser session, build or test run was started for this final update. Deployment, the new migration, a rebuilt Android release, and real/test payment flows remain owner checks. Existing deployment ZIPs predate this final update; do not assume they contain these changes.


## Corrected upload layout and billing gate — 18 October 2026

The previous source/ZIP still contained the large mobile upload screen. This correction replaces it with papers first, newest first; a compact allowance and Pro link; an Upload paper button; a first-upload empty state; and fully collapsed rules. Rules close after 30 seconds, on navigation or app backgrounding. The original marketing hero, ring and pipeline are removed. The website already has the corresponding compact layout.

The Pro app bar now stays above the scrolling content instead of overlapping it. Missing trial-offer configuration no longer marks all paid Google Play billing as unavailable. The app requests the Play catalog even when backend verification configuration is incomplete; actual localized prices may then appear, while checkout remains disabled until the backend reports ready. Reload clears old offers to prevent a stale purchasable selection.

This does not install credentials on Hostinger. To see exactly which configuration is missing, run from the existing backend directory (no private key or credential values are printed):

```sh
cd ~/domains/labapi.genziitian.in/public_html/backend
php artisan config:clear
php artisan tinker --execute='$keys=["package_name","subscription_product_id","subscription_base_plan_id","annual_base_plan_id","trial_offer_id","service_account_json"]; foreach($keys as $key) { dump([$key => (bool) config("services.google_play.".$key)]); } $p=config("services.google_play.service_account_json"); dump(["billing_file_readable" => is_string($p) && is_file($p) && is_readable($p)]);'
```

Required configuration names are GOOGLE_PLAY_PACKAGE_NAME, GOOGLE_PLAY_PRO_PRODUCT_ID and GOOGLE_PLAY_SERVICE_ACCOUNT_JSON. Monthly/yearly base plans must match monthly/annual. The optional trial offer is trial-7-days. The billing JSON path previously confirmed on Hostinger was /home/u404320264/domains/labapi.genziitian.in/private/teaching-lms-4e59e7438b03.json. The readiness flag confirms configuration presence, not successful Google authentication, Play permissions or purchase completion.

Checks for this correction: edited Dart files parsed/formatted; JavaScript syntax checked; ZIP contents checked against current source. The added backend readiness regression test has not been run. No build, device session, migration or payment was run.


## Confirmation animation

A shared SuccessTick widget expands the green circle and draws the white tick once. Paper submitted uses a 120px mark. A confirmed new Google Play purchase displays a Pro activated dialog after server verification and a refreshed Pro entitlement. Pending, cancelled, failed or restored events do not trigger a purchase celebration. Reduced-motion settings show the completed tick immediately. This animation has been checked in source and parsed, not run on a device.


## Loading and monthly trial follow-up

Read requests now use the screen-owned spinner only. The shared app loader renders only for blocking work, with an opaque backdrop that hides screen loaders beneath it. This removes the duplicate purple/green indicators.

The known Play monthly trial offer ID trial-7-days is the fallback when the backend omits an ID. It must still be returned by Google Play for the current account, and Quiz LAB must report trial eligibility. Eligible monthly cards show Try for free, the trial calculation and first billing date; other accounts receive regular monthly terms. Checkout remains disabled when backend billing verification configuration is missing. Removed the duplicated unavailable sentence on the paywall.


## Dedicated membership screen and receipt summary

The More page now has a compact Membership & transactions entry. It opens a dedicated app screen with Membership and Transactions tabs. The web More page opens a matching management panel with the same tabs. Membership details include status, provider, start, trial and current-period end; transaction history is paginated.

Eligible monthly trials display a receipt: monthly price, negative trial discount, divider, FREE due today, estimated first charge date and amount. Cancellation wording and a linked Terms & Conditions acknowledgement accompany checkout. The date assumes checkout is completed today; the provider confirms the exact time. Yearly stays a paid annual choice with no trial.

POST /membership/manage accepts an owned subscription_id and action cancel/pause/resume. The backend scopes lookup to the authenticated user's subscriptions. Provider errors do not mark the local action successful. Razorpay pause/resume uses its real API and only updates local state after the expected provider status is returned. Pause is immediate: access from this subscription is suspended and no refund is requested. Resume may involve a charge according to Razorpay's schedule. Another independent active membership remains effective.

Google Play management opens its subscription centre, where pause/resume/resubscribe availability is decided by Google and the Play Console configuration. The app never implements Google pause as a local database toggle. Cancel renewal requests provider cancellation and keeps the existing access end date. Subscribe again opens a fresh checkout after access ends; a paused subscription is resumed through its own provider instead.

For Razorpay, additionally enable subscription.paused and subscription.resumed on the existing signed webhook. The app refreshes membership on return from the provider. For Google, existing RTDN processing supplies the refreshed store state.

Provider references: https://developer.android.com/google/play/billing/subscriptions and https://github.com/razorpay/razorpay-php/blob/master/documents/subscription.md .

Checks: Dart files parsed/formatted and JavaScript syntax passed. Added backend regression cases for ownership, provider failure preserving access, and confirmed pause/resume. Backend tests, device interaction and real provider mutations were not run. A PHP syntax-check attempt could not start because the available WASM runtime tries to bind a local port that this sandbox disallows. No production cancellation, pause or charge was performed.


## Final management policy — pause controls removed

This section supersedes the earlier pause/resume implementation notes. Quiz LAB now exposes cancellation only through /membership/manage; pause and resume requests are rejected. Removed native/web buttons and Razorpay changeState method. Provider-originated paused/resumed notifications are still processed so account state stays accurate; Google Play may expose its own options. To disable Google's pause option entirely, change the subscription pause setting in Play Console; source changes alone cannot change that setting.

Management now displays subscription start, first recorded payment from verified nonzero receipts, other recorded payment dates, next expected charge for a renewing paid-provider subscription, and cancellation/access end. Older receipt history is not backfilled, so the first recorded payment is not falsely labelled the original purchase date. Missing provider dates remain unconfirmed, and complimentary access never gets a next-charge date.

Updated Terms & Conditions, Privacy Policy, Refund & Cancellation Policy, account deletion notices and bundled mobile legal text on 18 October 2026. Website and backend/public policy copies describe Razorpay website checkout, Google Play Android checkout, monthly/yearly recurring billing, trial eligibility and conversion, provider cancellation, refund channels, shared account benefits, billing records and deletion not cancelling billing. Removed obsolete website-only payment and blanket no-cancellation wording for subscriptions.

Only source/static checks were performed. New cancellation authorization and failure-handling regression cases are supplied but unrun. The Google Play item-not-found screenshot remains unresolved: package/product IDs match local configuration, but the installed build's Play account, license-testing eligibility, test-track access and offer availability still need validation. Do not interpret policy/source updates as proof of a completed purchase.


## Upload screen follow-up — process guide and account states

The latest layout starts with a compact How it works guide: Upload → Convert → Take test, followed by allowance, a single upload action when available, papers and collapsed rules. This supersedes the earlier papers-first layout.

Free with allowance: show the remaining free upload, Use free upload, and “5 uploads with Pro · Get Pro” (using the configured Pro limit). Free with no allowance: hide upload actions, show the live server reset countdown and the same Pro link. Pro with allowance: show X of 5 uploads and Upload paper, with no Pro upsell. Pro without allowance: hide upload actions and show the next-slot countdown, keeping existing papers usable. The empty paper list never presents another first-upload button.

Both surfaces use /student/uploaded-papers quota, which counts successful test creation by account regardless of web/app origin. Merely opening or claiming the upload action consumes nothing. Refresh on app/browser return and every 30 seconds while visible keeps the other platform's uploads reflected. Explicit refresh also updates immediately. Server-side account locking rechecks allowance at final test creation, so an outdated client display cannot bypass the shared limit. In-flight background responses are prevented from overwriting post-upload state.

Checks for this follow-up: edited Dart parsed/formatted; web JavaScript syntax and whitespace checks passed. Device rendering, live cross-device timing, and upload conversion were not run.


## Compact checkout footer and upload wording

The mobile paywall footer places the charge/trial text on the left and a compact checkout button on the right. Terms remain below as a small linked line. Reduced footer padding and scroll clearance retain the device safe area without the old large banner. Button labels, prices, trial eligibility and disabled/busy handling are unchanged.

A free account with allowance now sees Claim 1 free upload on its single primary action; the repeated availability heading is removed. The separate compact Pro row says 5 uploads every 7 days with Pro and uses a filled gold Get Pro button (numbers use server quota). Used Free and exhausted Pro states keep their countdowns; Pro accounts keep remaining-slot counts and no upsell. Upload rules remain after papers, with a left-aligned See all / See less toggle below the heading. Web upload wording and states match.

Dart formatting/parsing, JavaScript syntax and whitespace checks passed for this change. No app/device UI session or build was run.
