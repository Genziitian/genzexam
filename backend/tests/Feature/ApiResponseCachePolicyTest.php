<?php

namespace Tests\Feature;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class ApiResponseCachePolicyTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        foreach (['api', 'public/api'] as $prefix) {
            Route::get($prefix.'/__cache-policy/success', fn () => response()
                ->json(['ok' => true])
                ->header('Cache-Control', 'public, max-age=3600, s-maxage=7200'));
            Route::post($prefix.'/__cache-policy/validate', function (Request $request) {
                $request->validate(['title' => ['required', 'string']]);

                return response()->json(['ok' => true]);
            });
            Route::get($prefix.'/__cache-policy/forbidden', fn () => abort(403, 'Fixture forbidden.'));
        }

        Route::get('__cache-policy-web', fn () => response('Public web page')
            ->header('Cache-Control', 'public, max-age=3600'));
        Route::get('public/apiculture', fn () => response('Unrelated web page')
            ->header('Cache-Control', 'public, max-age=3600'));
    }

    public static function apiPrefixes(): array
    {
        return ['standard API prefix' => ['/api'], 'deployed API prefix' => ['/public/api']];
    }

    private function assertPrivateNoStore($response): void
    {
        $headers = $response->baseResponse->headers;
        $this->assertTrue($headers->hasCacheControlDirective('private'));
        $this->assertTrue($headers->hasCacheControlDirective('no-store'));
        $this->assertFalse($headers->hasCacheControlDirective('public'));
        $this->assertFalse($headers->hasCacheControlDirective('max-age'));
        $this->assertFalse($headers->hasCacheControlDirective('s-maxage'));
    }

    #[DataProvider('apiPrefixes')]
    public function test_api_success_overrides_cacheable_response_headers(string $prefix): void
    {
        $response = $this->getJson($prefix.'/__cache-policy/success')
            ->assertOk()->assertJsonPath('ok', true);

        $this->assertPrivateNoStore($response);
    }

    public function test_real_authentication_failure_has_the_api_cache_policy(): void
    {
        $response = $this->getJson('/public/api/courses')
            ->assertUnauthorized()->assertJsonPath('message', 'Unauthenticated.');

        $this->assertPrivateNoStore($response);
    }

    #[DataProvider('apiPrefixes')]
    public function test_validation_exception_response_has_the_api_cache_policy(string $prefix): void
    {
        $response = $this->postJson($prefix.'/__cache-policy/validate', [])
            ->assertUnprocessable()->assertJsonValidationErrors('title');

        $this->assertPrivateNoStore($response);
    }

    #[DataProvider('apiPrefixes')]
    public function test_missing_api_route_has_the_api_cache_policy(string $prefix): void
    {
        $response = $this->getJson($prefix.'/__cache-policy/missing')->assertNotFound();

        $this->assertPrivateNoStore($response);
    }

    #[DataProvider('apiPrefixes')]
    public function test_forbidden_exception_response_has_the_api_cache_policy(string $prefix): void
    {
        $response = $this->getJson($prefix.'/__cache-policy/forbidden')->assertForbidden();

        $this->assertPrivateNoStore($response);
    }

    public function test_web_responses_keep_their_original_cache_policy(): void
    {
        foreach (['/__cache-policy-web', '/public/apiculture'] as $path) {
            $response = $this->get($path)->assertOk();
            $headers = $response->baseResponse->headers;
            $this->assertTrue($headers->hasCacheControlDirective('public'));
            $this->assertSame('3600', $headers->getCacheControlDirective('max-age'));
            $this->assertFalse($headers->hasCacheControlDirective('no-store'));
        }
    }
}
