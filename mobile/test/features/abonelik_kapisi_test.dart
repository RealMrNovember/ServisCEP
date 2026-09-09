import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serviscep/app/theme.dart';
import 'package:serviscep/features/subscription/abonelik_kapisi.dart';
import 'package:serviscep/features/subscription/data/subscription_models.dart';
import 'package:serviscep/features/subscription/data/subscription_repository.dart';

/// Abonelik kapısının SINIRLARI.
///
/// Kapı yalnızca yeni kayıt oluşturmayı durdurur. Yedekleme, sunucu
/// tarafında hiçbir koşulda durmuyor (bkz. routes/api.php — abonelik
/// kapısı 2026-09-10'da kaldırıldı); buradaki bir regresyon ise
/// kullanıcıyı sahada çalışamaz hale getirir.
void main() {
  SubscriptionStatus durum({
    required bool aktif,
    bool deneme = true,
    String? whatsapp,
  }) {
    return SubscriptionStatus(
      plan: null,
      isTrial: deneme,
      isActive: true,
      hasActiveSubscription: aktif,
      expiresAt: null,
      daysRemaining: aktif ? 10 : 0,
      paymentInfo: PaymentInfo.fromJson(const {}),
      supportWhatsapp: whatsapp,
    );
  }

  /// Kapıyı bir düğmenin arkasına koyup düğmeye basar.
  Future<bool> kapidanGecti(
    WidgetTester tester,
    AsyncValue<SubscriptionStatus> saglayici,
  ) async {
    var gecti = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionStatusProvider.overrideWith(
            (ref) => saglayici.when(
              data: (d) => Future.value(d),
              loading: Future<SubscriptionStatus>.any,
              error: (e, s) => Future<SubscriptionStatus>.error(e),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  gecti = await abonelikIzinVerir(context, ref);
                },
                child: const Text('Yeni kayıt'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Yeni kayıt'));
    await tester.pumpAndSettle();

    return gecti;
  }

  testWidgets('aboneliği geçerli olan geçer, hiçbir şey açılmaz', (
    tester,
  ) async {
    final gecti = await kapidanGecti(
      tester,
      AsyncValue.data(durum(aktif: true)),
    );

    expect(gecti, isTrue);
    expect(find.textContaining('doldu'), findsNothing);
  });

  testWidgets('süresi dolmuş olan geçemez, ödeme akışı açılır', (tester) async {
    final gecti = await kapidanGecti(
      tester,
      AsyncValue.data(durum(aktif: false)),
    );

    expect(gecti, isFalse);
    expect(find.text('Deneme süren doldu'), findsOneWidget);
    expect(find.text('Paket seç ve öde'), findsOneWidget);

    // Havale yapmış ama onay bekleyen kullanıcı için ayrı yol: "öde"
    // düğmesi ona hiçbir şey söylemiyor, parayı zaten göndermiş.
    expect(find.text('Ödemeyi yaptım, bildirmek istiyorum'), findsOneWidget);
  });

  testWidgets('verinin durduğu izlenimi verilmez', (tester) async {
    // Kullanıcının ilk korkusu verisi. Kapı, yedeklemenin sürdüğünü
    // açıkça söylemek zorunda — sunucu tarafında gerçekten sürüyor.
    await kapidanGecti(tester, AsyncValue.data(durum(aktif: false)));

    expect(find.textContaining('kaybolmadı'), findsOneWidget);
  });

  testWidgets('destek numarası yoksa WhatsApp düğmesi çıkmaz', (tester) async {
    // Çalışmayan bir düğme, olmayan düğmeden kötüdür.
    await kapidanGecti(tester, AsyncValue.data(durum(aktif: false)));

    expect(find.text('WhatsApp ile bize ulaş'), findsNothing);
  });

  testWidgets('destek numarası varsa WhatsApp düğmesi çıkar', (tester) async {
    await kapidanGecti(
      tester,
      AsyncValue.data(durum(aktif: false, whatsapp: '905354895050')),
    );

    expect(find.text('WhatsApp ile bize ulaş'), findsOneWidget);
  });

  testWidgets('abonelik durumu BİLİNMİYORSA geçit açık kalır', (tester) async {
    // Çevrimdışı kullanıcının önüne "aboneliğin doldu" duvarı çıkarmak,
    // uygulamanın var oluş sebebine aykırı: sahada internet yokken
    // çalışabilmek. Durum okunamadığında kullanıcı durdurulmaz.
    final gecti = await kapidanGecti(
      tester,
      AsyncValue<SubscriptionStatus>.error('ağ yok', StackTrace.empty),
    );

    expect(gecti, isTrue);
  });
}
