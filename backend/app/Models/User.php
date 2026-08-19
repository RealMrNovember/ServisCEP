<?php

namespace App\Models;

use Filament\Models\Contracts\FilamentUser;
use Filament\Models\Contracts\HasName;
use Filament\Panel;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['company_id', 'full_name', 'email', 'phone', 'password', 'google_id', 'role'])]
#[Hidden(['password', 'remember_token', 'google_id'])]
class User extends Authenticatable implements FilamentUser, HasName
{
    use HasApiTokens, HasUuids, Notifiable;

    public $timestamps = false;

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'created_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function canAccessPanel(Panel $panel): bool
    {
        return $panel->getId() === 'app';
    }

    public function getFilamentName(): string
    {
        return $this->full_name;
    }
}
