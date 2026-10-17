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

The marketing subtitle under the Pro hero is removed. The comparison table remains. Upload rules show the first two entries, with See more / See less for the rest. Once the free upload is used, a live countdown uses the server-provided `resets_at`; the app refreshes the server allowance when it reaches zero. Get Pro to upload now opens the real membership checkout flow. Clicking Claim alone does not consume quota: successful test creation does.

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
