<?php

declare(strict_types=1);

namespace App\Models;

use App\Notifications\NewFeedbackReceived;
use App\Services\FcmService;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Notification;

/**
 * Kullanıcının uygulama içinden gönderdiği geri bildirim.
 *
 * NEDEN AppLog DEĞİL: tanılama kanalı KAYIT tutuyor — budanıyor, durumu
 * yok, cevabı yok. Geri bildirim üçünü de gerektiriyor; kullanıcı bir şey
 * soruyor ve cevap bekliyor.
 */
class Feedback extends Model
{
    use HasUuids;

    /**
     * Tablo adı AÇIKÇA veriliyor.
     *
     * Laravel "feedback"i sayılamayan isim sayıyor ve çoğulunu yine
     * `feedback` olarak üretiyor; tablo ise `feedbacks`. Açıkça
     * yazılmazsa model var olmayan bir tabloyu arıyor.
     */
    protected $table = 'feedbacks';

    public const TYPES = ['ONERI', 'HATA', 'SORU', 'DIGER'];

    public const STATUSES = ['YENI', 'INCELENIYOR', 'YANITLANDI', 'KAPANDI'];

    protected $fillable = [
        'company_id', 'user_id', 'type', 'message', 'status',
        'reply', 'replied_at', 'app_version', 'platform', 'device',
    ];

    protected function casts(): array
    {
        return ['replied_at' => 'datetime'];
    }

    protected static function booted(): void
    {
        // Her yeni geri bildirim adminlere e-postayla bildirilir. Panele
        // bakılmadığı sürece görünmeyen bir kutu, geri bildirim kanalı
        // değildir — ödeme taleplerinde aynı gerekçeyle aynı şey yapıldı.
        //
        // Mail hatası kaydın kendisini ASLA düşürmemeli: geri bildirim
        // veritabanında ve panelde her durumda görünür.
        static::created(function (Feedback $feedback): void {
            try {
                Notification::send(AdminUser::all(), new NewFeedbackReceived($feedback));
            } catch (\Throwable $e) {
                Log::error('Geri bildirim admin bildirimi gönderilemedi', [
                    'feedback_id' => $feedback->id,
                    'error' => $e->getMessage(),
                ]);
            }
        });
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Yöneticinin cevabını kaydeder ve kullanıcıya BİLDİRİR.
     *
     * Panelde kalan bir cevap, cevap değildir. Kullanıcı geri bildirimini
     * gönderdikten sonra uygulamayı tekrar açıp bakmayı düşünmez;
     * haberdar edilmesi gerekir.
     */
    public function respond(string $reply, string $status = 'YANITLANDI'): void
    {
        $this->update([
            'reply' => $reply,
            'status' => $status,
            'replied_at' => now(),
        ]);

        try {
            app(FcmService::class)->sendToCompany(
                $this->company()->firstOrFail(),
                'Geri bildiriminize yanıt geldi',
                mb_strimwidth($reply, 0, 120, '…'),
                ['type' => 'feedback_reply', 'feedback_id' => $this->id],
            );
        } catch (\Throwable $e) {
            // Bildirim gidemezse cevap yine de kayıtlı: kullanıcı
            // uygulamadaki geri bildirim listesinde görür.
            Log::warning('Geri bildirim yanıt bildirimi gönderilemedi', [
                'feedback_id' => $this->id,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
