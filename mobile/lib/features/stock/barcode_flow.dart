import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final existing = await repo.findByBarcode(companyId, code);
  if (!context.mounted) return;

  if (existing != null) {
    await navigator.push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(existing: existing)),
    );
    return;
  }

  // Ürün bu işletmede yok: küresel barkod veritabanından ne bulunursa
  // forma önceden yazılır, kullanıcı sıfırdan doldurmak zorunda kalmaz.
  final global = await repo.lookupGlobalBarcode(code);
  if (!context.mounted) return;

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
}
