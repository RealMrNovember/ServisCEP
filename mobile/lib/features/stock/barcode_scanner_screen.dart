import 'package:flutter/material.dart';

import '../../shared/tc_icon.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Kamera ile barkod tarama — bkz. docs/16 § Barkod Okuma Akışı.
///
/// Taranan kodu [Navigator.pop] ile geri döndürür; çağıran ekran bunu
/// yerel stokta arar, yoksa global sorgu / manuel form akışına yönlendirir
/// (bkz. scanBarcodeAndOpen).
///
/// Tasarım teslimatı ekran 27: bu ekran her iki temada da KOYU. Kamera
/// görüntüsünün üstünde okunabilirliği tema değil kontrast belirliyor;
/// açık temada beyaz bir çerçeve görüntüde kayboluyordu.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.qrCode,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Barkod Tara'),
        actions: [
          IconButton(
            icon: const TcIcon(TcIcons.flash),
            tooltip: 'Işık',
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              // Marka mavisi: kamera görüntüsünün içinde beyaz çerçeve
              // açık zeminli bir etikette kayboluyordu.
              border: Border.all(color: const Color(0xFF3B82F6), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Barkodu çerçevenin içine getir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Okunduğunda kendiliğinden devam eder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
