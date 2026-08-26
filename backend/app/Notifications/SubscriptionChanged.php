<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\Company;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Aboneliği onaylanan/uzatılan müşteriye gider.
 *
 * Neden push'a EK olarak e-posta: push yalnızca uygulamayı güncellemiş,
 * bildirim iznini vermiş ve cihazı kayıtlı olan kullanıcıya ulaşır.
 * Müşteri ödemesini yaptıktan sonra onayı bekliyor; haber alamazsa
 * boşuna bekler ve destek arar. E-posta bu koşulların hiçbirine bağlı
 * değildir — teslimat garantisi buradan gelir.
 */
class SubscriptionChanged extends Notification
{
    public function __construct(
        private readonly Company $company,
        private readonly bool $extended,
    ) {}

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $planName = $this->company->plan?->name ?? 'Paketiniz';
        $expiry = $this->company->subscription_expires_at?->translatedFormat('d F Y');

        $subject = $this->extended
            ? 'Aboneliğiniz aktif edildi'
            : 'Aboneliğiniz güncellendi';

        $message = (new MailMessage)
            ->subject("TeknikCEP — {$subject}")
            ->greeting('Merhaba,')
            ->line(
                $this->extended
                    ? 'Ödemeniz onaylandı ve aboneliğiniz aktif edildi. Teşekkür ederiz.'
                    : 'Aboneliğinizde bir güncelleme yapıldı.'
            )
            ->line("**Paket:** {$planName}");

        if ($expiry !== null) {
            $message->line("**Geçerlilik:** {$expiry} tarihine kadar");
        }

        return $message
            ->line('Uygulamayı açtığınızda yeni durumunuz görünecektir.')
            ->salutation('TeknikCEP');
    }
}
