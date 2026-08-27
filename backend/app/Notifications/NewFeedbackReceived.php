<?php

declare(strict_types=1);

namespace App\Notifications;

use App\Models\Feedback;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Str;

/**
 * Yeni bir kullanıcı geri bildirimi düştüğünde tüm adminlere gider.
 *
 * Panele bakılmadığı sürece görünmeyen bir kutu, geri bildirim kanalı
 * değildir: kullanıcı cevap bekliyor ve beklediği süre boyunca ürünün
 * ilgilenmediğini düşünüyor. Ödeme taleplerinde aynı gerekçeyle aynı
 * şey yapıldı.
 */
class NewFeedbackReceived extends Notification
{
    public function __construct(private readonly Feedback $feedback) {}

    /**
     * @return array<int, string>
     */
    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $tur = match ($this->feedback->type) {
            'ONERI' => 'Öneri',
            'HATA' => 'Hata bildirimi',
            'SORU' => 'Soru',
            default => 'Geri bildirim',
        };

        $sirket = $this->feedback->company?->name ?? 'Bilinmeyen şirket';
        $kisi = $this->feedback->user?->full_name ?? 'Bilinmeyen kullanıcı';

        return (new MailMessage)
            ->subject("$tur — $sirket")
            ->greeting("Yeni $tur")
            ->line("**$sirket** / $kisi")
            // Mesajın tamamı e-postada: adminin ne olduğunu anlamak için
            // panele girmesi gerekmesin. Panele yalnızca CEVAP yazmak için
            // girilir.
            ->line($this->feedback->message)
            ->line('Sürüm: '.($this->feedback->app_version ?? 'bilinmiyor'))
            ->action('Panelde aç', url('/admin/feedbacks/'.$this->feedback->id.'/edit'))
            ->line(Str::of('Yanıt yazdığınızda kullanıcıya bildirim gider.'));
    }
}
