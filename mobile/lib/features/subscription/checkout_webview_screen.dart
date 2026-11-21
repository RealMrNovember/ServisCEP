import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../shared/tc_icon.dart';

/// Stripe Checkout'un barındırdığı ödeme sayfasını gösterir.
///
/// Kart verisi hiçbir zaman bizim kodumuza uğramaz — bu ekran sadece
/// Stripe'ın sayfasını yükler. Backend'deki `success_url`/`cancel_url`
/// (`/odeme/sonuc/basarili` ve `basarisiz`) adreslerine gelindiğinde ekran
/// kendini kapatır; GERÇEK abonelik uzatma işi Stripe'ın webhook'u
/// üzerinden sunucuda olur — bu ekranın "başarılı" görmesi garanti değil
/// (kullanıcı pencereyi kapatabilir), bu yüzden çağıran taraf her zaman
/// abonelik durumunu sunucudan tazelemeli.
class CheckoutWebViewScreen extends StatefulWidget {
  const CheckoutWebViewScreen({required this.paymentUrl, super.key});

  final String paymentUrl;

  @override
  State<CheckoutWebViewScreen> createState() => _CheckoutWebViewScreenState();
}

class _CheckoutWebViewScreenState extends State<CheckoutWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.navigate;

            if (uri.path == '/odeme/sonuc/basarili') {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            if (uri.path == '/odeme/sonuc/basarisiz') {
              Navigator.of(context).pop(false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kartla Öde'),
        leading: IconButton(
          icon: const TcIcon(TcIcons.x, size: 20),
          tooltip: 'Vazgeç',
          // İptal etmek ödeme yapmamakla aynı şey: webhook hiç gelmeyecek,
          // abonelik değişmeyecek. false dönmek, çağıran tarafın bunu
          // "başarısız" gibi ele almasına yeter.
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
