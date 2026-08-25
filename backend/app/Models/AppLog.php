<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

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
