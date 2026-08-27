import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/sync_api_client.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';

/// Parola sıfırlama — e-postayla gelen 6 haneli kodla.
///
/// Bağlantı değil KOD kullanılıyor: bağlantı kullanıcıyı tarayıcıya,
/// oradan uygulamaya geri dönmeye zorlar ve o yolculuğun her adımı kayıp
/// kullanıcı demek. İki aşama tek ekranda — kod istendikten sonra sayfa
/// değişmiyor, alanlar açılıyor; kullanıcı e-postaya bakıp geri
/// döndüğünde girdiği adres hâlâ ekranda duruyor.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Giriş ekranında yazılmış e-posta — kullanıcı ikinci kez yazmasın.
  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _kod = TextEditingController();
  final _parola = TextEditingController();

  /// Kod gönderildi mi — ikinci aşamanın alanları buna göre açılıyor.
  bool _kodGonderildi = false;
  bool _calisiyor = false;
  String? _hata;

  @override
  void dispose() {
    _email.dispose();
    _kod.dispose();
    _parola.dispose();
    super.dispose();
  }

  Future<void> _kodIste() async {
    final adres = _email.text.trim();
    if (adres.isEmpty || !adres.contains('@')) {
      setState(() => _hata = 'Geçerli bir e-posta gir.');
      return;
    }

    setState(() {
      _calisiyor = true;
      _hata = null;
    });
    try {
      await ref.read(syncApiClientProvider).forgotPassword(adres);
      if (!mounted) return;
      setState(() => _kodGonderildi = true);
    } on ApiException catch (e) {
      setState(() => _hata = e.message);
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  Future<void> _sifirla() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _calisiyor = true;
      _hata = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(syncApiClientProvider)
          .resetPassword(
            email: _email.text.trim(),
            code: _kod.text.trim(),
            password: _parola.text,
          );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Parolan değişti. Yeni parolanla giriş yap.'),
        ),
      );
      navigator.pop();
    } on ApiException catch (e) {
      setState(() => _hata = e.message);
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Parolamı Unuttum')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              Text(
                _kodGonderildi ? 'Kodu gir' : 'E-posta adresin',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                _kodGonderildi
                    ? 'Adresine 6 haneli bir kod gönderdik. Kod 15 dakika '
                          'geçerli.'
                    : 'Hesabına bağlı adrese sıfırlama kodu göndereceğiz.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
              ),

              const SizedBox(height: AppSpacing.xl),
              TextFormField(
                controller: _email,
                enabled: !_kodGonderildi,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),

              if (_kodGonderildi) ...[
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _kod,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Kod',
                    counterText: '',
                  ),
                  validator: (v) => (v == null || v.trim().length != 6)
                      ? 'Kod 6 haneli olmalı'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _parola,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Yeni şifre',
                    // Sunucudaki kuralla AYNI sayı. Farklı olduğunda
                    // kullanıcı istemciden geçen bir parolayı sunucuya
                    // reddettiriyor ve sebebini anlamıyor.
                    helperText: 'En az 8 karakter.',
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'En az 8 karakter olmalı'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      TcIcon(TcIcons.info, size: 18, color: palet.textMuted),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Parolan değişince tüm cihazlardaki oturumların '
                          'kapanır.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palet.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_hata != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(_hata!, style: TextStyle(color: palet.dangerText)),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _calisiyor
                      ? null
                      : (_kodGonderildi ? _sifirla : _kodIste),
                  child: _calisiyor
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _kodGonderildi ? 'Parolayı Değiştir' : 'Kod Gönder',
                        ),
                ),
              ),
              // Kod gelmediyse çıkış yolu: e-postayı düzeltip yeniden
              // istemek. Bu olmadan kullanıcı yanlış adres yazdığında
              // ekrandan çıkıp baştan başlamak zorunda kalıyor.
              if (_kodGonderildi)
                TextButton(
                  onPressed: _calisiyor
                      ? null
                      : () => setState(() {
                          _kodGonderildi = false;
                          _kod.clear();
                          _hata = null;
                        }),
                  child: const Text('Kod gelmedi mi? Adresi değiştir'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
