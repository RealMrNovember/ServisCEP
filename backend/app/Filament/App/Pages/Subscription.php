<?php

namespace App\Filament\App\Pages;

use App\Models\Company;
use App\Models\PaymentRequest;
use App\Models\Plan;
use App\Models\Setting;
use BackedEnum;
use Filament\Facades\Filament;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Concerns\InteractsWithForms;
use Filament\Forms\Contracts\HasForms;
use Filament\Notifications\Notification;
use Filament\Pages\Page;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Illuminate\Support\Collection;

/**
 * Müşterinin havale/EFT ile ödeme yaptıktan sonra ödeme talebi girdiği
 * ekran — admin onayladığında PaymentRequest::approve() aboneliği otomatik
 * uzatır (bkz. admin panelindeki PaymentRequestsTable).
 */
class Subscription extends Page implements HasForms
{
    use InteractsWithForms;

    protected string $view = 'filament.app.pages.subscription';

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedCreditCard;

    protected static ?string $navigationLabel = 'Abonelik';

    protected static ?string $title = 'Abonelik';

    protected static ?int $navigationSort = 10;

    /** @var array<string, mixed>|null */
    public ?array $data = [];

    public function mount(): void
    {
        $this->form->fill();
    }

    public function selectPlan(string $planId): void
    {
        $this->data['plan_id'] = $planId;

        $this->dispatch('plan-selected');
    }

    public function getPlans(): Collection
    {
        return Plan::query()
            ->where('is_active', true)
            ->where('slug', '!=', 'deneme')
            ->orderBy('sort_order')
            ->get();
    }

    public function getCurrentCompany(): Company
    {
        return Filament::auth()->user()->company;
    }

    /**
     * Plan açıklaması "{hedef kitle}. {özellik, özellik, ...}." biçiminde
     * saklanır — burada kart üzerinde okunabilir bir hedef kitle cümlesi
     * ve işaretli özellik listesine ayrıştırılır.
     *
     * @return array{audience: string, features: array<int, string>}
     */
    public function splitPlanDescription(Plan $plan): array
    {
        $sentences = array_values(array_filter(array_map('trim', explode('.', (string) $plan->description))));

        $audience = $sentences[0] ?? '';
        $features = isset($sentences[1])
            ? array_values(array_filter(array_map('trim', explode(',', $sentences[1]))))
            : [];

        return ['audience' => $audience, 'features' => $features];
    }

    public function getYearlySavingsPercent(Plan $plan): int
    {
        $monthlyTotal = $plan->price_minor * 12;

        if ($monthlyTotal <= 0 || $plan->price_yearly_minor <= 0) {
            return 0;
        }

        return (int) round((1 - ($plan->price_yearly_minor / $monthlyTotal)) * 100);
    }

    public function form(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('Yeni Ödeme Talebi')
                    ->description('Havale/EFT ile ödemeyi yaptıktan sonra bu formu doldurun. Talebiniz onaylandığında aboneliğiniz otomatik olarak uzatılır.')
                    ->components([
                        Select::make('plan_id')
                            ->label('Talep edilen paket')
                            ->options(fn () => Plan::query()->where('is_active', true)->get()->mapWithKeys(
                                fn (Plan $plan) => [$plan->id => sprintf(
                                    '%s — %s ₺/ay veya %s ₺/yıl',
                                    $plan->name,
                                    number_format($plan->price_minor / 100, 2, ',', '.'),
                                    number_format($plan->price_yearly_minor / 100, 2, ',', '.'),
                                )]
                            ))
                            ->native(false),
                        TextInput::make('claimed_amount_tl')
                            ->label('Yatırdığınız tutar (₺)')
                            ->numeric()
                            ->prefix('₺'),
                        Textarea::make('customer_note')
                            ->label('Not')
                            ->helperText('Örn. dekont referansı, hangi süre için ödeme yaptığınız vb.')
                            ->columnSpanFull(),
                    ]),
            ])
            ->statePath('data');
    }

    public function submit(): void
    {
        $data = $this->form->getState();

        $user = Filament::auth()->user();

        PaymentRequest::create([
            'company_id' => $user->company_id,
            'requested_by_user_id' => $user->id,
            'plan_id' => $data['plan_id'] ?? null,
            'claimed_amount_minor' => filled($data['claimed_amount_tl'] ?? null) ? (int) round($data['claimed_amount_tl'] * 100) : null,
            'customer_note' => $data['customer_note'] ?? null,
            'status' => 'PENDING',
        ]);

        $this->form->fill();

        Notification::make()
            ->title('Ödeme talebiniz alındı')
            ->body('Talebiniz incelendikten sonra aboneliğiniz aktif edilecektir.')
            ->success()
            ->send();
    }

    public function getBankSettings(): array
    {
        return [
            'iban' => Setting::get('payment_iban'),
            'account_holder' => Setting::get('payment_account_holder'),
            'bank_name' => Setting::get('payment_bank_name'),
            'note' => Setting::get('payment_note'),
        ];
    }

    public function getMyRequests(): Collection
    {
        $companyId = Filament::auth()->user()->company_id;

        return PaymentRequest::with(['plan', 'approvedPlan'])
            ->where('company_id', $companyId)
            ->orderByDesc('created_at')
            ->limit(20)
            ->get();
    }
}
