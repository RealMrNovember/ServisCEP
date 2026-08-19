<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\Company;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Socialite\Facades\Socialite;

/**
 * Web (Filament "app" paneli) için Google Sign-In — bkz. docs/09 § 0.
 * Mobildeki native Android akışından bağımsızdır (ayrı OAuth client).
 */
class GoogleAuthController extends Controller
{
    public function redirect(): RedirectResponse
    {
        return Socialite::driver('google')->redirect();
    }

    public function callback(): RedirectResponse
    {
        $googleUser = Socialite::driver('google')->user();

        $user = User::where('google_id', $googleUser->getId())
            ->orWhere('email', $googleUser->getEmail())
            ->first();

        if ($user) {
            if (! $user->google_id) {
                $user->forceFill(['google_id' => $googleUser->getId()])->save();
            }
        } else {
            $user = DB::transaction(function () use ($googleUser) {
                $company = Company::startTrial($googleUser->getName() ?: $googleUser->getEmail());

                return User::create([
                    'company_id' => $company->id,
                    'full_name' => $googleUser->getName() ?: $googleUser->getEmail(),
                    'email' => $googleUser->getEmail(),
                    'password' => Str::password(32),
                    'google_id' => $googleUser->getId(),
                    'role' => 'OWNER',
                ]);
            });
        }

        Auth::guard('web')->login($user, remember: true);

        return redirect()->intended('/panel');
    }
}
