<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Services\AuthService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Laravel\Socialite\Facades\Socialite;

/**
 * Web (Filament "app" paneli) için Google Sign-In — bkz. docs/09 § 0.
 * Aynı OAuth client (GOOGLE_CLIENT_ID) mobil native akışıyla paylaşılır;
 * eşleştirme/hesap oluşturma kuralı AuthService::findOrCreateGoogleUser()
 * içinde tek yerde tutulur ki iki katman (web session, mobil Sanctum)
 * aynı e-posta için farklı davranmasın.
 */
class GoogleAuthController extends Controller
{
    public function __construct(private readonly AuthService $authService)
    {
    }

    public function redirect(): RedirectResponse
    {
        return Socialite::driver('google')->redirect();
    }

    public function callback(): RedirectResponse
    {
        $googleUser = Socialite::driver('google')->user();

        $user = $this->authService->findOrCreateGoogleUser(
            $googleUser->getId(),
            $googleUser->getEmail(),
            $googleUser->getName(),
        );

        Auth::guard('web')->login($user, remember: true);

        return redirect()->intended('/panel');
    }
}
