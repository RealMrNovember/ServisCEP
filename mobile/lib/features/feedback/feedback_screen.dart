import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/network/api_client.dart';
import '../../shared/app_button.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import 'data/feedback_repository.dart';

/// Geri bildirim: kullanıcı yazar, yönetim yanıtlar.
///
/// Uygulama içinde geri bildirim kanalı YOKTU: kullanıcı bir sorun
/// gördüğünde ya da bir şey istediğinde bize ulaşmasının hiçbir yolu
/// yoktu. Mağaza yorumu tek yoldu ve orada yazılan şey ne cevaplanabilir
/// ne de takip edilebilir.
///
/// Gönderim ve geçmiş AYNI ekranda: kullanıcı için ikisi aynı sorunun
/// parçası — "yazdım, ne oldu?".
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _mesaj = TextEditingController();
  FeedbackType _tur = FeedbackType.oneri;
  bool _gonderiliyor = false;

  @override
  void dispose() {
    _mesaj.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    final metin = _mesaj.text.trim();
    if (metin.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biraz daha ayrıntı yazar mısınız?')),
      );
      return;
    }

    setState(() => _gonderiliyor = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref
          .read(feedbackRepositoryProvider)
          .gonder(type: _tur, message: metin);

      _mesaj.clear();
      ref.invalidate(feedbackHistoryProvider);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Teşekkürler, aldık. Yanıtlayınca haber vereceğiz.'),
        ),
      );
    } on ApiException catch (e) {
      // Çevrimdışıyken kuyruğa ALINMIYOR (bkz. FeedbackRepository.gonder):
      // "gönderildi" deyip günler sonra göndermek yerine açıkça söylüyoruz.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final gecmis = ref.watch(feedbackHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Geri Bildirim')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(
            'Ne düşündüğünüzü yazın',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Eksik bulduğunuz, takıldığınız ya da olmasını istediğiniz '
            'her şeyi yazabilirsiniz. Hepsini okuyoruz.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Tür seçimi: yanıtlayan tarafın önceliklendirmesi buna bağlı.
          // Bir hata bildirimi, bir öneriden daha acildir.
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final t in FeedbackType.values)
                ChoiceChip(
                  label: Text(t.etiket),
                  selected: _tur == t,
                  onSelected: (_) => setState(() => _tur = t),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          TextField(
            controller: _mesaj,
            maxLines: 6,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Mesajınız...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Gönder',
            // AppButton tasarım sistemi ikon ADI alıyor, IconData değil.
            icon: TcIcons.send,
            loading: _gonderiliyor,
            onPressed: _gonderiliyor ? null : _gonder,
          ),

          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Gönderdikleriniz',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),

          gecmis.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => AppErrorState(
              title: 'Geçmiş yüklenemedi',
              message: 'Bağlantı kurulamadı. Gönderdikleriniz kayıtlı.',
              onRetry: () => ref.invalidate(feedbackHistoryProvider),
            ),
            data: (kayitlar) {
              if (kayitlar.isEmpty) {
                return const AppEmptyState(
                  icon: TcIcons.mail,
                  title: 'Henüz geri bildirim göndermediniz',
                  message: 'Yazdıklarınız ve gelen yanıtlar burada durur.',
                );
              }
              return Column(
                children: [for (final k in kayitlar) _KayitKarti(kayit: k)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _KayitKarti extends StatelessWidget {
  const _KayitKarti({required this.kayit});

  final FeedbackItem kayit;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final bicim = DateFormat('d MMMM y', 'tr_TR');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  kayit.typeLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                Text(
                  kayit.statusLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    // `successText`, `success` DEĞİL: ikincisi dolgu rengi ve
                    // yüzey üzerinde yazı olarak kontrastı yetmiyor
                    // (bkz. AppPalette sınıf notu).
                    color: kayit.yanitlandi
                        ? palet.successText
                        : palet.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              bicim.format(kayit.createdAt),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palet.textFaint),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(kayit.message),

            // Yanıt kayıtta DURUYOR: bildirim kaybolur, kayıt kalır.
            // Aynı ilke ödeme taleplerinde de uygulandı.
            if (kayit.yanitlandi) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palet.surfaceAlt,
                  borderRadius: AppRadius.field,
                  border: Border.all(color: palet.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yanıtımız',
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: palet.accent),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(kayit.reply!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
