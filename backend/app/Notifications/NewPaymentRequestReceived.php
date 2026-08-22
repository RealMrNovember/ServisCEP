<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\PaymentRequest;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Yeni bir abonelik ödeme talebi (havale bildirimi) düştüğünde tüm
 * adminlere gider — onay tamamen manuel olduğu için talebin panelde
 * beklediğini adminin e-postadan da görmesi gerekir (aksi halde talepler
 * yalnızca panele girildiğinde fark edilir).
 */
class NewPaymentRequestReceived extends Notification
{
    public function __construct(private readonly PaymentRequest $paymentRequest)
    {
    }

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $company = $this->paymentRequest->company;
        $plan = $this->paymentRequest->plan;

        $amount = $this->paymentRequest->claimed_amount_minor !== null
            ? number_format($this->paymentRequest->claimed_amount_minor / 100, 2, ',', '.').' ₺'
            : 'Belirtilmedi';

        $period = match ($this->paymentRequest->requested_duration) {
            'MONTHLY' => 'Aylık',
            'YEARLY' => 'Yıllık',
            default => 'Belirtilmedi',
        };

        return (new MailMessage)
            ->subject('Yeni ödeme talebi: '.($company?->name ?? 'Bilinmeyen şirket'))
            ->greeting('Yeni bir ödeme talebi var')
            ->line('Şirket: '.($company?->name ?? '—'))
            ->line('Talep edilen paket: '.($plan?->name ?? '—'))
            ->line('Ödeme periyodu: '.$period)
            ->line('Beyan edilen tutar: '.$amount)
            ->when(filled($this->paymentRequest->customer_note), fn (MailMessage $mail) => $mail->line('Müşteri notu: '.$this->paymentRequest->customer_note))
            ->action('Talebi İncele', url('/admin/payment-requests'))
            ->line('Banka hesabınızı kontrol edip talebi panelden onaylayın veya reddedin.');
    }
}
