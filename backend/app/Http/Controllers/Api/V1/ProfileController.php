<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Profile\UpdatePasswordRequest;
use App\Http\Requests\Profile\UpdateProfileRequest;
use App\Http\Resources\UserResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;

/**
 * Kullanıcının KENDİ profili — bkz. docs/09 § Hesap Yönetimi.
 *
 * Parola değiştirme özellikle gerekli: personel hesapları işletme sahibi
 * tarafından bir başlangıç parolasıyla açılıyor (bkz. PersonnelController)
 * ve o parola sahiple paylaşılmış oluyor. Kullanıcının onu değiştirebilmesi
 * bir kolaylık değil, güvenlik gereğidir.
 */
class ProfileController extends Controller
{
    public function update(UpdateProfileRequest $request): JsonResponse
    {
        $user = $request->user();
        $user->update($request->validated());

        return (new UserResource($user->refresh()->load('company')))->response();
    }

    public function updatePassword(UpdatePasswordRequest $request): JsonResponse
    {
        $user = $request->user();

        // Hash'leme AÇIKÇA yapılır: User modelinde 'password' cast'i yok
        // (bkz. B3'teki çifte hash'leme regresyonu).
        $user->update(['password' => Hash::make($request->string('password')->toString())]);

        // Diğer cihazlardaki oturumlar kapatılır — parola değiştirmenin
        // amacı zaten "başkası giremesin"dir; eski jetonlar geçerli
        // kalırsa bu hiçbir işe yaramaz. Mevcut cihaz açık kalır.
        $currentTokenId = $request->user()->currentAccessToken()->id;
        $user->tokens()->where('id', '!=', $currentTokenId)->delete();

        return response()->json([
            'message' => 'Parolan güncellendi. Diğer cihazlardaki oturumların kapatıldı.',
        ]);
    }
}
