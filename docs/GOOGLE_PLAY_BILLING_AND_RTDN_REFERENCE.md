# Quiz LAB: Google Play Billing and RTDN reference

Recorded: 17 October 2026.

This explains why we set up Google Play Billing and real-time developer notifications (RTDN), what each part does, what we configured, and how to continue or troubleshoot later.

## 1. Why we are doing this

Quiz LAB Pro unlocks video solutions, offline paper downloads, and turning uploaded PDFs into tests. Google Play Billing collects Android subscription payments. Our Laravel backend decides which Quiz LAB account currently has Pro access.

A subscription can change while the student is away from the app. A renewal can succeed, a payment can fail, or access can expire. RTDN tells our backend that something changed so it can check Google and update the student's membership without waiting for the student to open the membership screen.

**These notifications go to our server. They do not send an email or a notification to the student's phone.** Email or phone alerts would need a separate implementation.

The goal is to keep payment status and Pro access consistent across the Android app, website, and manager membership records.

## 2. What is completed, and what is still pending

This is a setup record, not proof that production billing is fully working. Console steps below were confirmed by screenshots or the owner's messages; production delivery has not been independently verified.

| Item | Status recorded on 17 October 2026 |
| --- | --- |
| Pro subscription product | Created: `quiz_lab_pro_monthly` |
| Monthly base plan | Screenshot confirmed `monthly`, monthly auto-renewing, Active, available in 175 countries/regions |
| India monthly price | Intended price: ₹99; recheck the saved price before launch |
| Overseas prices | Higher regional prices requested; exact saved amounts are not recorded here |
| Seven-day trial | Planned offer ID: `trial-7-days`; verify its exact ID, eligibility, and Active status in Play Console |
| Annual plan | Discussed and owner said done; exact saved ID, price, and status were not verified. App selection still needs work before offering it |
| Pub/Sub topic and subscription | Created; subscription used Pull for initial testing |
| Google Play publishing permission | Added; test message successfully reached the Cloud subscription |
| Push authentication service account | Created: `quizlab-rtdn-push` |
| Pub/Sub service agent permission | Screenshot at 13:40 IST confirmed Service Account Token Creator directly on the push account for `service-990282572765@gcp-sa-pubsub.iam.gserviceaccount.com` |
| Laravel RTDN receiver | Implemented locally, with local automated checks recorded in the deployment guide |
| Hostinger receiver deployment and environment | Pending verification |
| Authenticated Push delivery | Pending; keep Pull until the receiver is deployed |
| Real purchase, renewal, restore, and expiry tests | Pending |

The immediate next step after the permission grant is **deploying and configuring the backend receiver**, then switching the existing subscription to authenticated Push and testing it.

## 3. Product, base plan, and offer mean different things

| Term | Meaning for Quiz LAB | Why it helps |
| --- | --- | --- |
| Subscription product | The Pro membership being sold: `quiz_lab_pro_monthly` | Connects the Play purchase to the product our app/backend recognize |
| Base plan | The standard payment schedule and regional prices; current supported plan is `monthly` | Defines how often the student pays |
| Offer | A special starting phase attached to a base plan, such as seven free days | Lets eligible students try Pro before the normal recurring price starts |
| One-time product | A separate purchase paid once | Only needed if we implement something such as a separately purchased paper pack; unnecessary for recurring Pro alone |

A base plan ID is a label. Naming it `monthly` does not set its billing period: choose **Monthly** in the billing-period field. An earlier screenshot showed Weekly while the ID said monthly; the later Active plan screenshot confirmed Monthly.

The proposed trial flow is seven free days, followed by the regular monthly price unless the student cancels. Eligibility and availability must be configured in Play Console, and the app must select the appropriate offer.

An annual plan can offer a lower effective monthly cost and collect a year's payment up front. ₹999/year in India was discussed, but is not verified configuration. The current Flutter membership card has monthly wording and does not explicitly select an annual base plan. Keep annual purchasing unavailable in the app until plan selection, displayed terms, and purchase/restore flows are updated and tested.

Regional pricing follows the buyer's Google Play country/region, not their nationality. A student abroad sees that region's configured currency and price. No final overseas price table is preserved in this record.

### Subscription details and icon

The Console screenshot showed the name **Quiz LAB Pro** and these benefits: video solutions, downloading papers for offline practice, and turning uploaded PDFs into tests.

A reusable description, within the Console's 200-character limit:

> Unlock video solutions, download papers for offline practice, and turn your uploaded PDFs into tests with Quiz LAB Pro.

The icon requirements shown in Console were **32-bit PNG**, no more than **8 MB**, square **1:1**, with each side between **512 and 1080 pixels**. A 1024 × 1024 RGBA PNG fits those dimensions and bit depth; also check the final exported file size.

The final supplied screenshot showed **Digital app sales**, **Digital content**, and **All ages**. These are recorded selections, not an independent tax or age-rating assessment; review them if the paid content changes.

## 4. How the pieces work together

```text
Student buys Pro through Google Play in the Android app
    -> App sends the purchase token to the Quiz LAB backend
    -> Backend verifies the purchase with Google's Developer API
    -> Backend links the purchase to the signed-in Quiz LAB account
    -> Backend grants the appropriate Pro access

Later: payment/subscription state changes
    -> Google Play publishes an RTDN event to our Cloud topic
    -> Pub/Sub delivers it through our subscription
    -> Authenticated HTTPS request reaches our backend receiver
    -> Backend checks Google's latest subscription record
    -> Backend updates the shared membership records
```

The RTDN event is a signal to check Google. It is not the complete subscription record. Our receiver uses the Developer API response to decide access. See [Google's RTDN setup explanation](https://developer.android.com/google/play/billing/getting-ready).

## 5. Names and values to keep for future maintenance

| Setting | Value |
| --- | --- |
| App | Quiz LAB: Practice & Prepare |
| Android package | `in.genziitian.quizlab` |
| Google Cloud project ID | `teaching-lms` |
| Project number | `990282572765`, identified from the confirmed Pub/Sub service agent in the screenshot |
| Pro product ID | `quiz_lab_pro_monthly` |
| Supported base plan ID | `monthly` |
| Proposed trial offer ID | `trial-7-days` — verify exact saved ID |
| Topic ID | `quizlab-play-rtdn` |
| Full topic name | `projects/teaching-lms/topics/quizlab-play-rtdn` |
| Subscription ID | `quizlab-play-rtdn-sub` |
| Full subscription name | `projects/teaching-lms/subscriptions/quizlab-play-rtdn-sub` |
| Push service account | `quizlab-rtdn-push@teaching-lms.iam.gserviceaccount.com` |
| Receiver URL | `https://labapi.genziitian.in/public/api/membership/google-play/notifications` |
| Push audience | Exactly the receiver URL above |

The project ID and project number are different. Do not put `teaching-lms` in the numeric project-number placeholder.

## 6. The accounts and permissions: who does what

| Identity | Job | Required access for this setup |
| --- | --- | --- |
| `google-play-developer-notifications@system.gserviceaccount.com` | Google Play publishes billing events | Pub/Sub Publisher on our topic |
| `service-990282572765@gcp-sa-pubsub.iam.gserviceaccount.com` | Google's Pub/Sub service agent creates the delivery identity token | Service Account Token Creator on our push service account |
| `quizlab-rtdn-push@teaching-lms.iam.gserviceaccount.com` | Identity presented to our backend on Push requests | Selected as the Push authentication account; no JSON key needed |
| Separate billing API service account | Backend reads/verifies purchases and performs supported billing actions | App access in Play Console, including financial data and order/subscription permissions required by those actions; private backend credentials |
| Person configuring Push delivery | Saves the subscription's authentication settings | Permission to act as the push account, such as Service Account User, plus permission to edit the subscription |

The push account and billing API account serve separate purposes. Do not replace the billing JSON with a key for the push account. The Play Console RSA licensing public key is also separate from both accounts.

Token Creator is granted **to the Pub/Sub service agent on the push account**. Giving the push account a project role through its Permissions → Manage access screen does not create that relationship. [Google documents this permission relationship here](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions).

## 7. How we configured Cloud and Play Console

### Topic and initial Pull test

In Google Cloud project `teaching-lms`, we created the topic `quizlab-play-rtdn` with a default subscription. We kept Google-managed encryption and did not add a schema, ingestion, exports, or transforms. The subscription was used in Pull mode to inspect the first test message.

A topic is the channel Google publishes into. A subscription is the inbox/delivery route attached to it. A **Pub/Sub subscription is not a paid student subscription**.

We granted the Google Play publisher account **Pub/Sub Publisher** on the topic. In Play Console → Monetization setup, we enabled RTDN, entered the full topic name, selected **Subscriptions and voided purchases only**, and sent a test. The message was received in Cloud. [Official setup steps](https://developer.android.com/google/play/billing/getting-ready).

### Push identity and the permission just added

We created **Quiz LAB RTDN Push**, ID `quizlab-rtdn-push`, without downloading a JSON key or adding broad project roles.

To allow authenticated delivery:

1. Find the numeric Project number in Google Cloud Dashboard → Project info.
2. Open IAM & Admin → Service Accounts → Quiz LAB RTDN Push.
3. Open **Principals with access → Grant access**.
4. Enter `service-PROJECT_NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com`, replacing the placeholder with that number.
5. Select **Service Account Token Creator** and save.

The 17 October 2026, 13:40 IST screenshot confirmed the direct Token Creator grant to `service-990282572765@gcp-sa-pubsub.iam.gserviceaccount.com`. It also showed the inherited Cloud Pub/Sub Service Agent role separately. The grant became visible with **Include Google-provided role grants** checked and **View by roles** selected. If it appears missing later, check that visibility option before adding permissions again.

## 8. Backend environment: what each setting is for

These settings belong in the **deployed Laravel backend environment**. The current Flutter app already queries product `quiz_lab_pro_monthly`; do not add a service-account JSON or private billing credential to Flutter assets or build variables.

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

Replace the JSON path with the real private server path and verify the trial offer ID. This is configuration to apply, not a claim that production already has these values.

| Settings | Purpose |
| --- | --- |
| Package and product | Identify the app and Pro purchase |
| Base plan and trial offer | Identify the configured monthly plan and introductory offer |
| Regions version | Region version used by the existing Play price-management code |
| Service account JSON | Private billing API credentials used by the backend |
| RTDN topic | Records the publishing channel; setting it alone does not connect delivery |
| RTDN subscription | Must match the subscription in the received message envelope |
| RTDN audience | Must match the intended receiver URL in Google's identity token |
| RTDN service account email | Identifies the allowed Push sender |

Keep the billing JSON outside `public_html` and out of Git. Preserve the existing production `.env` and application key during deployment.

## 9. Remaining deployment steps, in order

Use [GOOGLE_PLAY_RTDN_SETUP.md](GOOGLE_PLAY_RTDN_SETUP.md) for the detailed deployment procedure and local test evidence. A prepared bundle is at [output/deployment/quizlab-rtdn-backend.zip](../output/deployment/quizlab-rtdn-backend.zip); review it against current source before any later deployment.

1. Deploy the receiver, authentication service, membership sync service, routes, configuration, and migration to Hostinger.
2. Set the backend environment above. Ensure the separate billing API account has working Play access.
3. From the deployed Laravel backend directory, run:

   ```sh
   php artisan migrate --force
   php artisan optimize:clear
   ```

4. Confirm the receipt table migration completed. The host must forward the Authorization header and allow outbound HTTPS to Google's authentication and Developer API endpoints.
5. Edit the existing Cloud subscription `quizlab-play-rtdn-sub` and configure:

   | Field | Value |
   | --- | --- |
   | Delivery type | Push |
   | Endpoint | Receiver URL from section 5 |
   | Authentication | Enabled |
   | Service account | `quizlab-rtdn-push@teaching-lms.iam.gserviceaccount.com` |
   | Audience | Exactly the receiver URL |
   | Payload unwrapping | Disabled; keep the normal message envelope |
   | Acknowledgement deadline | 60 seconds |
   | Retry policy | Exponential backoff, 10 seconds minimum / 600 seconds maximum |

6. Send another Play Console test. Confirm backend delivery using the checks below.
7. Complete real purchase lifecycle tests with a Play license tester before launch.

This receiver does not require a new Composer package or a queue worker. Its deployment alone does not require a Flutter rebuild; annual-plan UI changes would.

## 10. How it helps, with concrete examples

The following describes the locally implemented receiver's behavior once deployed and connected. It is not evidence of live delivery yet.

| Situation | Backend behavior | Benefit |
| --- | --- | --- |
| Renewal succeeds | Fetches Google's current record and updates access dates | Paid students retain Pro |
| Student cancels renewal | Preserves valid remaining access until its expiry | Cancellation does not unfairly remove time already granted |
| Payment is in grace period | Keeps access while Google's current record permits it | Student gets time to fix payment |
| Account goes on hold or subscription is paused | Removes entitlement from that subscription while access is suspended | Membership follows the actual payment state |
| Subscription expires | Stops granting access from that subscription | Expired purchases do not remain Pro indefinitely |
| Refund or revocation event | Checks current Google state before recalculating access | Avoids blindly removing access based on an old event |
| Same event arrives again | Recognizes a processed message ID | Retries do not apply the update twice |
| Backend or Google is temporarily unavailable | Returns a retryable error | Pub/Sub can attempt delivery again |
| Student also has a valid separate membership grant | Preserves that other entitlement | One expired Play subscription does not erase independent access |

The receiver checks Google's identity token, sender email, audience, app package, and subscription name. It updates memberships only after looking up the latest purchase state. See [Google's subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions).

## 11. What proves it is working

Each stage proves something different:

| Check | What it proves |
| --- | --- |
| Play Console says test published | Google Play could publish to the Cloud topic |
| Test message is visible in the Pull subscription | Cloud received and queued it |
| Push delivery returns HTTP 204 and a new receipt has `kind=test`, `status=processed`, and `processed_at` | The deployed backend accepted and recorded the test |
| License-test purchase changes the correct account's membership, and later renewal/cancellation/expiry change it correctly | The payment and entitlement flow works for those tested cases |

A test notification never grants Pro. Local automated tests use fake Google responses; they do not verify Hostinger or real payment behavior.

Test purchases using an app installed through the Play testing track with the intended license tester. An Android Studio debug launch proves the app can run, but does not establish a working Play purchase flow.

## 12. Troubleshooting for the future

| Symptom | Meaning / next check |
| --- | --- |
| Pull message says “Deadline exceeded” | It was not acknowledged within the delivery window; Cloud may redeliver it. This is not a student's payment failure |
| Play test publish fails | Check the full topic name and Google Play's Publisher grant |
| Push setup gives an actAs/permission error | Check the configuring person's permission to act as the push account and the Pub/Sub service agent's token-creation permission |
| Receiver returns 404 | Check deployment, API route, and the exact endpoint URL |
| Receiver returns 401/403 | Check forwarded Authorization header, selected Push account, audience, app package, and configured subscription |
| Receiver returns 503 | Check environment settings, Google/API connectivity, database, and receipt status |
| Receipt says `unlinked` | The purchase token is not linked to a Quiz LAB account yet. Have the student verify/restore the purchase in the app; never guess the owner |
| Growing backlog or repeated errors | Investigate before retention expires; retry storage is not permanent |
| Website/app membership differs | Check account identity, backend access calculation, and whether the client has refreshed its membership state |

Do not manually consume/ack production messages while the Push receiver is processing them. Receipts intentionally avoid raw purchase tokens and credentials; do not add secrets to debugging logs.

## 13. Boundaries and future work

- RTDN is important subscription infrastructure. It is not a student messaging feature, a payment gateway, or a replacement for server purchase verification.
- Unknown new purchase tokens are retried until app verification links them. Automatic ownership linking for new out-of-app purchases is not implemented.
- Annual-plan selection, final overseas pricing, and accurate overseas purchase amount/currency reporting need separate verification/work.
- Keep Pause and Play Store resubscribe disabled until their complete flows are tested; their current Console settings have not been verified here.
- Merchandising and optimization can promote eligible one-time products on Google surfaces. It is separate from the recurring Pro setup and is not required for RTDN.
- Price experiments and promo codes are optional commercial tools. No experiment or promo campaign is documented as configured.
- Alternative billing, external offers/content links, and Billing Choice are separate programs. We have not enrolled or implemented them as part of this setup; review the current rules before any future use.
- One-time product fulfillment and manual chargeback-review notifications are outside the current receiver's scope.
- Monitor delivery failures, unknown purchases, and receipt storage. There is no automatic receipt-pruning job in this implementation.
- Record future deployment dates, confirmed trial/annual IDs, test results, and pricing changes here. The project number and confirmed permission are recorded above. Never record private keys or tokens.

## 14. Related implementation and official references

- [Deployment steps, behavior, and recorded local test results](GOOGLE_PLAY_RTDN_SETUP.md)
- [Broader membership and web payment setup](PRO_MEMBERSHIPS_AND_PLAY_BILLING.md)
- [RTDN receiver](../backend/app/Http/Controllers/GooglePlayNotificationController.php)
- [Push identity verification](../backend/app/Services/GooglePlayPushAuthentication.php)
- [Membership state synchronization](../backend/app/Services/GooglePlayMembershipSync.php)
- [Google: billing and RTDN setup](https://developer.android.com/google/play/billing/getting-ready)
- [Google Cloud: authenticated Push delivery](https://docs.cloud.google.com/pubsub/docs/authenticate-push-subscriptions)
- [Google: subscription lifecycle](https://developer.android.com/google/play/billing/lifecycle/subscriptions)
- [Google: RTDN message reference](https://developer.android.com/google/play/billing/rtdn-reference)
