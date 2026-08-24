<?php

declare(strict_types=1);

namespace Tests\Feature\Push;

use App\Models\DeviceToken;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Ölü cihaz token'larının temizlenmesi — kalıcı olarak geçersiz token'lar
 * silinmeli, geçici hatalarda kayıt KORUNMALIDIR (aksi halde tek bir
 * sunucu hıçkırığı kullanıcının bildirimlerini kalıcı olarak kapatırdı).
 */
class FcmDeadTokenTest extends TestCase
{
    use RefreshDatabase;

    private function makeToken(string $token): void
    {
        $user = User::factory()->create();
        DeviceToken::create([
            'user_id' => $user->id,
            'company_id' => $user->company_id,
            'token' => $token,
            'platform' => 'android',
        ]);
    }

    private function fakeCredentials(): void
    {
        // Gerçek anahtar olmadan erişim jetonu adımını taklit ediyoruz.
        config(['services.fcm.credentials' => $this->credentialsFixture(), 'services.fcm.project_id' => 'test-project']);
    }

    private function credentialsFixture(): string
    {
        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
        openssl_pkey_export($key, $pem);

        $path = storage_path('app/test-fcm-credentials.json');
        file_put_contents($path, json_encode([
            'client_email' => 'test@example.iam.gserviceaccount.com',
            'private_key' => $pem,
            'project_id' => 'test-project',
        ]));

        return $path;
    }

    protected function tearDown(): void
    {
        @unlink(storage_path('app/test-fcm-credentials.json'));
        parent::tearDown();
    }

    public function test_deletes_token_when_fcm_reports_it_unregistered(): void
    {
        $this->fakeCredentials();
        $this->makeToken('dead-token');

        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'fake'], 200),
            'fcm.googleapis.com/*' => Http::response(['error' => ['message' => 'Requested entity was not found.']], 404),
        ]);

        app(FcmService::class)->sendToTokens(['dead-token'], 'x', 'y');

        $this->assertDatabaseMissing('device_tokens', ['token' => 'dead-token']);
    }

    public function test_deletes_token_when_message_says_registration_token_invalid(): void
    {
        $this->fakeCredentials();
        $this->makeToken('malformed-token');

        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'fake'], 200),
            'fcm.googleapis.com/*' => Http::response([
                'error' => ['message' => 'The registration token is not a valid FCM registration token'],
            ], 400),
        ]);

        app(FcmService::class)->sendToTokens(['malformed-token'], 'x', 'y');

        $this->assertDatabaseMissing('device_tokens', ['token' => 'malformed-token']);
    }

    public function test_keeps_token_when_error_is_our_own_bad_payload(): void
    {
        $this->fakeCredentials();
        $this->makeToken('good-token');

        // 400 ama sebep token değil, gönderdiğimiz mesaj — kaydı SİLME.
        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'fake'], 200),
            'fcm.googleapis.com/*' => Http::response([
                'error' => ['message' => 'Invalid JSON payload received.'],
            ], 400),
        ]);

        app(FcmService::class)->sendToTokens(['good-token'], 'x', 'y');

        $this->assertDatabaseHas('device_tokens', ['token' => 'good-token']);
    }

    public function test_keeps_token_on_transient_server_error(): void
    {
        $this->fakeCredentials();
        $this->makeToken('transient-token');

        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'fake'], 200),
            'fcm.googleapis.com/*' => Http::response(['error' => ['message' => 'Internal error']], 503),
        ]);

        app(FcmService::class)->sendToTokens(['transient-token'], 'x', 'y');

        $this->assertDatabaseHas('device_tokens', ['token' => 'transient-token']);
    }

    public function test_reports_number_of_successful_sends(): void
    {
        $this->fakeCredentials();

        Http::fake([
            'oauth2.googleapis.com/*' => Http::response(['access_token' => 'fake'], 200),
            'fcm.googleapis.com/*' => Http::response(['name' => 'projects/x/messages/1'], 200),
        ]);

        $sent = app(FcmService::class)->sendToTokens(['a', 'b'], 'x', 'y');

        $this->assertSame(2, $sent);
    }
}
