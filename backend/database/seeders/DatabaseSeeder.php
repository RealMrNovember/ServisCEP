<?php

namespace Database\Seeders;

use App\Models\AdminUser;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $this->call(PlanSeeder::class);

        if (! AdminUser::query()->where('email', 'info@cicibyte.com')->exists()) {
            $password = Str::password(16);

            AdminUser::query()->create([
                'full_name' => 'Cicibyte Teknoloji',
                'email' => 'info@cicibyte.com',
                'password' => Hash::make($password),
            ]);

            $this->command?->warn("Admin kullanıcı oluşturuldu — e-posta: info@cicibyte.com  şifre: {$password}");
            $this->command?->warn('Bu şifreyi kaydedin, tekrar gösterilmeyecek. İlk girişte değiştirmeniz önerilir.');
        }
    }
}
