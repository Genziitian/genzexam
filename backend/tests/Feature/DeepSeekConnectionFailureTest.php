<?php

namespace Tests\Feature;

use App\Exceptions\DeepSeekGenerationException;
use App\Services\DeepSeekQuizGenerator;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class DeepSeekConnectionFailureTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config([
            'services.deepseek.key' => 'fixture-key',
            'services.deepseek.endpoint' => 'https://api.deepseek.com/chat/completions',
            'services.deepseek.model' => 'deepseek-chat',
            'services.deepseek.max_input_chars' => 60000,
            'services.deepseek.max_questions' => 100,
        ]);
        Http::preventStrayRequests();
    }

    public static function connectionFailures(): array
    {
        return [
            'connection failure' => ['cURL error 6: Could not resolve host: api.deepseek.com'],
            'provider timeout' => ['cURL error 28: Operation timed out after 300000 milliseconds'],
        ];
    }

    #[DataProvider('connectionFailures')]
    public function test_provider_connection_failure_is_a_conversion_error(string $details): void
    {
        Http::fake([
            'https://api.deepseek.com/chat/completions' => Http::failedConnection($details),
        ]);

        try {
            $this->app->make(DeepSeekQuizGenerator::class)
                ->generateFromText('1. What is 1 + 1? Answer: 2.');
            $this->fail('A provider connection failure must be reported as a conversion failure.');
        } catch (DeepSeekGenerationException $exception) {
            $this->assertSame(
                'The paper conversion service could not be reached. Please try again shortly.',
                $exception->getMessage()
            );
            $this->assertInstanceOf(ConnectionException::class, $exception->getPrevious());
            $this->assertStringContainsString($details, $exception->getPrevious()->getMessage());
        }

        Http::assertSentCount(1);
    }

    public function test_successful_conversion_still_returns_the_validated_payload(): void
    {
        $payload = [
            'schema_version' => '1.1',
            'quiz_title' => 'Addition practice',
            'subject' => 'Mathematics',
            'questions' => [['type' => 'numerical', 'stem' => 'What is 1 + 1?', 'numerical_answer' => 2]],
        ];
        Http::fake([
            'https://api.deepseek.com/chat/completions' => Http::response([
                'choices' => [['finish_reason' => 'stop', 'message' => ['content' => json_encode($payload)]]],
            ]),
        ]);

        $this->assertSame($payload, $this->app->make(DeepSeekQuizGenerator::class)
            ->generateFromText('1. What is 1 + 1? Answer: 2.'));
        Http::assertSentCount(1);
    }

    public function test_successful_http_response_still_requires_a_valid_conversion_payload(): void
    {
        Http::fake([
            'https://api.deepseek.com/chat/completions' => Http::response([
                'choices' => [['finish_reason' => 'stop', 'message' => ['content' => '{"questions":[]}']]],
            ]),
        ]);

        $this->expectException(DeepSeekGenerationException::class);
        $this->expectExceptionMessage('Generated JSON is missing schema_version.');

        $this->app->make(DeepSeekQuizGenerator::class)
            ->generateFromText('1. What is 1 + 1? Answer: 2.');
    }
}
