import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../shared/tc_icon.dart';
import '../auth/data/session_controller.dart';
import 'barcode_scanner_screen.dart';
import 'data/products_repository.dart';
import 'product_form_screen.dart';

/// Barkod tara → ürünü bul → yoksa ön doldurulmuş formu aç.
///
/// [BarcodeScannerScreen] yalnızca okunan kodu geri döndürüyor; kodla ne
/// yapılacağı çağıranın işi. Bu akış üç ayrı yerden (stok listesi, ana
/// sayfadaki hızlı eylem, "Daha Fazla" menüsü) çağrıldığı için ortak
/// yazıldı — ana sayfa ve menüdeki düğmeler taramadan sonra hiçbir şey
/// yapmıyor, tarayıcı kapanıp kullanıcı boş ekranda kalıyordu.
Future<void> scanBarcodeAndOpen(BuildContext context, WidgetRef ref) async {
  final navigator = Navigator.of(context);
  final code = await navigator.push<String>(
    MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
  );
  if (code == null || !context.mounted) return;

  final companyId = ref.read(sessionControllerProvider).valueOrNull?.companyId;
  if (companyId == null) return;

  final repo = ref.read(productsRepositoryProvider);
  final existing = await repo.barkodlaBul(companyId, code);
  if (!context.mounted) return;

  if (existing != null) {
    await navigator.push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(existing: existing)),
    );
    return;
  }

  // Kod bu işletmenin kataloğunda yok. Açık ürün veritabanlarına
  // soruluyor; bulunursa ad/marka forma önceden yazılıyor.
  //
  // Bulunamaması NORMAL: bu veritabanları ağırlıklı olarak market
  // ürünlerini kapsıyor. Elektrik malzemesi ve güvenlik kamerası gibi
  // ürünlerin kutusunda çoğu zaman perakende barkodu yerine üretici
  // SERİ NUMARASI oluyor ve seriler hiçbir ürün veritabanında yer
  // almıyor. Bu yüzden sonuç ne olursa olsun akış devam ediyor.
  final global = await _sorgulaGosterge(context, repo, code);
  if (!context.mounted) return;

  // Eskiden burada BOŞ bir form açılıyordu ve kullanıcıya hiçbir şey
  // söylenmiyordu; "okutuyorum ama bilgi gelmiyor" şikâyetinin sebebi
  // buydu. Artık ne bulunduğu (ya da bulunamadığı) söyleniyor ve iki
  // gerçek seçenek sunuluyor.
  //
  // "Mevcut ürüne ekle" seçeneği asıl ihtiyaç: kutusunda perakende
  // barkodu yerine SERİ NUMARASI olan ürünlerde (kamera vb.) her kutu
  // farklı kod okutuyor. Her birini ayrı ürün yapmak stoku anlamsız
  // hâle getirirdi.
  final secim = await showModalBottomSheet<_TaramaSecimi>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              global == null
                  ? 'Bu barkod kayıtlı değil'
                  : 'İnternette bulundu',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              global == null ? code : '${global.name}\n$code',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
          ),
          ListTile(
            leading: const TcIcon(TcIcons.plus),
            title: const Text('Yeni ürün olarak ekle'),
            subtitle: Text(
              global == null
                  ? 'Bu kod yeni ürüne yazılır'
                  : 'Bilgiler forma önceden yazılır',
            ),
            onTap: () => Navigator.pop(sheetContext, _TaramaSecimi.yeniUrun),
          ),
          ListTile(
            leading: const TcIcon(TcIcons.tag),
            title: const Text('Mevcut bir ürüne ekle'),
            subtitle: const Text(
              'Aynı üründen gelen her kutunun kodu farklıysa bunu seç',
            ),
            onTap: () => Navigator.pop(sheetContext, _TaramaSecimi.mevcutUrun),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (secim == null || !context.mounted) return;

  if (secim == _TaramaSecimi.yeniUrun) {
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          prefilledBarcode: code,
          prefilledName: global?.name,
          prefilledBrand: global?.brand,
          prefilledCategory: global?.category,
        ),
      ),
    );
    return;
  }

  final urun = await showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => const _UrunSecici(),
  );
  if (urun == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  await repo.barkodBagla(urun: urun, barcode: code);
  messenger.showSnackBar(
    SnackBar(content: Text('Barkod "${urun.name}" ürününe bağlandı.')),
  );
}

enum _TaramaSecimi { yeniUrun, mevcutUrun }

/// Sorgu sürerken ekranı boş bırakmayan küçük bir bekleme penceresi.
///
/// Sorgu dışarı çıkıyor ve birkaç saniye sürebiliyor; hiçbir şey
/// göstermemek kullanıcıya "tarama çalışmadı" hissi veriyordu.
Future<GlobalProductLookupResult?> _sorgulaGosterge(
  BuildContext context,
  ProductsRepository repo,
  String code,
) async {
  final istek = repo.lookupGlobalBarcode(code);

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Barkod aranıyor…')),
          ],
        ),
      ),
    ),
  );

  GlobalProductLookupResult? sonuc;
  try {
    sonuc = await istek;
  } on Object {
    // Sorgu bir kolaylık; başarısız olması taramayı durdurmamalı.
    sonuc = null;
  }

  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

  return sonuc;
}

/// Bağlanacak ürünü seçtiren liste.
class _UrunSecici extends ConsumerWidget {
  const _UrunSecici();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urunler = ref.watch(productsListProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Hangi ürüne eklensin?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: urunler.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Ürünler okunamadı: $e')),
                data: (liste) => liste.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Henüz ürün yok. Önce "Yeni ürün olarak ekle" ile '
                            'bir ürün tanımla.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: liste.length,
                        itemBuilder: (_, i) => ListTile(
                          title: Text(liste[i].name),
                          subtitle: liste[i].brand == null
                              ? null
                              : Text(liste[i].brand!),
                          onTap: () => Navigator.pop(context, liste[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
