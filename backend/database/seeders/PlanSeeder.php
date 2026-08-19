<?php

namespace Database\Seeders;

use App\Models\Plan;
use Illuminate\Database\Seeder;

class PlanSeeder extends Seeder
{
    public function run(): void
    {
        $plans = [
            [
                'name' => 'Deneme',
                'slug' => 'deneme',
                'description' => '14 günlük ücretsiz deneme sürümü — tüm özellikler açık.',
                'price_minor' => 0,
                'duration_days' => 14,
                'max_users' => 2,
                'sort_order' => 0,
            ],
            [
                'name' => 'Başlangıç',
                'slug' => 'baslangic',
                'description' => 'Bireysel usta / 1-2 kişilik ekipler için. Maksimum 2 kullanıcı, çevrimdışı çalışma, standart iş akışı.',
                'price_minor' => 49900,
                'price_yearly_minor' => 550000,
                'duration_days' => 30,
                'max_users' => 2,
                'sort_order' => 1,
            ],
            [
                'name' => 'Profesyonel',
                'slug' => 'profesyonel',
                'description' => '3-5 kişilik saha işletmeleri için. Maksimum 5 kullanıcı, dijital imza, cari hesap takibi, gelişmiş PDF belge üretimi.',
                'price_minor' => 100000,
                'price_yearly_minor' => 1100000,
                'duration_days' => 30,
                'max_users' => 5,
                'sort_order' => 2,
            ],
            [
                'name' => 'Kurumsal',
                'slug' => 'kurumsal',
                'description' => 'Büyüyen, çoklu ekip yönetenler için. 10+ kullanıcı, company_id izolasyonlu tam güvenlik, gelişmiş stok yönetimi.',
                'price_minor' => 250000,
                'price_yearly_minor' => 2500000,
                'duration_days' => 30,
                'max_users' => null,
                'sort_order' => 3,
            ],
        ];

        foreach ($plans as $plan) {
            Plan::query()->updateOrCreate(['slug' => $plan['slug']], $plan);
        }
    }
}
