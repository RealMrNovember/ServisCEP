<?php

declare(strict_types=1);

namespace App\Logging;

use App\Models\AppLog;
use Illuminate\Support\Str;
use Monolog\Handler\AbstractProcessingHandler;
use Monolog\LogRecord;
use Throwable;

/**
 * Laravel'in log kayıtlarını `app_logs` tablosuna da yazar.
 *
 * Dosya logu kalmaya devam eder — bu handler onun yerine değil, yanına
 * çalışır. Amaç, bir arızayı teşhis etmek için sunucuya SSH ile girmek
 * zorunda kalmamak.
 *
 * İki kural bu sınıfın varlık sebebi kadar önemli:
 *
 * 1. **Log yazmak asla isteği bozmamalı.** Veritabanına yazma başarısız
 *    olursa (bağlantı yok, tablo yok, migration henüz koşmadı) sessizce
 *    vazgeçilir. Bir hatayı kaydedememek, o hatanın üstüne bir hata daha
 *    koymaktan iyidir.
 *
 * 2. **Özyineleme olmamalı.** Veritabanına yazarken çıkan hata tekrar
 *    loglanırsa sonsuz döngü olur; bu yüzden yazma sırasında bayrak
 *    kaldırılır ve o sırada gelen kayıtlar atlanır.
 */
class DatabaseLogHandler extends AbstractProcessingHandler
{
    private static bool $writing = false;

    protected function write(LogRecord $record): void
    {
        if (self::$writing) {
            return;
        }

        self::$writing = true;

        try {
            AppLog::create([
                'id' => (string) Str::uuid(),
                'level' => strtolower($record->level->getName()),
                'source' => AppLog::SOURCE_SERVER,
                'message' => Str::limit($record->message, 250, ''),
                'context' => $this->normalizeContext($record),
                'user_id' => $this->currentUserId(),
                'company_id' => $this->currentCompanyId(),
                'method' => request()?->method(),
                'path' => $this->currentPath(),
                'ip' => request()?->ip(),
                'created_at' => now(),
            ]);
        } catch (Throwable) {
            // Bilinçli olarak yutuluyor — bkz. sınıf açıklaması (1).
        } finally {
            self::$writing = false;
        }
    }

    /**
     * Bağlamı JSON'a yazılabilir hâle getirir.
     *
     * İstisna nesneleri olduğu gibi serileştirilemez; sınıfı, mesajı,
     * dosyası ve yığın izinin ilk satırları alınır — teşhis için yeterli,
     * tabloyu şişirmeyecek kadar da kısa.
     */
    private function normalizeContext(LogRecord $record): array
    {
        $context = $record->context;

        if (isset($context['exception']) && $context['exception'] instanceof Throwable) {
            $exception = $context['exception'];
            $context['exception'] = [
                'class' => $exception::class,
                'message' => $exception->getMessage(),
                'file' => $exception->getFile().':'.$exception->getLine(),
                'trace' => Str::limit($exception->getTraceAsString(), 2000, '…'),
            ];
        }

        return $this->stringifyDeep($context);
    }

    /** @return array<mixed> */
    private function stringifyDeep(array $values): array
    {
        foreach ($values as $key => $value) {
            if (is_array($value)) {
                $values[$key] = $this->stringifyDeep($value);
            } elseif (is_object($value)) {
                $values[$key] = method_exists($value, '__toString')
                    ? (string) $value
                    : $value::class;
            }
        }

        return $values;
    }

    private function currentUserId(): ?string
    {
        try {
            return auth()->id() ? (string) auth()->id() : null;
        } catch (Throwable) {
            return null;
        }
    }

    private function currentCompanyId(): ?string
    {
        try {
            $user = auth()->user();

            return $user?->company_id ? (string) $user->company_id : null;
        } catch (Throwable) {
            return null;
        }
    }

    private function currentPath(): ?string
    {
        try {
            $path = request()?->path();

            return $path ? Str::limit('/'.ltrim($path, '/'), 250, '') : null;
        } catch (Throwable) {
            return null;
        }
    }
}
