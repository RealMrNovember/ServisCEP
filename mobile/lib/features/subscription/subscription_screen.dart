import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../app/typography.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/money.dart';
import '../../shared/ui.dart';
import 'data/subscription_models.dart';
import 'data/subscription_repository.dart';

/// Abonelik ekranı — web'deki Filament "Abonelik" sayfasının mobil karşılığı
/// (durum kartı → paketler → havale bilgisi → ödeme bildirimi → geçmiş).
/// Ödeme akışı web ile aynı: kullanıcı kendi bankasından havale yapar,
/// buradan bildirir, admin panelden onaylayınca abonelik uzar.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final _scrollController = ScrollController();
  final _formSectionKey = GlobalKey();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedPlanId;
  String _billingPeriod = 'MONTHLY';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _selectPlan(PlanInfo plan, String period) {
    setState(() {
      _selectedPlanId = plan.id;
      _billingPeriod = period;
      _amountController.text = Money.formatMinor(
        period == 'YEARLY' ? plan.priceYearlyMinor : plan.priceMonthlyMinor,
      ).replaceAll('₺', '').trim();
    });
    // Paket seçimi formu doldurur ama forma OTOMATİK kaydırmaz — kullanıcı
    // önce havale bilgisini (IBAN) görsün; ayrıca form bölümünün başında
    // "önce ödeme yapın" uyarısı da var.
    final ctx = _formSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        alignment: 0.1,
      );
    }
  }

  Future<void> _submit() async {
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir paket seçmelisin.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final amountText = _amountController.text.trim();
      await ref
          .read(subscriptionRepositoryProvider)
          .submitPaymentRequest(
            planId: _selectedPlanId!,
            billingPeriod: _billingPeriod,
            claimedAmountMinor: amountText.isEmpty
                ? null
                : Money.parseToMinor(amountText),
            customerNote: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      ref.invalidate(paymentRequestsProvider);
      if (mounted) {
        setState(() {
          _selectedPlanId = null;
          _amountController.clear();
          _noteController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ödeme bildirimin alındı. Onaylandığında aboneliğin otomatik uzatılır.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(subscriptionStatusProvider);
    ref.invalidate(plansProvider);
    ref.invalidate(paymentRequestsProvider);
    await Future.wait([
      ref.read(subscriptionStatusProvider.future),
      ref.read(plansProvider.future),
      ref.read(paymentRequestsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(subscriptionStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Abonelik')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(onRetry: _refresh),
        data: (status) => RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _StatusCard(status: status),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Paketler'),
              const SizedBox(height: 4),
              Text(
                'Ödemeyi yaptıktan sonra aşağıdaki formla bildir; onaylandığında aboneliğin otomatik uzatılır.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              _PlansSection(
                selectedPlanId: _selectedPlanId,
                currentPlanId: status.plan?.id,
                onSelect: _selectPlan,
              ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Havale / EFT Bilgileri'),
              const SizedBox(height: 12),
              _BankInfoCard(info: status.paymentInfo),
              const SizedBox(height: 24),
              KeyedSubtree(
                key: _formSectionKey,
                child: _sectionTitle(context, 'Ödeme Bildirimi'),
              ),
              const SizedBox(height: 12),
              _PaymentNoticeCard(info: status.paymentInfo),
              const SizedBox(height: 12),
              _buildForm(context),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Geçmiş Talepler'),
              const SizedBox(height: 12),
              const _RequestHistory(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _buildForm(BuildContext context) {
    final plansAsync = ref.watch(plansProvider);
    final plans = plansAsync.valueOrNull ?? const <PlanInfo>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedPlanId,
          decoration: const InputDecoration(labelText: 'Talep edilen paket'),
          items: plans
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    '${p.name} — ${Money.formatMinor(p.priceMonthlyMinor, decimals: false)}/ay',
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedPlanId = v),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'MONTHLY', label: Text('Aylık')),
            ButtonSegment(value: 'YEARLY', label: Text('Yıllık')),
          ],
          selected: {_billingPeriod},
          onSelectionChanged: (s) => setState(() => _billingPeriod = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Yatırdığın tutar (₺)',
            prefixText: '₺ ',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Not (opsiyonel)',
            hintText: 'Örn. dekont referansı',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: const Text('Ödeme Bildirimi Gönder'),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final SubscriptionStatus status;

  static final _tarih = DateFormat('d MMMM y', 'tr_TR');

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final aktif = status.hasActiveSubscription;
    final gun = status.daysRemaining;

    final baslik = status.isTrial
        ? 'DENEME SÜRÜMÜ'
        : (status.plan?.name ?? 'PAKET SEÇİLMEDİ').toUpperCase();

    final buyukSatir = switch (gun) {
      null => aktif ? 'Süresiz' : 'Pasif',
      <= 0 => 'Süresi doldu',
      _ => '$gun gün kaldı',
    };

    // Son üç güne girildiyse tehlike, son haftada uyarı: kullanıcı
    // "daha çok var" sanıp kesintiye uğramasın.
    final renk = switch (gun) {
      null => palet.accent,
      <= 0 => palet.dangerText,
      <= 3 => palet.dangerText,
      <= 7 => palet.warningText,
      _ => palet.accent,
    };

    return AppCard(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            baslik,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palet.textMuted,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            buyukSatir,
            style: AppTypography.monoLarge.copyWith(fontSize: 26, color: renk),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // "Verilerin silinmez" cümlesi BİLİNÇLİ olarak burada:
            // süresi dolmak üzere olan kullanıcının ilk korkusu
            // kayıtlarını kaybetmek ve bu korku ödeme kararını
            // bozuyor.
            status.expiresAt == null
                ? 'Verilerin cihazında ve sunucuda duruyor; silinmez.'
                : '${_tarih.format(status.expiresAt!.toLocal())} tarihinde '
                      'sona eriyor. Verilerin silinmez.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
          ),
          if (status.isTrial && aktif) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Tüm özellikler açık. Süre bitmeden bir paket seçersen '
              'kesinti yaşamazsın.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlansSection extends ConsumerWidget {
  const _PlansSection({
    required this.selectedPlanId,
    required this.currentPlanId,
    required this.onSelect,
  });

  final String? selectedPlanId;
  final String? currentPlanId;
  final void Function(PlanInfo plan, String period) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);

    return plansAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Paketler yüklenemedi — internet bağlantını kontrol et.'),
      ),
      data: (plans) => Column(
        children: [
          for (final plan in plans) ...[
            _PlanCard(
              plan: plan,
              isCurrent: plan.id == currentPlanId,
              isSelected: plan.id == selectedPlanId,
              onSelect: onSelect,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isSelected,
    required this.onSelect,
  });

  final PlanInfo plan;
  final bool isCurrent;
  final bool isSelected;
  final void Function(PlanInfo plan, String period) onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPopular = plan.slug == 'profesyonel';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected || isCurrent
              ? scheme.primary
              : scheme.outlineVariant,
          width: isSelected || isCurrent ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                plan.name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              if (isCurrent)
                _chip(context, 'Mevcut Paketin', scheme.primary)
              else if (isPopular)
                _chip(context, 'En Popüler', scheme.tertiary),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.formatMinor(plan.priceMonthlyMinor, decimals: false),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '/ay',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'veya yıllık ${Money.formatMinor(plan.priceYearlyMinor, decimals: false)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (plan.yearlySavingsPercent > 0) ...[
                const SizedBox(width: 6),
                _chip(
                  context,
                  '%${plan.yearlySavingsPercent} tasarruf',
                  Colors.green.shade700,
                ),
              ],
            ],
          ),
          if (plan.audience.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '${plan.audience}.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 8),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 15,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      feature,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 15, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  plan.maxUsers != null
                      ? 'Maksimum ${plan.maxUsers} kullanıcı'
                      : 'Sınırsız kullanıcı',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onSelect(plan, 'MONTHLY'),
                  child: const Text('Aylık Seç'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => onSelect(plan, 'YEARLY'),
                  child: const Text('Yıllık Seç'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _BankInfoCard extends StatelessWidget {
  const _BankInfoCard({required this.info});

  final PaymentInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (info.iban == null || info.iban!.isEmpty) {
      return Text(
        'Ödeme bilgileri henüz tanımlanmadı.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  info.iban!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'IBAN\'ı kopyala',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: info.iban!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('IBAN kopyalandı')),
                  );
                },
              ),
            ],
          ),
          if (info.accountHolder != null || info.bankName != null)
            Text(
              [
                info.accountHolder,
                info.bankName,
              ].where((s) => s != null && s.isNotEmpty).join(' — '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (info.note != null && info.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(info.note!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// "Önce ödeme yapın" uyarısı — paket seçimi kullanıcıyı forma getirdiği
/// için IBAN bölümü gözden kaçabilir; havale bilgisi burada da özetlenir
/// (web abonelik sayfasındaki aynı UX düzeltmesinin mobil karşılığı).
class _PaymentNoticeCard extends StatelessWidget {
  const _PaymentNoticeCard({required this.info});

  final PaymentInfo info;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Bu form, ödemeni yaptıktan sonra doldurulmalı. ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: info.iban != null && info.iban!.isNotEmpty
                        ? 'Henüz ödemediysen önce yukarıdaki hesaba havale/EFT gönder, sonra buradan bildir.'
                        : 'Ödeme yaptıysan buradan bildirimde bulunabilirsin.',
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestHistory extends ConsumerWidget {
  const _RequestHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(paymentRequestsProvider);
    final scheme = Theme.of(context).colorScheme;

    return requestsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const Text('Geçmiş talepler yüklenemedi.'),
      data: (requests) {
        if (requests.isEmpty) {
          return Text(
            'Henüz bir ödeme bildirimin yok.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          );
        }
        return Column(
          children: [
            for (final req in requests)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RequestTile(request: req),
              ),
          ],
        );
      },
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final PaymentRequestInfo request;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (request.status) {
      'PENDING' => ('Bekliyor', Colors.orange.shade700),
      'APPROVED' => ('Onaylandı', Colors.green.shade700),
      'REJECTED' => ('Reddedildi', scheme.error),
      _ => (request.status, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.approvedPlanName ?? request.planName ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (request.createdAt != null)
                      DateFormat(
                        'd MMM y HH:mm',
                        'tr_TR',
                      ).format(request.createdAt!.toLocal()),
                    if (request.claimedAmountMinor != null)
                      Money.formatMinor(request.claimedAmountMinor!),
                    if (request.requestedDuration == 'YEARLY')
                      'Yıllık'
                    else if (request.requestedDuration == 'MONTHLY')
                      'Aylık',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (request.status == 'REJECTED' &&
                    request.adminNote != null &&
                    request.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    request.adminNote!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40),
          const SizedBox(height: 12),
          const Text('Abonelik bilgileri yüklenemedi.'),
          const SizedBox(height: 4),
          Text(
            'İnternet bağlantını kontrol edip tekrar dene.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}
