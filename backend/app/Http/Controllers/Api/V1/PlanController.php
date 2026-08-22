<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PlanResource;
use App\Models\Plan;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PlanController extends Controller
{
    /**
     * Satıştaki paketler — deneme planı hariç (o yalnızca kayıt anında
     * otomatik atanır, satın alınamaz). Web abonelik sayfasıyla aynı
     * filtre (bkz. Filament\App\Pages\Subscription::getPlans).
     */
    public function index(): AnonymousResourceCollection
    {
        $plans = Plan::query()
            ->where('is_active', true)
            ->where('slug', '!=', 'deneme')
            ->orderBy('sort_order')
            ->get();

        return PlanResource::collection($plans);
    }
}
