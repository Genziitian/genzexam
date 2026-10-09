# Quiz LAB Pro memberships and payment setup

## What the code now does

- Stores a subscription ledger and the editable web plan (default ₹99/month, 7 days).
- Uses Razorpay Subscriptions for web checkout when Razorpay API keys and a webhook secret are set. A first subscription is created with its first billing date seven days ahead; later subscriptions for the same Quiz LAB account do not get another trial.
- Uses Google Play Billing in the Android app. The app sends the purchase token to the Laravel API, which verifies it with Google Play before granting Pro.
- Shows membership status and dates in web Settings and app More/Settings.
- Lets a member or manager cancel future renewal at the billing provider while preserving current access. Managers can revoke access immediately; Google Play revocation requests a prorated refund, while Razorpay cancellation does not automatically refund.
- Lets managers search the subscription history, inspect trial/payment dates and provider references, grant complimentary Pro for a chosen number of days, cancel renewal, or revoke access.
- Restricts PDF-to-test uploads, offline paper downloads, and Pro video playback to active Pro access on the server.

## Google Play Console steps

1. In Play Console, open **Monetize with Play > Products > Subscriptions** and create an auto-renewing subscription product with the product ID `quiz_lab_pro_monthly`.
2. Create and activate a monthly auto-renewing base plan. Set its regular price to ₹99 in India. Add and activate an offer with a 7-day free-trial phase; choose the offer eligibility you want. Offer IDs cannot be changed after activation. Use its exact offer ID in backend configuration. The manager can update the India price for new Play subscribers through the Developer API once the base plan is configured below; existing subscriber price cohorts are not changed by that action.
3. Publish the subscription product and offer to the same testing track as the app. Add tester Gmail accounts under Play Console license testing and make sure testers install the app from the Play testing link. Purchases generally do not work in a locally sideloaded build unless the account/build is set up for Play testing.
4. In Google Cloud, enable the **Google Play Android Developer API**. Create a service account, then grant that service account access to this app in Play Console with permission to view financial/order data and manage orders/subscriptions. Keep the service-account JSON private on the backend host, outside the public website directory.
5. Set these backend environment values, then clear Laravel's config cache:

   ```dotenv
   GOOGLE_PLAY_PACKAGE_NAME=in.genziitian.quizlab
   GOOGLE_PLAY_PRO_PRODUCT_ID=quiz_lab_pro_monthly
   GOOGLE_PLAY_PRO_BASE_PLAN_ID=monthly
   GOOGLE_PLAY_PRO_TRIAL_OFFER_ID=YOUR_PLAY_CONSOLE_TRIAL_OFFER_ID
   GOOGLE_PLAY_REGIONS_VERSION=2022/02
   GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=/secure/path/google-play-service-account.json
   ```

   Replace `monthly` with the actual base plan ID. The offer ID must exactly match the Play Console offer ID. Store the JSON outside the public web directory and restrict its file permissions. The documented regions version is `2022/02`.

   On the host, deploy the backend files first, then from the Laravel backend directory run `php artisan migrate --force` and `php artisan optimize:clear`. If the app's `vendor/autoload.php` is missing, the Laravel release is incomplete; install the backend's Composer dependencies during deployment before running Artisan.

6. Configure Real-time developer notifications (RTDN) in Play Console and send subscription events to an authenticated backend consumer. RTDN ingestion is not implemented yet. Until it is, the member's settings refresh verifies the latest Google state, but the manager list may not immediately reflect renewals or cancellations made directly in Play Store.
7. Test trial activation, trial cancellation, first renewal, payment failure/grace period, restore purchases, and account switching with Play license testers before promoting the app.

The Android app uses Flutter's `in_app_purchase` plugin. Google requires server verification for entitlements; the client never unlocks Pro from a local purchase result alone. The backend uses `purchases.subscriptionsv2.get` for verification and acknowledges a new purchase through the Google Play Developer API. Member and manager cancellation stops future renewal. A manager's immediate Google Play revoke calls `purchases.subscriptionsv2.revoke` with a prorated refund, so use that action only when a refund is intended.

### Before turning on Play purchases

- The Play Console subscription product ID must be exactly `quiz_lab_pro_monthly`; the Play app package must match `in.genziitian.quizlab`.
- The service account must be granted access to this app in Play Console, and its JSON must be installed securely on the API host.
- The app must be uploaded to a testing track and installed through Play Store using a license tester account. A locally installed APK is not a reliable purchase test.
- Add the subscription and 7-day offer in Play Console, then confirm the app product query returns a price before enabling the purchase button.
- Keep Razorpay checkout for the website and Play Billing for Android. Digital subscription purchases in a Play-distributed app should use Google Play Billing.

### Android release requirements and build

Use Flutter 3.47 or later (CI uses 3.47.6), Dart 3.13 or later, and Java 17 or later.
The Android project enables AGP 9's built-in Kotlin. The Kotlin 2.4.0 declaration
in `settings.gradle` selects the compiler without applying the legacy Android
Kotlin plugin; removing it lets AGP choose a compiler below Flutter's minimum.

`in_app_purchase` 3.3.1 and `in_app_purchase_android` 0.5.3 use Google Play Billing
Library 8.0.0. The normal submission deadline for Billing Library 7 was August 31,
2026. Every release AAB/APK build checks the resolved Billing dependency and fails
if it is missing or below version 8. Do not override Android Billing separately
from its Flutter plugin or manually change the billing version in the manifest.

From the repository's `mobile` directory:

```sh
flutter pub get
flutter analyze
flutter build appbundle --release
```

The upload bundle is `build/app/outputs/bundle/release/app-release.aab`. Release
signing must be configured in the ignored `android/key.properties` file. Increase
the build number after `+` in `pubspec.yaml` for each new Play upload; this release
is `1.0.3+4` because version code 3 was already uploaded.

The October 9 dependency update also upgrades `file_picker_web` to 4.1.0. Remaining
outdated notices are constrained upstream: Flutter pins `material_color_utilities`
and `flutter_test` pins `test_api`; `file_picker` requires `cross_file` 0.3.x;
`vector_graphics_compiler` caps `xml` at 7.0.1. Keep the committed lockfile and do
not force incompatible versions with `dependency_overrides`.

A successful release build verifies compilation and the Billing Library version.
It does not verify a real subscription transaction. Install the new build through
the Play testing track and complete the license-tester purchase/restore checks
above before production rollout.

References: [Google Play Billing deadlines](https://developer.android.com/google/play/billing/deprecation-faq),
[Flutter Android billing changelog](https://pub.dev/packages/in_app_purchase_android/changelog),
and [Flutter built-in Kotlin migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).

## Web / Razorpay setup

1. Enable Razorpay Subscriptions for the merchant account and set test keys on the backend first:

   ```dotenv
   RAZORPAY_KEY_ID=rzp_test_...
   RAZORPAY_KEY_SECRET=...
   RAZORPAY_WEBHOOK_SECRET=...
   ```

2. In Razorpay Dashboard, add the webhook URL `https://labapi.genziitian.in/public/api/membership/razorpay/webhook` and subscribe to `subscription.activated`, `subscription.charged`, `subscription.cancelled`, `subscription.halted`, and `subscription.completed`. Use the exact webhook secret in `RAZORPAY_WEBHOOK_SECRET`.
3. The manager's **Pro memberships** tab creates a new Razorpay monthly plan when the web price changes. Existing subscribers keep their original plan; the new price applies to new subscriptions.
4. Run the new database migration on the API deployment before enabling checkout. Test web signup, first-trial timing, renewal, cancellation-at-period-end, and failed payment in Razorpay Test Mode, then replace test keys with live keys.

## Manager panel

Open **Manager workspace > Pro memberships**. The list includes student/account ID, provider and product, status, amount, start date, trial end, last paid date, next charge/access end, checkout link for pending web payments, and provider subscription reference. The filters include pending, trialing, active, cancelled, revoked, and expired records. Managers can grant complimentary Pro by email and duration.

- **Cancel renewal**: tells the provider to stop future billing; current paid/trial access remains until its end date.
- **Revoke now**: removes access immediately. Google Play is asked to issue a prorated refund. Razorpay is stopped immediately without an automatic refund.
- **Legacy manual Pro**: can be revoked locally because no external recurring charge is recorded.

The plan editor sets the web price and web trial duration. Once the Play service account, product, and base plan are configured, saving a price also updates the India price for new subscribers on Google Play. Existing Play price cohorts are unchanged; price increases for current subscribers need a separate Google Play price-change migration. The 7-day Play offer and its eligibility remain configured in Play Console. Android users still buy through Play Billing. The manager list is not yet updated by RTDN when Play renewals happen outside this app; see step 6 above.

`Cancel renewal` calls the billing provider and leaves the user entitled until the current billing/trial period ends. `Revoke now` removes access immediately; for Google Play it requests a prorated refund, and for Razorpay it does not issue a refund. A complimentary manager grant has no external charge.
