# Connect Google Play notifications to Quiz LAB

For the plain-language explanation, setup history, account roles, benefits, and
future troubleshooting, see [the Billing and RTDN reference](GOOGLE_PLAY_BILLING_AND_RTDN_REFERENCE.md).

The Laravel receiver is implemented locally. It is not live until the backend is
deployed, the migration and environment settings are applied, and the existing
Pub/Sub subscription uses authenticated push delivery.

## Values for this app

| Setting | Value |
| --- | --- |
| Google Cloud project ID | `teaching-lms` |
| Google Cloud project number | `990282572765` |
| Topic | `projects/teaching-lms/topics/quizlab-play-rtdn` |
| Pub/Sub subscription | `projects/teaching-lms/subscriptions/quizlab-play-rtdn-sub` |
| Backend endpoint | `https://labapi.genziitian.in/public/api/membership/google-play/notifications` |
| OIDC audience | Same exact URL as the backend endpoint |
| Android package | `in.genziitian.quizlab` |
| Pro product | `quiz_lab_pro_monthly` |

These topic and subscription names came from the Cloud Console configuration.
They are not secrets. The private billing service-account JSON stays on Hostinger
outside `public_html`; do not put it in the app or commit it.

## 1. Create the push authentication identity

In Google Cloud, select `teaching-lms`, then open **IAM & Admin > Service Accounts**.
Create a service account with ID `quizlab-rtdn-push`. Its email should be:

```text
quizlab-rtdn-push@teaching-lms.iam.gserviceaccount.com
```

It needs no downloaded key, no Play Console invitation, and no broad project
roles. It is the identity attached to delivery requests, separate from the
billing API service account that can verify/cancel subscriptions.

The Pub/Sub service agent must be able to mint an identity token for this account.
Find your project's **project number** (different from its project ID) in Google
Cloud's project information. On the new push service account, open
**Principals with access > Grant access** and grant:

```text
Principal: service-990282572765@gcp-sa-pubsub.iam.gserviceaccount.com
Role: Service Account Token Creator
```

This principal and its direct Token Creator grant were confirmed in the owner's
17 October 2026, 13:40 IST screenshot. Select **Include Google-provided role grants**
and **View by roles** if the entry is hidden. Scope this grant to the push
service account. The Google account editing the push subscription must also have
`iam.serviceAccounts.actAs` on it (for example, Service Account User).

## 2. Deploy and configure Hostinger first

Deploy the updated `backend` files, including the new migration and service/controller
files. No new Composer package, Flutter rebuild, or queue worker is required for
this receiver. The deployed backend must already have its normal Composer dependencies.
Use `APP_DEBUG=false` on the production backend.

Add the following to the **deployed backend** environment:

```dotenv
GOOGLE_PLAY_PACKAGE_NAME=in.genziitian.quizlab
GOOGLE_PLAY_PRO_PRODUCT_ID=quiz_lab_pro_monthly
GOOGLE_PLAY_PRO_BASE_PLAN_ID=monthly
GOOGLE_PLAY_PRO_TRIAL_OFFER_ID=trial-7-days
GOOGLE_PLAY_REGIONS_VERSION=2022/02
GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=/absolute/private/path/to/billing-service-account.json
GOOGLE_PLAY_RTDN_TOPIC=projects/teaching-lms/topics/quizlab-play-rtdn
GOOGLE_PLAY_RTDN_SUBSCRIPTION=projects/teaching-lms/subscriptions/quizlab-play-rtdn-sub
GOOGLE_PLAY_RTDN_AUDIENCE=https://labapi.genziitian.in/public/api/membership/google-play/notifications
GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL=quizlab-rtdn-push@teaching-lms.iam.gserviceaccount.com
```

Use the real private JSON path and exact activated trial offer ID. The billing
service account (JSON file) needs Play Console access for purchase verification.
`GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT_EMAIL` instead names the identity selected in
the Pub/Sub push settings. Configuring a topic variable alone does not subscribe
the backend to the topic; the full subscription name is also checked.

In **Hostinger SSH**, run sequentially:

```sh
cd /home/u404320264/domains/labapi.genziitian.in/public_html/backend
php artisan migrate --force
php artisan optimize:clear
```

Confirm `2026_10_17_000001_create_google_play_notifications_table` completed.
The earlier Pro subscription ledger migration must also have run.
Make sure Hostinger preserves the `Authorization` header for Laravel and allows
outbound HTTPS to `oauth2.googleapis.com` and `androidpublisher.googleapis.com`.
An unauthenticated POST to the deployed receiver should return 401 after config
is installed, rather than 404, a login redirect, or a hosting protection page.

## 3. Change the existing inbox from pull to push

Open **Pub/Sub > Subscriptions > quizlab-play-rtdn-sub > Edit**. Keep the existing
subscription and topic; changing its delivery retains its queued messages.

| Field | Setting |
| --- | --- |
| Delivery type | Push |
| Endpoint URL | `https://labapi.genziitian.in/public/api/membership/google-play/notifications` |
| Enable authentication | Checked |
| Service account | `quizlab-rtdn-push@teaching-lms.iam.gserviceaccount.com` |
| Audience | Exact same URL as the endpoint |
| Payload unwrapping | Disabled; retain the normal JSON message envelope |
| Acknowledgement deadline | 60 seconds |
| Retry policy | Exponential backoff, 10 seconds minimum / 600 seconds maximum |

Save after the backend is deployed. Keep Pause and Play Store resubscribe disabled
until their real purchase flows have been tested. Leave external/alternative
billing programs unchanged for this standard Play Billing integration.

## 4. Test delivery and membership changes

In **Play Console > Monetization setup**, keep the topic above and
**Subscriptions and voided purchases only**, then **Send test notification** and
save. The Google-owned publishing account must still have Pub/Sub Publisher on
the topic:

```text
google-play-developer-notifications@system.gserviceaccount.com
```

Success in Play Console confirms publishing to Cloud. To confirm the backend
received it, inspect the `google_play_notifications` table: the new `kind=test`
row should have `status=processed` and `processed_at` set. Cloud's push delivery
metrics should show HTTP 204 responses. A test event never grants Pro.

Use a Play license tester to purchase and verify Pro through the app. Then test
renewal, cancellation, expiry, payment failure/grace/hold, and refund/revocation.
Check both web and mobile access, membership dates, and the manager list.
Do not manually pull/ack real billing events while push delivery is running.

## Receiver behavior and operational checks

- Google authenticates the OIDC token through its documented tokeninfo endpoint;
  the receiver also checks issuer, expiry, verified sender email, exact audience,
  configured Pub/Sub subscription, and Android package. It fails closed when
  settings are missing or authentication fails.
- Each relevant event fetches the current subscription from the Developer API.
  The event's type or timestamp alone never grants/revokes access. This handles
  delayed or out-of-order messages, including refunds of older periods where
  Google still reports a currently valid subscription.
- Active/trial/grace subscriptions grant access through their expiry. A canceled
  subscription keeps its remaining paid/trial access. Paused, on-hold, pending,
  and expired subscriptions do not grant access.
- Membership screen refresh uses the same state mapping. Trial conversion uses
  Google's current offer phase; an offer ID alone does not mean a trial is active.
- Processed message IDs are deduplicated durably. Network/API/database failures
  return 503 so Pub/Sub retries. Authentication failure returns 401/403. No
  queue worker is required because the update commits before HTTP 204.
- Receipts store only a token hash, not raw purchase tokens, JSON credentials, or
  Authorization headers. Purchase tokens remain encrypted in the membership ledger.
- A first event can arrive before app verification links its token to a Quiz LAB
  account. It is saved as `unlinked`, returns 503, and can succeed on a later
  retry after app verification. Unknown purchases are never assigned to a guessed
  student. Out-of-app new-token purchases still need in-app Restore/verification;
  automatic account linking for those purchases is not implemented here.
- A valid separate web/manual membership on the same user is preserved if one
  Play subscription expires. This receiver does not change plan prices, annual
  selection, country prices, or existing purchase amount/currency reporting.
- Repeated `unlinked` receipts need investigation before message retention ends;
  ask the student to restore/verify their purchase. Monitor non-204 push responses,
  growing backlog and receipt status. Google authentication outages are retryable.
- `pendingRefundReviewNotification` (manual chargeback review workflow) and
  one-time product purchase fulfillment are outside this receiver's scope. Such
  messages are recorded as ignored; handle chargeback review in Play Console.
- Retain receipts long enough to cover delivery/replay; there is no automatic
  pruning job in this change.

## Verification

The feature tests use an isolated in-memory SQLite database and fake Google
responses. They cover authentication, malformed/wrong-app messages, the current
RTDN payload without `subscriptionId`, test events, renewal, duplicates,
cancellation/restoration, grace/hold/pause/expiry, independent grants, stale
events, trial conversion, failures and unknown purchase retries. These are local
checks; they do not establish live Hostinger delivery or real Google purchases.

Local execution on PHP 8.4.23: the 24 RTDN/membership checks plus 6 existing
Google mobile sign-in checks passed (30 tests, 162 assertions) with mocked Google
responses. The existing storefront suite separately has 7 errors and 3 failures
in its 21 tests; the same results were reproduced with the unchanged payment
controller, routes and service configuration from HEAD. Those storefront
fixture failures are not repaired by this notification change.

```sh
cd backend
php vendor/bin/phpunit --filter GooglePlayNotificationTest
```

References: [Google push authentication](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions),
[RTDN setup](https://developer.android.com/google/play/billing/getting-ready),
[RTDN payload](https://developer.android.com/google/play/billing/rtdn-reference),
[Subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions).
