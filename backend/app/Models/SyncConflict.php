<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Concerns\BelongsToCompany;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Bkz. ROADMAP.md § B10 — bir güncelleme, sunucudaki mevcut sürümle
 * çakıştığında (ör. telefon offline'ken ofis aynı kaydı değiştirmişse)
 * sessizce ezilmez, burada saklanır. Yalnızca OWNER manuel olarak
 * çözer. Kayıtlar immutable'dır — çözüldükten sonra `resolution`/
 * `resolved_at`/`resolved_by` doldurulur, satır silinmez.
 */
class SyncConflict extends Model
{
    use BelongsToCompany, HasFactory, HasUuids;

    public $timestamps = false;

    protected $fillable = [
        'company_id', 'user_id', 'subject_type', 'subject_id', 'base_version', 'server_version',
        'incoming_payload', 'server_snapshot', 'resolution', 'resolved_by', 'resolved_at',
    ];

    protected function casts(): array
    {
        return [
            'base_version' => 'integer',
            'server_version' => 'integer',
            'incoming_payload' => 'array',
            'server_snapshot' => 'array',
            'resolved_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
