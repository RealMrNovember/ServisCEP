import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../app/typography.dart';
import '../../shared/skeleton.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import 'data/payment_history.dart';

/// "Ödemelerim" — abonelik ödeme geçmişi.
///
/// Kart ödemesi ve havale bildirimi aynı ekranda toplanır — kullanıcı
/// için ikisi aynı sorunun cevabı: "ne zaman, ne kadar ödedim, ne oldu".
///
/// Ama BEKLEYENLER ayrı bölümde ve en üstte durur. Bekleyen bir talep
/// kullanıcının cevap beklediği bir şeydir; geçmiş ödeme yalnızca
/// referanstır. Karışık bir listede kullanıcı kendi talebini aramak
/// zorunda kalıyordu.
///
/// Kayıtlı kart BİLİNÇLİ olarak yok: kart bilgisi bizim sunucumuza hiç
/// uğramıyor, ödeme sağlayıcının güvenli sayfasında tamamlanıyor.
/// Saklanmayan bir kartı listelemek mümkün değil ve doğru da olmazdı.
class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kayitlarAsync = ref.watch(paymentHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ödemelerim')),
      body: kayitlarAsync.when(
        loading: () => const AppSkeleton(count: 5),
        error: (_, _) => AppErrorState(
          message: 'Ödeme geçmişi yüklenemedi.',
          onRetry: () => ref.invalidate(paymentHistoryProvider),
        ),
        data: (kayitlar) {
          if (kayitlar.isEmpty) {
            return const AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Henüz ödeme yok',
              message:
                  'Abonelik ödemeleriniz burada tarih ve tutarıyla listelenir.',
            );
          }

          // Bekleyen kayıtlar AYRI bölümde ve en üstte.
          //
          // Bekleyen bir talep kullanıcının takip ettiği, cevap beklediği
          // bir şey; geçmiş ödeme yalnızca referans. Aynı listede
          // karışınca kullanıcı kendi talebini aramak zorunda kalıyordu.
          final bekleyen = kayitlar.where((k) => k.isOpen).toList();
          final gecmis = kayitlar.where((k) => !k.isOpen).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(paymentHistoryProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.x4l,
              ),
              children: [
                if (bekleyen.isNotEmpty) ...[
                  const SectionHeader(
                    'Bekleyenler',
                    subtitle:
                        'Havale bildirimin onaylandığında burada '
                        '"Ödendi" olarak görünür ve aboneliğin uzar.',
                  ),
                  for (final k in bekleyen)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _PaymentCard(item: k),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (gecmis.isNotEmpty) ...[
                  SectionHeader(
                    'Geçmiş',
                    subtitle: bekleyen.isEmpty
                        ? null
                        : 'Tamamlanmış ödemeler.',
                  ),
                  for (final k in gecmis)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _PaymentCard(item: k),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.item});

  final PaymentHistoryItem item;

  static final _dateFormat = DateFormat('d MMMM y · HH:mm', 'tr_TR');

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    final (durumRengi, durumZemin, durumCizgi) = switch (item.state) {
      PaymentState.paid => (
        palet.successText,
        palet.successSoft,
        palet.successLine,
      ),
      PaymentState.failed => (
        palet.dangerText,
        palet.dangerSoft,
        palet.dangerLine,
      ),
      PaymentState.pending => (
        palet.warningText,
        palet.warningSoft,
        palet.warningLine,
      ),
    };

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TcIcon(
                item.kind == PaymentKind.card ? TcIcons.card : TcIcons.bank,
                size: 20,
                color: palet.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.planName ?? 'Abonelik',
                      style: AppTypography.h3.copyWith(color: palet.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        item.kindLabel,
                        if (item.durationLabel.isNotEmpty) item.durationLabel,
                      ].join(' · '),
                      style: AppTypography.caption.copyWith(
                        color: palet.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                item.amountLabel,
                style: AppTypography.mono.copyWith(color: palet.text),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: palet.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // Ödendiyse ödeme anı, değilse oluşturulma anı
                      // gösterilir — kullanıcının merak ettiği tarih bu.
                      _dateFormat.format(item.paidAt ?? item.createdAt),
                      style: AppTypography.caption.copyWith(
                        color: palet.textMuted,
                      ),
                    ),
                    if (item.reference != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.reference!,
                        style: AppTypography.monoSmall.copyWith(
                          color: palet.textFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: durumZemin,
                  borderRadius: AppRadius.pill,
                  border: Border.all(color: durumCizgi),
                ),
                child: Text(
                  item.stateLabel,
                  style: AppTypography.badge.copyWith(color: durumRengi),
                ),
              ),
            ],
          ),
          if (item.note != null && item.note!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: durumZemin,
                borderRadius: AppRadius.field,
                border: Border.all(color: durumCizgi),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // Notun kimden geldiği belli olmalı; kullanıcı bunu
                    // sistem metni sanmamalı.
                    item.state == PaymentState.failed
                        ? 'Neden onaylanmadı'
                        : 'Bizden not',
                    style: AppTypography.labelUp.copyWith(color: durumRengi),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.note!.trim(),
                    style: AppTypography.caption.copyWith(color: durumRengi),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
