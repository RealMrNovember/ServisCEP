import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

/// Kırpma çerçevesinin oranı.
///
/// Kare zorunluluğu gerçek bir kusurdu: kurumsal logoların çoğu YATAYDIR
/// (simge + yazı). Kare çerçeveye sıkıştırıldığında kullanıcı ya yazıyı
/// kesip yalnızca simgeyi alabiliyor ya da logoyu küçültüp etrafında
/// kocaman boşluk bırakıyordu.
enum LogoAspect {
  serbest('Serbest', null),
  genis('Geniş 3:1', 3),
  yatay('Yatay 2:1', 2),
  kare('Kare 1:1', 1);

  const LogoAspect(this.label, this.ratio);

  final String label;

  /// Genişlik / yükseklik. `null` ise görselin kendi oranı korunur.
  final double? ratio;
}

/// Kırpılan logonun arkasına konacak zemin.
enum LogoBackground {
  seffaf('Şeffaf', null),
  beyaz('Beyaz', Color(0xFFFFFFFF)),
  koyu('Koyu', Color(0xFF15181F));

  const LogoBackground(this.label, this.color);

  final String label;
  final Color? color;
}

/// Logo kırpma ekranı.
///
/// Neden hazır bir paket değil: `image_cropper` Android'de UCrop
/// Activity'sini ve AppCompat temasını manifest'e eklemeyi gerektirir; bu
/// uygulamanın teması AppCompat değil. Kırpma işi burada tek bir
/// `drawImageRect` çağrısına indiğinden, native yüzeye dokunmadan saf Dart
/// ile çözmek hem daha az kırılgan hem de uygulamanın geri kalanıyla
/// tutarlı.
///
/// Kullanıcı görseli kaydırır/yakınlaştırır; pencerede görünen alan aynen
/// dışa aktarılır — "ne görüyorsan o çıkar" garantisi.
class LogoCropperScreen extends StatefulWidget {
  const LogoCropperScreen({
    super.key,
    required this.bytes,
    this.title = 'Logoyu kırp',
    this.maxOutputWidth = 1200,
  });

  final Uint8List bytes;
  final String title;

  /// Çıktı genişliği üst sınırı — belgede birkaç santimetre basılan bir
  /// logo için fazlasıyla yeterli, dosyayı şişirmenin anlamı yok.
  final int maxOutputWidth;

  @override
  State<LogoCropperScreen> createState() => _LogoCropperScreenState();
}

class _LogoCropperScreenState extends State<LogoCropperScreen> {
  ui.Image? _image;
  String? _error;

  LogoAspect _aspect = LogoAspect.serbest;
  LogoBackground _background = LogoBackground.seffaf;

  double _userScale = 1;
  Offset _offset = Offset.zero;

  double _gestureStartScale = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  Size _viewport = Size.zero;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } on Object {
      if (mounted) setState(() => _error = 'Görsel açılamadı.');
    }
  }

  /// Çerçevenin oranı — "Serbest" seçiliyse görselin kendi oranı.
  double _frameRatio(ui.Image image) =>
      _aspect.ratio ?? (image.width / image.height);

  /// Görselin pencereyi tam kaplaması için gereken taban ölçek.
  double _baseScale(ui.Image image) =>
      math.max(_viewport.width / image.width, _viewport.height / image.height);

  double _effectiveScale(ui.Image image) => _baseScale(image) * _userScale;

  /// Kaydırmayı, görselin pencereden çekilip boşluk bırakmayacağı aralıkta
  /// tutar — kırpılmış logonun kenarında beklenmedik bant kalması istenmez.
  Offset _clampOffset(Offset offset, ui.Image image) {
    final scale = _effectiveScale(image);
    final slackX = math.max(0.0, (image.width * scale - _viewport.width) / 2);
    final slackY = math.max(0.0, (image.height * scale - _viewport.height) / 2);
    return Offset(
      offset.dx.clamp(-slackX, slackX),
      offset.dy.clamp(-slackY, slackY),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartScale = _userScale;
    _gestureStartOffset = _offset;
    _gestureStartFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final image = _image;
    if (image == null) return;

    setState(() {
      _userScale = (_gestureStartScale * details.scale).clamp(1.0, 6.0);
      final panned =
          _gestureStartOffset + (details.localFocalPoint - _gestureStartFocal);
      _offset = _clampOffset(panned, image);
    });
  }

  void _setAspect(LogoAspect aspect) {
    setState(() {
      _aspect = aspect;
      // Çerçeve değişince eski kaydırma anlamını yitirir; başa alınır.
      _userScale = 1;
      _offset = Offset.zero;
      _viewport = Size.zero;
    });
  }

  Future<void> _export() async {
    final image = _image;
    if (image == null || _viewport.isEmpty) return;

    setState(() => _exporting = true);
    try {
      final scale = _effectiveScale(image);
      final imageCenter = Offset(image.width / 2, image.height / 2);

      // Pencere köşesini görsel koordinatına çevir: pencere merkezinden
      // olan uzaklığı ölçeğe böl, görsel merkezine ekle.
      final srcTopLeft =
          imageCenter +
          Offset(
            (-_viewport.width / 2 - _offset.dx) / scale,
            (-_viewport.height / 2 - _offset.dy) / scale,
          );
      final srcRect = Rect.fromLTWH(
        srcTopLeft.dx,
        srcTopLeft.dy,
        _viewport.width / scale,
        _viewport.height / scale,
      );

      final outWidth = math.min(
        widget.maxOutputWidth.toDouble(),
        srcRect.width,
      );
      final outHeight = outWidth * _viewport.height / _viewport.width;
      final dstRect = Rect.fromLTWH(0, 0, outWidth, outHeight);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, dstRect);

      // Zemin KULLANICININ seçimi.
      //
      // Önceden koşulsuz beyaza boyanıyordu ve beyaz/açık renkli logolar
      // belgede tamamen görünmez oluyordu. Şeffaf varsayılan: PNG
      // saydamlığı korunur, belgenin kendi zemini görünür.
      final zemin = _background.color;
      if (zemin != null) {
        canvas.drawRect(dstRect, Paint()..color = zemin);
      }

      canvas.drawImageRect(
        image,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final cropped = await picture.toImage(
        outWidth.round(),
        outHeight.round(),
      );
      picture.dispose();

      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      if (!mounted) return;

      if (data == null) {
        setState(() {
          _exporting = false;
          _error = 'Kırpma tamamlanamadı.';
        });
        return;
      }
      Navigator.of(context).pop<Uint8List>(data.buffer.asUint8List());
    } on Object {
      if (mounted) {
        setState(() {
          _exporting = false;
          _error = 'Kırpma tamamlanamadı.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _error != null
                    ? Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70),
                      )
                    : image == null
                    ? const CircularProgressIndicator()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final ratio = _frameRatio(image);
                          final maxW = math.min(
                            constraints.maxWidth - AppSpacing.xl * 2,
                            460.0,
                          );
                          final maxH = constraints.maxHeight - AppSpacing.xl;

                          // Çerçeve hem genişliğe hem yüksekliğe sığmalı;
                          // yalnızca genişliğe bakmak, dik oranlarda
                          // pencereyi ekran dışına taşırıyordu.
                          var width = maxW;
                          var height = width / ratio;
                          if (height > maxH) {
                            height = maxH;
                            width = height * ratio;
                          }

                          final size = Size(width, height);
                          if (size != _viewport) {
                            _viewport = size;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              setState(
                                () => _offset = _clampOffset(_offset, image),
                              );
                            });
                          }

                          return GestureDetector(
                            onScaleStart: _onScaleStart,
                            onScaleUpdate: _onScaleUpdate,
                            child: _CropViewport(
                              size: size,
                              image: image,
                              scale: _effectiveScale(image),
                              offset: _offset,
                              background: _background.color,
                            ),
                          );
                        },
                      ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                children: [
                  _SecimSatiri(
                    baslik: 'Çerçeve',
                    secenekler: [
                      for (final a in LogoAspect.values)
                        (a.label, a == _aspect, () => _setAspect(a)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SecimSatiri(
                    baslik: 'Zemin',
                    secenekler: [
                      for (final b in LogoBackground.values)
                        (
                          b.label,
                          b == _background,
                          () => setState(() => _background = b),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Parmağınla kaydır, iki parmakla yakınlaştır.',
                    style: TextStyle(color: Colors.white60, fontSize: 12.5),
                  ),
                  Slider(
                    value: _userScale,
                    min: 1,
                    max: 6,
                    onChanged: image == null
                        ? null
                        : (value) => setState(() {
                            _userScale = value;
                            _offset = _clampOffset(_offset, image);
                          }),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: AppColors.bezel),
                          ),
                          onPressed: _exporting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Vazgeç'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _exporting || image == null
                              ? null
                              : _export,
                          child: _exporting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Kullan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Başlık + yatay seçenek şeridi.
class _SecimSatiri extends StatelessWidget {
  const _SecimSatiri({required this.baslik, required this.secenekler});

  final String baslik;
  final List<(String, bool, VoidCallback)> secenekler;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            baslik,
            style: const TextStyle(color: Colors.white60, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (label, secili, onTap) in secenekler)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: secili,
                      onSelected: (_) => onTap(),
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: secili ? Colors.black : Colors.white70,
                      ),
                      backgroundColor: Colors.white10,
                      selectedColor: Colors.white,
                      side: const BorderSide(color: AppColors.bezel),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Kırpma penceresi — görseli çizer, kılavuz çizgileri gösterir.
class _CropViewport extends StatelessWidget {
  const _CropViewport({
    required this.size,
    required this.image,
    required this.scale,
    required this.offset,
    required this.background,
  });

  final Size size;
  final ui.Image image;
  final double scale;
  final Offset offset;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: CustomPaint(
          painter: _CropPainter(
            image: image,
            scale: scale,
            offset: offset,
            background: background,
          ),
          child: CustomPaint(painter: _GuidePainter(), size: size),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter({
    required this.image,
    required this.scale,
    required this.offset,
    required this.background,
  });

  final ui.Image image;
  final double scale;
  final Offset offset;
  final Color? background;

  /// Saydamlığın GÖRÜNMESİ için dama deseni.
  ///
  /// Şeffaf zemin düz bir renkle gösterilirse kullanıcı logonun beyaz mı
  /// saydam mı olduğunu ayırt edemiyor; beyaz bir logo beyaz zeminde
  /// kayboluyor ve bu, ancak belge basıldığında fark ediliyordu.
  void _dama(Canvas canvas, Size size) {
    const kare = 12.0;
    final acik = Paint()..color = const Color(0xFF3A3A40);
    final koyu = Paint()..color = const Color(0xFF2C2C31);

    for (var y = 0.0; y < size.height; y += kare) {
      for (var x = 0.0; x < size.width; x += kare) {
        final ciftMi = ((x / kare).floor() + (y / kare).floor()).isEven;
        canvas.drawRect(Rect.fromLTWH(x, y, kare, kare), ciftMi ? acik : koyu);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final zemin = background;
    if (zemin == null) {
      _dama(canvas, size);
    } else {
      canvas.drawRect(Offset.zero & size, Paint()..color = zemin);
    }

    final drawn = Size(image.width * scale, image.height * scale);
    final topLeft = Offset(
      (size.width - drawn.width) / 2 + offset.dx,
      (size.height - drawn.height) / 2 + offset.dy,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      topLeft & drawn,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image ||
      old.scale != scale ||
      old.offset != offset ||
      old.background != background;
}

class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.8;

    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) => false;
}
