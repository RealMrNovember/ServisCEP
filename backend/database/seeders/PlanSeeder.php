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
                'description' => 'Tek kişilik veya küçük ekipler için.',
                'price_minor' => 0,
                'duration_days' => 30,
                'max_users' => 2,
                'sort_order' => 1,
            ],
            [
                'name' => 'Profesyonel',
                'slug' => 'profesyonel',
                'description' => 'Büyüyen saha servis ekipleri için.',
                'price_minor' => 0,
                'duration_days' => 30,
                'max_users' => 10,
                'sort_order' => 2,
            ],
            [
                'name' => 'Kurumsal',
                'slug' => 'kurumsal',
                'description' => 'Sınırsız kullanıcı, öncelikli destek.',
                'price_minor' => 0,
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
