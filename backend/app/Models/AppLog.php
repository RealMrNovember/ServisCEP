<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

/**
 * Tek bir olay kaydı — bkz. create_app_logs_table migration'ı.
 *
 * Bu model BelongsToCompany kullanmaz: günlük, şirket kapsamından bağımsız
 * olarak yalnızca süper admin panelinden görülür ve kimlik doğrulanamadan
 * önce oluşan olayları (giriş yapamayan bir cihaz gibi) da taşımak
 * zorundadır — o anda ortada bir şirket yoktur.
 */
class AppLog extends Model
{
    use HasUuids;

    public const UPDATED_AT = null;

    /** Olayın nereden geldiği. */
    public const SOURCE_SERVER = 'server';

    public const SOURCE_REQUEST = 'request';

    public const SOURCE_MOBILE = 'mobile';

    protected $fillable = [
        'level', 'source', 'message', 'context',
        'user_id', 'company_id',
        'method', 'path', 'status', 'duration_ms',
        'ip', 'platform', 'app_version', 'device',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'context' => 'array',
            'status' => 'integer',
            'duration_ms' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        // Kullanıcı silinmiş olabilir; ilişki null döner ve kayıt yine de
        // okunur kalır (ip/sürüm/yol alanları kaydın kendisinde duruyor).
        return $this->belongsTo(User::class);
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    /**
     * Belirli bir olayı doğrudan günlüğe yazar.
     *
     * Neden Log facade'ı değil: production'da `LOG_LEVEL=error` olduğu
     * için `info` seviyesindeki kayıtlar hiçbir yere düşmüyor. Oysa
     * "kim ne zaman giriş yaptı" tam olarak `info` seviyesinde bir bilgi
     * ve destek tarafında en sık sorulan sorulardan biri. Seviyeyi genel
     * olarak düşürmek her framework mesajını da içeri alırdı; bu yüzden
     * bilinçli seçilmiş olaylar doğrudan yazılır.
     *
     * Yazma başarısız olursa sessizce vazgeçilir — bir olayı
     * kaydedememek, o isteği bozmaktan iyidir.
     */
    public static function event(
        string $message,
        array $context = [],
        ?User $user = null,
        string $level = 'info',
    ): void {
        try {
            $request = request();

            static::create([
                'id' => (string) Str::uuid(),
                'level' => $level,
                'source' => self::SOURCE_SERVER,
                'message' => Str::limit($message, 250, ''),
                'context' => $context,
                'user_id' => $user?->getKey() ? (string) $user->getKey() : null,
                'company_id' => $user?->company_id ? (string) $user->company_id : null,
                'method' => $request?->method(),
                'path' => $request ? Str::limit('/'.ltrim($request->path(), '/'), 250, '') : null,
                'ip' => $request?->ip(),
                'platform' => $request?->header('X-Platform')
                    ?? (str_contains((string) $request?->userAgent(), 'Dart/') ? 'mobile' : null),
                'app_version' => Str::limit((string) $request?->header('X-App-Version'), 30, '') ?: null,
                'created_at' => now(),
            ]);
        } catch (\Throwable) {
            // Bilinçli olarak yutuluyor.
        }
    }

    /** Panelde renklendirme için — seviyelerin görsel ağırlığı. */
    public static function levelColor(string $level): string
    {
        return match ($level) {
            'critical', 'alert', 'emergency' => 'danger',
            'error' => 'danger',
            'warning' => 'warning',
            'info', 'notice' => 'info',
            default => 'gray',
        };
    }
}
