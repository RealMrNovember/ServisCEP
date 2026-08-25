import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

/// Logo kırpma ekranı.
///
/// Neden hazır bir paket değil: `image_cropper` Android'de UCrop
/// Activity'sini ve AppCompat temasını manifest'e eklemeyi gerektirir; bu
/// uygulamanın teması AppCompat değil. Kırpma işi burada tek bir
/// `drawImageRect` çağrısına indiğinden, native yüzeye dokunmadan saf Dart
/// ile çözmek hem daha az kırılgan hem de görsel olarak uygulamanın geri
/// kalanıyla tutarlı.
///
/// Kullanıcı görseli kaydırır/yakınlaştırır; pencerede görünen alan aynen
/// dışa aktarılır — "ne görüyorsan o çıkar" garantisi.
class LogoCropperScreen extends StatefulWidget {
  const LogoCropperScreen({
    super.key,
    required this.bytes,
    this.aspectRatio = 1,
    this.title = 'Logoyu kırp',
    this.maxOutputWidth = 900,
  });

  final Uint8List bytes;

  /// Genişlik / yükseklik. Logolar için 1 (kare) varsayılan.
  final double aspectRatio;
  final String title;

  /// Çıktı genişliği üst sınırı — PDF'te 60pt basılan bir logo için
  /// 900px fazlasıyla yeterli, dosyayı gereksiz şişirmenin anlamı yok.
  final int maxOutputWidth;

  @override
  State<LogoCropperScreen> createState() => _LogoCropperScreenState();
}

class _LogoCropperScreenState extends State<LogoCropperScreen> {
  ui.Image? _image;
  String? _error;

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

  /// Görselin pencereyi tam kaplaması için gereken taban ölçek.
  double _baseScale(ui.Image image) {
    return math.max(
      _viewport.width / image.width,
      _viewport.height / image.height,
    );
  }

  double _effectiveScale(ui.Image image) => _baseScale(image) * _userScale;

  /// Kaydırmayı, görselin pencereden çekilip boşluk bırakmayacağı aralıkta
  /// tutar — kırpılmış logonun kenarında beyaz bant kalması istenmez.
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
      final outHeight = outWidth / widget.aspectRatio;
      final dstRect = Rect.fromLTWH(0, 0, outWidth, outHeight);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, dstRect);
      // Şeffaf PNG'ler PDF'te beyaz kağıdın üstünde duracağı için zemin
      // beyaza boyanır; aksi halde koyu temada çekilmiş şeffaf bir logo
      // belgede kaybolur.
      canvas.drawRect(dstRect, Paint()..color = Colors.white);
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
                          final width = math.min(
                            constraints.maxWidth - AppSpacing.xxl * 2,
                            420.0,
                          );
                          final size = Size(width, width / widget.aspectRatio);
                          if (size != _viewport) {
                            _viewport = size;
                            // İlk ölçüm sonrası kaydırmayı sınırlara oturt.
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
                AppSpacing.xl,
              ),
              child: Column(
                children: [
                  const Text(
                    'Parmağınla kaydır, iki parmakla yakınlaştır.',
                    style: TextStyle(color: Colors.white60, fontSize: 12.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.sm),
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

/// Kırpma penceresi — görseli çizer, dışını karartır, kılavuz çizgileri
/// gösterir.
class _CropViewport extends StatelessWidget {
  const _CropViewport({
    required this.size,
    required this.image,
    required this.scale,
    required this.offset,
  });

  final Size size;
  final ui.Image image;
  final double scale;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: CustomPaint(
          painter: _CropPainter(image: image, scale: scale, offset: offset),
          child: CustomPaint(
            painter: _GuidePainter(),
            size: size,
          ),
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
  });

  final ui.Image image;
  final double scale;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B0B0D),
    );

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
      old.image != image || old.scale != scale || old.offset != offset;
}

class _GuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
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
