import 'dart:async';

import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/palette.dart';
import '../app/theme.dart';

/// İskelet yükleme deseni — tasarım sistemi § 5.
enum SkeletonPattern {
  /// Liste satırı: avatar kutusu + iki metin çizgisi.
  list,

  /// Kart listesi: iki katmanlı kart.
  cards,

  /// Detay ekranı: tek büyük blok + alan satırları.
  detail,
}

/// Dönen daire yerine kullanılan yükleme iskeleti.
///
/// Tasarım sistemi dönen daireyi bilinçli olarak yasaklıyor: iskelet,
/// gelecek içeriğin şeklini önden gösterdiği için bekleme kısa hissettiriyor
/// ve içerik gelince düzen zıplamıyor.
///
/// **500 ms kuralı:** bu süreden kısa yüklemelerde iskelet HİÇ gösterilmez.
/// Anlık gelen veride bir anlığına iskelet çakmak, yüklemeyi gizlemekten
/// daha rahatsız edici. Kural widget'ın içine gömülü; çağıran tarafın
/// hatırlaması gerekmiyor.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.pattern = SkeletonPattern.list,
    this.count = 3,
  });

  final SkeletonPattern pattern;

  /// Kaç tekrar çizileceği. [SkeletonPattern.detail] için yoksayılır.
  final int count;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  static const _gecikme = Duration(milliseconds: 500);

  /// Denetleyici `initState` içinde kuruluyor, `late` alan olarak DEĞİL.
  ///
  /// `late` hâlinde ilk erişimde oluşuyordu ve liste 500 ms'den hızlı
  /// yüklendiğinde ilk erişim `dispose()` oluyordu: iskelet hiç
  /// görünmeden, sırf yok etmek için, ARTIK KAPATILMIŞ bir eleman
  /// üzerinde ticker kuruluyordu. Ticker kurulumu ağaçta yukarı bakıyor
  /// (TickerMode) ve kapatılmış bir elemanda bu tanımsız davranış.
  late final AnimationController _parilti;

  /// Gecikme zamanlayıcısı SAKLANIYOR ki dispose'da iptal edilebilsin.
  /// `Future.delayed` iptal edilemiyor; widget söküldükten sonra da
  /// çalışmaya devam ediyordu.
  Timer? _gecikmeZamanlayici;

  bool _gorunur = false;

  @override
  void initState() {
    super.initState();
    _parilti = AnimationController(vsync: this, duration: AppMotion.shimmer);

    // Parıltı ancak iskelet GÖRÜNDÜĞÜNDE dönmeye başlıyor. Baştan
    // döndürmek, hiç görünmeyecek iskeletlerde de kare üretirdi.
    _gecikmeZamanlayici = Timer(_gecikme, () {
      if (!mounted) return;
      setState(() => _gorunur = true);
      _parilti.repeat();
    });
  }

  @override
  void dispose() {
    _gecikmeZamanlayici?.cancel();
    _parilti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_gorunur) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: 1,
      duration: AppMotion.slow,
      child: AnimatedBuilder(
        animation: _parilti,
        builder: (context, _) => _desenCiz(context, _parilti.value),
      ),
    );
  }

  Widget _desenCiz(BuildContext context, double ilerleme) {
    return switch (widget.pattern) {
      SkeletonPattern.list => Column(
        children: List.generate(
          widget.count,
          (_) => _SatirIskeleti(ilerleme: ilerleme),
        ),
      ),
      SkeletonPattern.cards => Column(
        children: List.generate(
          widget.count,
          (_) => _KartIskeleti(ilerleme: ilerleme),
        ),
      ),
      SkeletonPattern.detail => _DetayIskeleti(ilerleme: ilerleme),
    };
  }
}

/// Parıltılı dikdörtgen — iskeletlerin yapı taşı.
class _Blok extends StatelessWidget {
  const _Blok({
    required this.ilerleme,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  final double ilerleme;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [palet.skeleton, palet.skeletonSheen, palet.skeleton],
          // Parıltı soldan sağa geçer; -1..2 aralığı, bandın görünür
          // alana girip tamamen çıkmasını sağlar.
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1 + ilerleme * 3, 0),
          end: Alignment(1 + ilerleme * 3, 0),
        ),
      ),
    );
  }
}

class _SatirIskeleti extends StatelessWidget {
  const _SatirIskeleti({required this.ilerleme});

  final double ilerleme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSize.rowMin,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.palette.border)),
      ),
      child: Row(
        children: [
          _Blok(
            ilerleme: ilerleme,
            width: AppSize.iconBox,
            height: AppSize.iconBox,
            radius: AppRadius.md,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Blok(ilerleme: ilerleme, width: 160, height: 14),
                const SizedBox(height: AppSpacing.sm),
                _Blok(ilerleme: ilerleme, width: 100, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KartIskeleti extends StatelessWidget {
  const _KartIskeleti({required this.ilerleme});

  final double ilerleme;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palet.surface,
        borderRadius: AppRadius.card,
        border: Border.all(color: palet.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Blok(
                ilerleme: ilerleme,
                width: AppSize.iconBox,
                height: AppSize.iconBox,
                radius: AppRadius.md,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Blok(ilerleme: ilerleme, width: 180, height: 16),
              ),
              const SizedBox(width: AppSpacing.md),
              _Blok(ilerleme: ilerleme, width: 64, height: 24, radius: 999),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: palet.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Blok(ilerleme: ilerleme, width: 120, height: 13),
              _Blok(ilerleme: ilerleme, width: 80, height: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetayIskeleti extends StatelessWidget {
  const _DetayIskeleti({required this.ilerleme});

  final double ilerleme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Blok(
            ilerleme: ilerleme,
            width: double.infinity,
            height: 120,
            radius: AppRadius.lg,
          ),
          const SizedBox(height: AppSpacing.xxl),
          for (final genislik in <double>[200, 260, 160, 220])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _Blok(ilerleme: ilerleme, width: genislik, height: 14),
            ),
        ],
      ),
    );
  }
}
