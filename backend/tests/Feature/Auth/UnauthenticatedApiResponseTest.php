<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Kimliksiz API isteği her zaman temiz bir 401 almalı.
 *
 * Regresyon: `Accept: application/json` göndermeyen istekler 500
 * "Server Error" alıyordu — Laravel var olmayan `route('login')`'a
 * yönlendirmeye çalışıyordu. Production smoke testinde yakalandı,
 * TÜM korumalı API uçlarını etkiliyordu.
 */
class UnauthenticatedApiResponseTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @return array<string, array{string}>
     */
    public static function protectedEndpoints(): array
    {
        return [
            'customers' => ['/api/v1/customers'],
            'jobs' => ['/api/v1/jobs'],
            'quotes' => ['/api/v1/quotes'],
            'subscription' => ['/api/v1/subscription'],
        ];
    }

    #[\PHPUnit\Framework\Attributes\DataProvider('protectedEndpoints')]
    public function test_returns_401_without_json_accept_header(string $endpoint): void
    {
        // Kasıtlı olarak `getJson` DEĞİL — Accept başlığı olmayan ham istek.
        $this->get($endpoint)
            ->assertStatus(401)
            ->assertJsonPath('message', 'Unauthenticated.');
    }

    #[\PHPUnit\Framework\Attributes\DataProvider('protectedEndpoints')]
    public function test_returns_401_with_json_accept_header(string $endpoint): void
    {
        $this->getJson($endpoint)->assertStatus(401);
    }
}
