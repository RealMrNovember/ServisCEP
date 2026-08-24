<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/**
 * Push bildirimi cihaz kaydı — mobil uygulama FCM token'ını burada
 * bildirir (bkz. docs/06 § Push Notification).
 */
class DeviceTokenController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => ['required', 'string', 'max:500'],
            'platform' => ['nullable', 'string', 'in:android,ios'],
        ]);

        $user = $request->user();

        // Token globalde benzersizdir: aynı cihaza başka bir hesapla
        // giriş yapılırsa kayıt yeni sahibine geçer (eski kullanıcıya
        // artık bildirim gitmez — doğrusu budur).
        $device = DeviceToken::updateOrCreate(
            ['token' => $validated['token']],
            [
                'user_id' => $user->id,
                'company_id' => $user->company_id,
                'platform' => $validated['platform'] ?? 'android',
                'last_seen_at' => now(),
            ]
        );

        return response()->json(['data' => ['id' => $device->id]], 201);
    }

    /**
     * Çıkışta çağrılır — cihaz artık bu hesabın bildirimlerini almamalı.
     */
    public function destroy(Request $request): Response
    {
        $validated = $request->validate(['token' => ['required', 'string']]);

        DeviceToken::where('token', $validated['token'])
            ->where('user_id', $request->user()->id)
            ->delete();

        return response()->noContent();
    }
}
