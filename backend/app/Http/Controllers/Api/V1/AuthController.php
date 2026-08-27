<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\GoogleLoginRequest;
use App\Http\Requests\Auth\GoogleRegisterRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\AuthService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(private readonly AuthService $authService) {}

    public function register(RegisterRequest $request): JsonResponse
    {
        $result = $this->authService->register($request->validated());

        return $this->tokenResponse($result['user'], $result['token'], 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $result = $this->authService->login($request->validated());

        return $this->tokenResponse($result['user'], $result['token']);
    }

    /**
     * Parola sıfırlama kodu ister.
     *
     * Hesap bulunsa da bulunmasa da AYNI yanıt dönüyor: farklı yanıt
     * vermek, bu ucu "bu e-posta kayıtlı mı?" sorgusuna çevirirdi.
     */
    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        $this->authService->sendPasswordResetCode(
            $request->validated()['email']
        );

        return response()->json([
            'message' => 'E-posta adresin kayıtlıysa sıfırlama kodu gönderildi.',
        ]);
    }

    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        /** @var array{email: string, code: string, password: string} $data */
        $data = $request->validated();
        $this->authService->resetPassword($data);

        return response()->json([
            'message' => 'Parolan güncellendi. Yeni parolanla giriş yapabilirsin.',
        ]);
    }

    public function googleLogin(GoogleLoginRequest $request): JsonResponse
    {
        $result = $this->authService->loginWithGoogle($request->validated()['id_token']);

        return $this->tokenResponse($result['user'], $result['token']);
    }

    public function googleRegister(GoogleRegisterRequest $request): JsonResponse
    {
        $result = $this->authService->registerWithGoogle($request->validated());

        return $this->tokenResponse($result['user'], $result['token'], 201);
    }

    public function logout(Request $request): JsonResponse
    {
        $this->authService->logout($request->user());

        return response()->json(['message' => 'Çıkış yapıldı.']);
    }

    public function me(Request $request): JsonResponse
    {
        /** @var UserResource $resource */
        $resource = new UserResource($request->user()->load('company'));

        return $resource->response();
    }

    private function tokenResponse(User $user, string $token, int $status = 200): JsonResponse
    {
        return (new UserResource($user))
            ->additional(['token' => $token])
            ->response()
            ->setStatusCode($status);
    }
}
