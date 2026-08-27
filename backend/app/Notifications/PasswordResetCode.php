<?php

declare(strict_types=1);

namespace App\Notifications;

use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Parola sıfırlama kodu.
 *
 * Bağlantı değil KOD gönderiliyor. Kullanıcı sahada, telefonunda ve
 * uygulamanın içinde: bir bağlantı onu tarayıcıya, oradan da uygulamaya
 * geri dönmeye zorlar ve bu yolculuğun her adımı kayıp kullanıcı demek.
 * Altı haneli kodu okuyup uygulamadaki alana yazmak tek adım.
 */
class PasswordResetCode extends Notification
{
    public function __construct(
        private readonly string $code,
        private readonly int $gecerlilikDakika,
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
        return (new MailMessage)
            ->subject('TeknikCEP — parola sıfırlama kodu')
            ->greeting('Parolanı sıfırla')
            ->line('Uygulamadaki alana bu kodu yaz:')
            ->line("**{$this->code}**")
            ->line("Kod {$this->gecerlilikDakika} dakika geçerli.")
            // Bu cümle bilinçli: parola sıfırlama isteğini BAŞKASI
            // yaptıysa, kullanıcının yapması gereken tek şey görmezden
            // gelmek. Panik yaratmadan bunu söylemek gerekiyor.
            ->line(
                'Bu isteği sen yapmadıysan yapman gereken bir şey yok; '
                .'parolan değişmez.'
            );
    }
}
