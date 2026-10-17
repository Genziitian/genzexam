# Quiz LAB Pro update: upload instructions

Prepared 17 October 2026 after comparing the owner's three downloaded server files.

## 1. Backend package

Use **quizlab-rtdn-hostinger-update.zip**, not the earlier `quizlab-rtdn-backend.zip`.

1. In Hostinger File Manager, stay in **public_html/backend**.
2. Keep local backups of the three server files already downloaded. Also download a backup of `app/Http/Controllers/StudentUploadedPaperController.php` before replacing it; its server copy was not supplied for comparison.
3. Upload `quizlab-rtdn-hostinger-update.zip` into **public_html/backend**.
4. Extract into that same directory. Merge into existing directories and replace only matching files; do not replace/delete entire directories.
5. Confirm these 8 files are in their exact locations:

   ```text
   app/Http/Controllers/GooglePlayNotificationController.php
   app/Http/Controllers/ProMembershipController.php
   app/Http/Controllers/StudentUploadedPaperController.php
   app/Services/GooglePlayPushAuthentication.php
   app/Services/GooglePlayMembershipSync.php
   config/services.php
   routes/api.php
   database/migrations/2026_10_17_000001_create_google_play_notifications_table.php
   ```

6. Remove the uploaded ZIP after extraction. Keep your local backup. The archive contains no `.env`, JSON key, `vendor`, storage files, or app key.

This ZIP has **no outer backend folder**. The result must not be `public_html/backend/backend`.

## 2. Configure environment and migrate

Use the backend environment block in [the RTDN setup guide](../../docs/GOOGLE_PLAY_RTDN_SETUP.md). Preserve the existing production `.env` and application key. Set the real private billing-account JSON path and exact activated offer ID, rather than copying placeholders.

For explicit shared upload defaults, add or update these names once in the backend `.env`:

```dotenv
STUDENT_PAPER_UPLOAD_LIMIT=5
STUDENT_PAPER_FREE_UPLOAD_LIMIT=1
STUDENT_PAPER_UPLOAD_WINDOW_DAYS=7
```

After uploading/configuring, run from the Laravel backend directory in Hostinger SSH:

```sh
php artisan migrate --path=database/migrations/2026_10_17_000001_create_google_play_notifications_table.php --force
php artisan optimize:clear
```

The pre-existing Pro ledger and personal-upload migrations must already be installed. This command applies only the RTDN receipt migration; it does not run the separate local manager publishing migration.

Verify the endpoint, then switch the existing Pub/Sub subscription to authenticated Push as described in the setup guide. Keep Pull until the receiver is ready.

## 3. Website update

`quizlab-pro-web-update.zip` contains `more-web.js` and `app-enhancements.js`. Upload/extract it in the website directory that already serves those scripts, rather than assuming it belongs on the API domain. The second script includes the current shared free/Pro upload allowance UI.

Back up both existing scripts first. These local web scripts were not compared against downloaded production copies. Keep any other website changes intended for your release.

In the deployed website's HTML entry point, keep the same script path but change its version query to a fresh value, for example:

```html
<script src="/more-web.js?v=20261017-pro-rules" defer></script>
```

Also use a fresh version query for the existing `app-enhancements.js` script tag, preserving any other attributes. Purge any website cache and refresh. The ZIP intentionally does not replace the complete production HTML entry point.

## 4. Android update

The Flutter changes are in `mobile/lib/api/pro_play_offer.dart` and `mobile/lib/screens/student/pro_membership_card.dart`. They require a new Flutter build. The currently running or published app does not receive these changes merely from the backend upload.

Build/test the updated app and install the intended version through the Play testing track for actual billing tests. This package does not contain a new release APK/AAB.

## 5. Acceptance checks

Using the same Quiz LAB account on web and app, verify Pro access, trial eligibility, cancellation retaining remaining time, and combined upload usage: one free upload or five Pro uploads per rolling seven days, not separate allowances per device. Then test Google/Razorpay purchase confirmation and subsequent expiry. Check RTDN test receipt processing and HTTP 204 delivery before calling the integration live.

See [shared Pro rules and limits](../../docs/APP_AND_WEB_PRO_RULES.md) and [the full billing reference](../../docs/GOOGLE_PLAY_BILLING_AND_RTDN_REFERENCE.md).

## Recorded local checks

The final backend ZIP passed 37 isolated PHP tests / 355 assertions on PHP 8.4.23 with mocked payment services. Four Flutter billing-offer tests and the focused web membership checks passed. Flutter analysis and both web scripts passed syntax/static checks. These results do not confirm a live deployment or payment.
