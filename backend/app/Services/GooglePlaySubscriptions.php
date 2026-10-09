<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

class GooglePlaySubscriptions
{
    private function credentials(): array
    {
        $source = (string) config('services.google_play.service_account_json');
        if ($source === '') throw new RuntimeException('Google Play billing credentials are not configured.');
        $json = ! str_starts_with(ltrim($source), '{') && is_file($source) ? file_get_contents($source) : $source;
        $credentials = json_decode((string) $json, true);
        if (! is_array($credentials) || empty($credentials['client_email']) || empty($credentials['private_key'])) {
            throw new RuntimeException('Google Play service-account JSON is invalid.');
        }
        return $credentials;
    }

    private function accessToken(): string
    {
        $credentials = $this->credentials();
        $encode = fn (string $value) => rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
        $now = time();
        $header = $encode(json_encode(['alg' => 'RS256', 'typ' => 'JWT'], JSON_THROW_ON_ERROR));
        $claims = $encode(json_encode([
            'iss' => $credentials['client_email'],
            'scope' => 'https://www.googleapis.com/auth/androidpublisher',
            'aud' => 'https://oauth2.googleapis.com/token',
            'iat' => $now,
            'exp' => $now + 3600,
        ], JSON_THROW_ON_ERROR));
        $unsigned = $header.'.'.$claims;
        $key = openssl_pkey_get_private($credentials['private_key']);
        if (! $key || ! openssl_sign($unsigned, $signature, $key, OPENSSL_ALGO_SHA256)) {
            throw new RuntimeException('Could not sign Google Play API credentials.');
        }
        $jwt = $unsigned.'.'.$encode($signature);
        $response = Http::asForm()->connectTimeout(5)->timeout(15)->post('https://oauth2.googleapis.com/token', [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt,
        ]);
        if (! $response->successful() || ! $response->json('access_token')) throw new RuntimeException('Google Play authorization failed. Check service-account access and credentials.');
        return (string) $response->json('access_token');
    }

    public function get(string $purchaseToken): array
    {
        $package = (string) config('services.google_play.package_name');
        if ($package === '') throw new RuntimeException('Google Play package name is not configured.');
        $url = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'.rawurlencode($package).'/purchases/subscriptionsv2/tokens/'.rawurlencode($purchaseToken);
        $response = Http::withToken($this->accessToken())->connectTimeout(5)->timeout(15)->get($url);
        if (! $response->successful()) throw new RuntimeException('Google Play could not verify this subscription purchase.');
        return $response->json();
    }

    public function cancel(string $purchaseToken, string $reason): void
    {
        $package = (string) config('services.google_play.package_name');
        if ($package === '') throw new RuntimeException('Google Play package name is not configured.');
        $url = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'.rawurlencode($package).'/purchases/subscriptionsv2/tokens/'.rawurlencode($purchaseToken).':cancel';
        $response = Http::withToken($this->accessToken())->connectTimeout(5)->timeout(15)->post($url, [
            'cancellationContext' => ['cancellationType' => $reason === 'manager' ? 'DEVELOPER_REQUESTED_STOP_PAYMENTS' : 'USER_REQUESTED_STOP_RENEWALS'],
        ]);
        if (! $response->successful()) throw new RuntimeException('Google Play could not cancel this subscription.');
    }

    public function revoke(string $purchaseToken, string $refundType = 'prorated'): void
    {
        $package = (string) config('services.google_play.package_name');
        if ($package === '') throw new RuntimeException('Google Play package name is not configured.');
        $url = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'.rawurlencode($package).'/purchases/subscriptionsv2/tokens/'.rawurlencode($purchaseToken).':revoke';
        $context = $refundType === 'full' ? ['fullRefund' => (object) []] : ['proratedRefund' => (object) []];
        $response = Http::withToken($this->accessToken())->connectTimeout(5)->timeout(15)->post($url, ['revocationContext' => $context]);
        if (! $response->successful()) throw new RuntimeException('Google Play could not revoke this subscription and process its refund.');
    }

    public function acknowledge(string $purchaseToken, string $productId): void
    {
        $package = (string) config('services.google_play.package_name');
        if ($package === '') throw new RuntimeException('Google Play package name is not configured.');
        $url = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'.rawurlencode($package).'/purchases/subscriptions/'.rawurlencode($productId).'/tokens/'.rawurlencode($purchaseToken).':acknowledge';
        $response = Http::withToken($this->accessToken())->connectTimeout(5)->timeout(15)->post($url, []);
        if (! $response->successful()) throw new RuntimeException('Google Play could not acknowledge this subscription purchase.');
    }

    public function updateIndiaBasePlanPrice(int $amountPaise): void
    {
        $package = (string) config('services.google_play.package_name');
        $productId = (string) config('services.google_play.subscription_product_id');
        $basePlanId = (string) config('services.google_play.subscription_base_plan_id');
        $regionsVersion = (string) config('services.google_play.regions_version');
        if ($package === '' || $productId === '' || $basePlanId === '' || $regionsVersion === '') {
            throw new RuntimeException('Google Play price management needs package, product, base plan, and regions version configuration.');
        }
        $root = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'.rawurlencode($package).'/subscriptions/'.rawurlencode($productId);
        $http = Http::withToken($this->accessToken())->connectTimeout(5)->timeout(20);
        $current = $http->get($root);
        if (! $current->successful()) throw new RuntimeException('Google Play could not load the Pro subscription catalog item.');
        $subscription = $current->json();
        $foundPlan = false;
        $basePlans = $subscription['basePlans'] ?? [];
        foreach ($basePlans as &$basePlan) {
            if (($basePlan['basePlanId'] ?? null) !== $basePlanId) continue;
            $foundPlan = true;
            $foundIndia = false;
            $regionalConfigs = $basePlan['regionalConfigs'] ?? [];
            foreach ($regionalConfigs as &$region) {
                if (($region['regionCode'] ?? null) !== 'IN') continue;
                $foundIndia = true;
                $region['price'] = [
                    'currencyCode' => 'INR',
                    'units' => (string) intdiv($amountPaise, 100),
                    'nanos' => ($amountPaise % 100) * 10000000,
                ];
            }
            unset($region);
            if (! $foundIndia) throw new RuntimeException('Add India (INR) to this Play base plan before setting its price from the manager panel.');
            $basePlan['regionalConfigs'] = $regionalConfigs;
        }
        unset($basePlan);
        if (! $foundPlan) throw new RuntimeException('The configured Google Play base plan ID was not found.');
        $subscription['basePlans'] = $basePlans;
        $query = http_build_query(['updateMask' => 'basePlans', 'regionsVersion.version' => $regionsVersion]);
        $updated = $http->patch($root.'?'.$query, $subscription);
        if (! $updated->successful()) throw new RuntimeException('Google Play rejected the new base plan price. Check the service-account permissions and regions version.');
    }
}
