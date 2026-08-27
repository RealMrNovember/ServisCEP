<?php

declare(strict_types=1);

namespace Tests\Feature\Feedback;

use App\Models\Feedback;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

/**
 * Kullanıcı geri bildirimi.
 *
 * Tanılama ucundan (`/diagnostics`) bilinçli olarak AYRI: tanılama
 * makinenin ürettiği kayıt, bu insanın yazdığı mesaj. Tanılama budanıyor
 * ve cevaplanmıyor; geri bildirim kalıcı ve cevap bekliyor.
 */
class FeedbackTest extends TestCase
{
    use RefreshDatabase;

    private function girisYap(): User
    {
        $user = User::factory()->create();
        $this->withToken($user->createToken('test')->plainTextToken);

        return $user;
    }

    public function test_a_user_can_send_feedback(): void
    {
        Notification::fake();
        $user = $this->girisYap();

        $this->postJson('/api/v1/feedback', [
            'type' => 'ONERI',
            'message' => 'Teklif ekranında kalem sırasını değiştirebilmek isterdim.',
        ])->assertCreated()
            ->assertJsonPath('data.status', 'YENI')
            ->assertJsonPath('data.status_label', 'Alındı');

        $this->assertDatabaseHas('feedbacks', [
            'company_id' => $user->company_id,
            'user_id' => $user->id,
            'type' => 'ONERI',
            'status' => 'YENI',
        ]);
    }

    /**
     * Künye başlıklardan okunuyor: kullanıcıya "hangi sürümü
     * kullanıyorsunuz" diye sormak zorunda kalmamak için.
     */
    public function test_feedback_records_the_client_version(): void
    {
        Notification::fake();
        $this->girisYap();

        $this->withHeaders([
            'X-App-Version' => '0.7.8',
            'X-Platform' => 'android',
            'X-Device-Model' => 'Pixel 7',
        ])->postJson('/api/v1/feedback', [
            'message' => 'Senkron çok yavaş çalışıyor.',
        ])->assertCreated();

        $this->assertDatabaseHas('feedbacks', [
            'app_version' => '0.7.8',
            'platform' => 'android',
            'device' => 'Pixel 7',
        ]);
    }

    public function test_an_empty_or_too_short_message_is_rejected(): void
    {
        $this->girisYap();

        $this->postJson('/api/v1/feedback', ['message' => ''])
            ->assertStatus(422);
        $this->postJson('/api/v1/feedback', ['message' => 'iyi'])
            ->assertStatus(422);
    }

    public function test_feedback_requires_authentication(): void
    {
        // Tanılamanın AKSİNE kimlik zorunlu: cevap yazılacak, kimin
        // yazdığı bilinmeyen bir mesaja cevap gönderilemez.
        $this->postJson('/api/v1/feedback', [
            'message' => 'Kimliksiz gönderim denemesi.',
        ])->assertStatus(401);
    }

    /**
     * Yanıt kullanıcıya ULAŞIR ve kayıtta durur.
     *
     * Bildirim kaybolur, kayıt kalır — aynı ilke ödeme taleplerinde de
     * uygulandı.
     */
    public function test_a_reply_reaches_the_user_and_stays_in_the_record(): void
    {
        Notification::fake();
        $user = $this->girisYap();

        $feedback = Feedback::create([
            'company_id' => $user->company_id,
            'user_id' => $user->id,
            'type' => 'SORU',
            'message' => 'Proformayı nasıl faturaya çeviriyorum?',
        ]);

        $feedback->respond('Şu an fatura modülü yok; yol haritasında.');

        $this->getJson('/api/v1/feedback')
            ->assertOk()
            ->assertJsonPath('data.0.status', 'YANITLANDI')
            ->assertJsonPath('data.0.reply', 'Şu an fatura modülü yok; yol haritasında.');
    }

    /**
     * Kullanıcı YALNIZCA kendi şirketinin geri bildirimlerini görür.
     */
    public function test_feedback_is_scoped_to_the_users_company(): void
    {
        Notification::fake();
        $baskasi = User::factory()->create();
        Feedback::create([
            'company_id' => $baskasi->company_id,
            'user_id' => $baskasi->id,
            'message' => 'Başka şirketin geri bildirimi.',
        ]);

        $this->girisYap();

        $this->getJson('/api/v1/feedback')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }
}
