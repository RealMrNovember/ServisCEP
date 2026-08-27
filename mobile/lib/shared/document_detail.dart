import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/palette.dart';
import '../app/theme.dart';
import '../app/typography.dart';
import '../core/services/pdf_service.dart';
import '../core/utils/customer_display.dart';
import '../core/utils/money.dart';
import '../features/customers/data/customers_repository.dart';
import 'document_items_editor.dart';
import 'tc_icon.dart';
import 'ui.dart';

final _dateFormat = DateFormat('d MMMM y', 'tr_TR');

/// Teklif ve proforma detayının ortak gövdesi.
///
/// İki belge aynı bilgileri gösterir; ayrı yazıldıklarında biri
/// güncellenip diğeri geride kalıyordu. Farklılıkları ([statusPill],
/// [onChangeStatus]) parametre olarak alınır.
///
/// NOT: tasarımda ayrıca "Belge geçmişi" (oluşturuldu / gönderildi /
/// müşteri görüntüledi) ve "Düzenle" var. İkisinin de arkasında veri yok:
/// belge olayları hiçbir yerde tutulmuyor ve oluşmuş bir belgeyi düzenleme
/// akışı bulunmuyor. Boş bir zaman çizelgesi ya da hiçbir şey yapmayan bir
/// düğme koymak yerine ikisi de dışarıda bırakıldı (bkz. ROADMAP).
class DocumentDetailScaffold extends ConsumerWidget {
  const DocumentDetailScaffold({
    super.key,
    required this.kindLabel,
    required this.code,
    required this.customerId,
    required this.createdAt,
    required this.items,
    required this.currency,
    required this.vatMode,
    required this.vatRate,
    required this.onShare,
    this.validUntil,
    this.notes,
    this.statusPill,
    this.onChangeStatus,
    this.shareLabel = 'PDF Gönder',
  });

  /// "Teklif" ya da "Proforma" — başlıkta belge numarasının üstünde.
  final String kindLabel;

  final String code;
  final String customerId;
  final DateTime createdAt;
  final DateTime? validUntil;
  final String? notes;

  final AsyncValue<List<PdfLineItem>> items;
  final Currency currency;
  final VatMode vatMode;
  final int vatRate;

  final Widget? statusPill;
  final VoidCallback? onChangeStatus;
  final VoidCallback onShare;
  final String shareLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palet = context.palette;
    final musteriAsync = ref.watch(customerByIdProvider(customerId));
    final musteri = musteriAsync.valueOrNull;
    final gecti = validUntil != null && validUntil!.isBefore(DateTime.now());
    final telefon = musteri?.phone?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(code)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          _BelgeBasligi(
            kindLabel: kindLabel,
            code: code,
            musteri: musteri?.displayName,
            altSatir: _altSatir(gecti),
            statusPill: statusPill,
            onChangeStatus: onChangeStatus,
          ),

          const SizedBox(height: AppSpacing.xl),
          // Önizleme kartı: belgenin müşteriye hangi biçimde gideceğini
          // söylüyor. Gerçek bir küçük resim üretmek her açılışta PDF
          // oluşturmak demek olurdu; dokunulunca zaten gönderim menüsü
          // açılıyor, ki kullanıcının buradaki tek amacı da bu.
          AppCard(
            onTap: onShare,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 56,
                  decoration: BoxDecoration(
                    color: palet.accent.withValues(alpha: 0.12),
                    borderRadius: AppRadius.field,
                    border: Border.all(color: palet.accentLine),
                  ),
                  child: Center(
                    child: TcIcon(TcIcons.file, size: 20, color: palet.accent),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$kindLabel $code',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A4 · PDF · antetli',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                      ),
                    ],
                  ),
                ),
                TcIcon(TcIcons.chevronRight, size: 18, color: palet.textMuted),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          _KunyeKarti(
            satirlar: [
              if (telefon.isNotEmpty) ('Telefon', telefon),
              ('Düzenlenme', _dateFormat.format(createdAt)),
              (
                'Geçerlilik',
                validUntil == null
                    ? 'Belirtilmedi'
                    : _dateFormat.format(validUntil!),
              ),
              ('Para birimi', currency.code),
              ('KDV', '%$vatRate · ${vatMode.label}'),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader('Kalemler'),
          items.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Kalemler okunamadı: $e'),
            data: (lines) {
              final tutarlar = lines
                  .map((line) => line.amounts(vatMode))
                  .toList();

              return Column(
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _KalemSatiri(
                        line: lines[i],
                        grossMinor: tutarlar[i].grossMinor,
                        currency: currency,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  DocumentTotalsCard(
                    totals: DocumentTotals.from(tutarlar),
                    currency: currency,
                    vatMode: vatMode,
                  ),
                ],
              );
            },
          ),

          if (notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader('Notlar'),
            AppCard(child: Text(notes!.trim())),
          ],
        ],
      ),
      // Gönderim bu ekrandaki tek gerçek eylem: listeyi kaydırıp en alta
      // inmeden ulaşılabilmesi için alt çubukta sabit duruyor.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              if (onChangeStatus != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onChangeStatus,
                    child: const Text('Durum'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: onShare,
                  child: Text(shareLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "24 Ağustos 2026 · 15 gün geçerli" — süresi geçmişse gün sayısı
  /// yerine doğrudan uyarı yazılır.
  String _altSatir(bool gecti) {
    final tarih = _dateFormat.format(createdAt);
    if (validUntil == null) return tarih;
    if (gecti) return '$tarih · süresi doldu';
    final gun = validUntil!.difference(createdAt).inDays;
    return gun <= 0 ? tarih : '$tarih · $gun gün geçerli';
  }
}

/// Belge başlığı — tasarım teslimatı ekran 06.
///
/// Belge numarası tek aralıklı ve en belirgin öğe: kullanıcı belgeyi
/// numarasıyla anıyor. Durum rozeti başlıkta ve dokunulabilir.
class _BelgeBasligi extends StatelessWidget {
  const _BelgeBasligi({
    required this.kindLabel,
    required this.code,
    required this.musteri,
    required this.altSatir,
    required this.statusPill,
    required this.onChangeStatus,
  });

  final String kindLabel;
  final String code;
  final String? musteri;
  final String altSatir;
  final Widget? statusPill;
  final VoidCallback? onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kindLabel.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palet.textMuted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(code, style: AppTypography.monoLarge.copyWith(fontSize: 22)),
        if (musteri != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(musteri!, style: Theme.of(context).textTheme.titleMedium),
        ],
        const SizedBox(height: 2),
        Text(
          altSatir,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
        ),
        if (statusPill != null) ...[
          const SizedBox(height: AppSpacing.md),
          onChangeStatus == null
              ? statusPill!
              : GestureDetector(onTap: onChangeStatus, child: statusPill!),
        ],
      ],
    );
  }
}

/// Etiket–değer satırlarından oluşan künye kartı.
class _KunyeKarti extends StatelessWidget {
  const _KunyeKarti({required this.satirlar});

  final List<(String, String)> satirlar;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < satirlar.length; i++) ...[
            if (i > 0) Divider(height: AppSpacing.xl, color: palet.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    satirlar[i].$1,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    satirlar[i].$2,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tek bir belge kalemi.
///
/// Satır tutarı tek aralıklı: alt alta gelen tutarlar hane hane
/// hizalanıyor ve göz toplamı kolayca tarayabiliyor.
class _KalemSatiri extends StatelessWidget {
  const _KalemSatiri({
    required this.line,
    required this.grossMinor,
    required this.currency,
  });

  final PdfLineItem line;
  final int grossMinor;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.description,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '${line.quantity} ${line.unit} × '
                  '${Money.formatMinor(line.unitPriceMinor, currency: currency)}'
                  '  ·  KDV %${line.taxRate}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            Money.formatMinor(grossMinor, currency: currency),
            style: AppTypography.mono.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
