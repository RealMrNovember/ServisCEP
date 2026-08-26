<?php

declare(strict_types=1);

namespace App\Support;

/**
 * Rol bazlı yetki matrisi — bkz. docs/09 § 1 Yetkilendirme (Roller).
 *
 * Yetkiler TEK yerde tanımlanır; politikalar `$user->can*` yerine buradan
 * okur. Amaç: "hangi rol neyi yapabilir?" sorusunun cevabının koda
 * dağılmaması — dağılırsa er ya da geç bir uçta unutulur ve sessiz bir
 * yetki açığı oluşur.
 *
 * İş kuralı notu: TECHNICIAN (saha teknisyeni) işletmenin finansal
 * verilerini GÖREMEZ — ciro, gider, tahsilat ve cari bakiye ona kapalıdır.
 * Sahaya telefon veren bir işletme sahibinin ilk beklentisi budur.
 */
final class RolePermissions
{
    public const OWNER = 'OWNER';

    public const ADMIN = 'ADMIN';

    public const TECHNICIAN = 'TECHNICIAN';

    public const ACCOUNTING = 'ACCOUNTING';

    public const VIEWER = 'VIEWER';

    /** Personel eklerken seçilebilecek roller (OWNER dahil değil — bkz. below). */
    public const ASSIGNABLE = [self::ADMIN, self::TECHNICIAN, self::ACCOUNTING, self::VIEWER];

    public const ALL = [self::OWNER, self::ADMIN, self::TECHNICIAN, self::ACCOUNTING, self::VIEWER];

    // Yetenekler
    public const CUSTOMERS_VIEW = 'customers.view';

    public const CUSTOMERS_MANAGE = 'customers.manage';

    public const CUSTOMERS_DELETE = 'customers.delete';

    public const JOBS_VIEW = 'jobs.view';

    public const JOBS_MANAGE = 'jobs.manage';

    public const DOCUMENTS_VIEW = 'documents.view';

    public const DOCUMENTS_MANAGE = 'documents.manage';

    public const FINANCE_VIEW = 'finance.view';

    public const FINANCE_MANAGE = 'finance.manage';

    public const LEDGER_ADJUST = 'ledger.adjust';

    public const COMPANY_MANAGE = 'company.manage';

    public const PERSONNEL_MANAGE = 'personnel.manage';

    public const AUDIT_VIEW = 'audit.view';

    public const CONFLICTS_RESOLVE = 'conflicts.resolve';

    /**
     * @var array<string, array<int, string>>
     */
    private const MATRIX = [
        // OWNER özel olarak ele alınır (her şeye yetkili) — matriste yok.
        self::ADMIN => [
            self::CUSTOMERS_VIEW, self::CUSTOMERS_MANAGE, self::CUSTOMERS_DELETE,
            self::JOBS_VIEW, self::JOBS_MANAGE,
            self::DOCUMENTS_VIEW, self::DOCUMENTS_MANAGE,
            self::FINANCE_VIEW, self::FINANCE_MANAGE,
            self::CONFLICTS_RESOLVE,
        ],
        self::TECHNICIAN => [
            self::CUSTOMERS_VIEW, self::CUSTOMERS_MANAGE,
            self::JOBS_VIEW, self::JOBS_MANAGE,
            self::DOCUMENTS_VIEW,
        ],
        self::ACCOUNTING => [
            self::CUSTOMERS_VIEW, self::CUSTOMERS_MANAGE,
            self::JOBS_VIEW,
            self::DOCUMENTS_VIEW, self::DOCUMENTS_MANAGE,
            self::FINANCE_VIEW, self::FINANCE_MANAGE, self::LEDGER_ADJUST,
        ],
        self::VIEWER => [
            self::CUSTOMERS_VIEW, self::JOBS_VIEW, self::DOCUMENTS_VIEW,
        ],
    ];

    public static function allows(?string $role, string $ability): bool
    {
        if ($role === self::OWNER) {
            return true;
        }

        return in_array($ability, self::MATRIX[$role] ?? [], true);
    }

    /**
     * @return array<int, string>
     */
    public static function abilitiesFor(?string $role): array
    {
        if ($role === self::OWNER) {
            return [
                self::CUSTOMERS_VIEW, self::CUSTOMERS_MANAGE, self::CUSTOMERS_DELETE,
                self::JOBS_VIEW, self::JOBS_MANAGE,
                self::DOCUMENTS_VIEW, self::DOCUMENTS_MANAGE,
                self::FINANCE_VIEW, self::FINANCE_MANAGE, self::LEDGER_ADJUST,
                self::COMPANY_MANAGE, self::PERSONNEL_MANAGE, self::AUDIT_VIEW,
                self::CONFLICTS_RESOLVE,
            ];
        }

        return self::MATRIX[$role] ?? [];
    }

    public static function label(string $role): string
    {
        return match ($role) {
            self::OWNER => 'İşletme Sahibi',
            self::ADMIN => 'Yönetici',
            self::TECHNICIAN => 'Teknisyen',
            self::ACCOUNTING => 'Muhasebe',
            self::VIEWER => 'Görüntüleyici',
            default => $role,
        };
    }
}
