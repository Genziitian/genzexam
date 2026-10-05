# Razorpay paper checkout setup

The paper store uses Razorpay Standard Checkout. The app creates each order on the Laravel API using the paper's server-side price, verifies the Checkout signature, confirms that the payment is captured, and grants access in the database. Razorpay documents the server-side order and signature checks in its [Standard Checkout integration guide](https://razorpay.com/docs/server-integration/python/test-app/); INR order amounts use paise.

## API server configuration

Add these values to the Laravel API server's environment. Checkout needs the key ID and key secret; the webhook secret is required to grant access if a student closes Checkout before returning to the site. Use Razorpay **Test Mode** keys first; never put the key secret in browser code.

```dotenv
RAZORPAY_KEY_ID=rzp_test_...
RAZORPAY_KEY_SECRET=...
RAZORPAY_WEBHOOK_SECRET=...
```

After changing environment values on a server with cached config, clear Laravel's config cache.

## Webhook

In Razorpay Dashboard → Account & Settings → Webhooks, register the API URL and a webhook secret matching `RAZORPAY_WEBHOOK_SECRET`. Enable `payment.captured` and automatic payment capture. The endpoint is:

```text
https://labapi.genziitian.in/public/api/storefront/razorpay/webhook
```

The webhook signature is checked over the raw request body. The handler also checks the captured amount and currency against the stored order. Razorpay recommends validating webhook HMAC signatures and using trusted server-side order IDs and payment amounts in its [security checklist](https://razorpay.com/security/checklist).

## Pricing

Open `/paper-pricing` with a manager account. Prices are entered in whole rupees and stored in paise. Set a price of `0` for a free paper; optionally set an access duration in days. The migration gives existing papers a price of zero, so current free practice stays available until a manager changes a paper's price.

## Deployment note

Checkout is unavailable until the Razorpay key ID and key secret are configured on the Laravel API server. Configure the webhook secret and automatic capture as well for the complete purchase flow. Use the same key pair's mode consistently in Razorpay Checkout and the server environment. Configure and verify the webhook in Test Mode before switching to Live Mode.

For local development, serve this site's static files on port `3000` and the Laravel API on port `8000`; the paper pages use that local API address. If a custom `CORS_ALLOWED_ORIGINS` list is configured, include the local site origin there too.
