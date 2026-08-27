import 'package:flutter/material.dart';

import '../../shared/tc_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../shared/step_indicator.dart';
import '../../shared/ui.dart';
import '../../shared/wordmark.dart';
import 'data/auth_repository.dart';
import 'data/google_auth_service.dart';
import 'data/session_controller.dart';

/// Kayıt / Onboarding ekranı — bkz. docs/10 § SaaS Vizyonu örnek akışı:
/// işletme türü → firma bilgileri → sahip bilgileri → hazır.
///
/// [googlePrefill] doluysa (Login ekranından "Google ile devam et" ile
/// gelindiyse) e-posta/ad Google'dan alınır, parola alanları gizlenir —
/// bkz. docs/09 § Kimlik Doğrulama Yöntemleri.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.googlePrefill});

  final GoogleAuthResult? googlePrefill;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

const _businessTypeOptions = [
  'Elektrik',
  'Kamera / Güvenlik',
  'Bilgisayar',
  'Diğer',
];

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  late final _ownerNameController = TextEditingController(
    text: widget.googlePrefill?.displayName ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.googlePrefill?.email ?? '',
  );
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  final Set<String> _selectedBusinessTypes = {};
  bool _isSubmitting = false;
  String? _errorText;

  /// Görünen adım (0..2) — tasarım teslimatı ekran 18.
  ///
  /// Kayıt formu on alan taşıyordu ve telefonda tek ekranda hepsi
  /// görününce kullanıcı "bu kadar çok şey mi soruyor" deyip
  /// vazgeçiyordu. Hesap → Firma → İş Türleri olarak bölündü.
  int _adim = 0;

  @override
  void initState() {
    super.initState();
    _adim = _ilkAdim;
  }

  final Set<int> _hataliAdimlar = {};

  /// Google akışında parola sorulmuyor; o yüzden ilk adımda tek alan
  /// (e-posta, o da kilitli) kalıyor ve adım atlanabilir hâle geliyor.
  int get _ilkAdim => _isGoogleFlow ? 1 : 0;

  /// Adımın eksiği varsa nedenini döner.
  String? _adimEksigi(int adim) {
    if (adim == 2 && _selectedBusinessTypes.isEmpty) {
      return 'En az bir işletme türü seç.';
    }
    // Form doğrulaması alan alan mesajını kendi gösteriyor; burada
    // yalnızca geçilip geçilemeyeceği soruluyor.
    if (adim < 2 && !(_formKey.currentState?.validate() ?? false)) {
      return '';
    }
    return null;
  }

  void _ileriGit() {
    final eksik = _adimEksigi(_adim);
    if (eksik != null) {
      setState(() => _hataliAdimlar.add(_adim));
      if (eksik.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(eksik)));
      }
      return;
    }
    setState(() {
      _hataliAdimlar.remove(_adim);
      _adim += 1;
    });
  }

  bool get _isGoogleFlow => widget.googlePrefill != null;

  @override
  void dispose() {
    _companyNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorText = null);

    if (_selectedBusinessTypes.isEmpty) {
      setState(() => _errorText = 'En az bir işletme türü seçmelisin.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      if (_isGoogleFlow) {
        await ref
            .read(sessionControllerProvider.notifier)
            .registerWithGoogle(
              idToken: widget.googlePrefill!.idToken,
              companyName: _companyNameController.text.trim(),
              businessTypes: _selectedBusinessTypes.toList(),
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
            );
      } else {
        await ref
            .read(sessionControllerProvider.notifier)
            .register(
              companyName: _companyNameController.text.trim(),
              businessTypes: _selectedBusinessTypes.toList(),
              ownerFullName: _ownerNameController.text.trim(),
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim().isEmpty
                  ? null
                  : _phoneController.text.trim(),
              password: _passwordController.text,
            );
      }
      if (mounted) context.go('/dashboard');
    } on AuthException catch (e) {
      // "Bu hesap zaten var" bir çıkmaz sokak olmamalı: kullanıcıyı giriş
      // ekranına, ne yapması gerektiğini söyleyerek geri gönder.
      if (mounted && e.message.toLowerCase().contains('zaten bir hesap var')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu hesap zaten kayıtlı. Giriş ekranından devam edebilirsin.',
            ),
          ),
        );
        context.go('/login');
        return;
      }
      setState(() => _errorText = e.message);
    } catch (_) {
      setState(
        () => _errorText = 'Kayıt sırasında bir sorun oluştu, tekrar dene.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesap Oluştur'),
        leading: _adim > _ilkAdim
            ? IconButton(
                icon: const TcIcon(TcIcons.arrowLeft),
                onPressed: () => setState(() => _adim -= 1),
              )
            : null,
      ),
      body: Column(
        children: [
          StepIndicator(
            etiketler: const ['Hesap', 'Firma', 'İş Türleri'],
            adim: _adim,
            hataliAdimlar: _hataliAdimlar,
            // Google akışında ilk adım hiç gösterilmiyor; oraya geri
            // dönmek boş bir ekran açardı.
            onGit: (i) => setState(() => _adim = i < _ilkAdim ? _ilkAdim : i),
          ),
          Divider(height: 1, color: palet.border),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                children: [
                  if (_adim == 0) ...[
                    const Wordmark(fontSize: 24),
                    const SizedBox(height: AppSpacing.xl),
                    const SectionHeader(
                      'Hesap bilgilerin',
                      subtitle: 'Uygulamaya bu bilgilerle gireceksin.',
                    ),
                    TextFormField(
                      controller: _ownerNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Ad Soyad'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ad soyad gerekli'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'E-posta gerekli';
                        }
                        if (!v.contains('@')) return 'Geçerli bir e-posta gir';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Şifre'),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'En az 6 karakter olmalı'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordConfirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Şifre (tekrar)',
                      ),
                      validator: (v) => v != _passwordController.text
                          ? 'Şifreler eşleşmiyor'
                          : null,
                    ),
                  ],

                  if (_adim == 1) ...[
                    const SectionHeader(
                      'Firma bilgileri',
                      subtitle:
                          'Tekliflerin ve belgelerin üstünde bu bilgiler '
                          'görünecek.',
                    ),
                    TextFormField(
                      controller: _companyNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Firma adı'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Firma adı gerekli'
                          : null,
                    ),
                    if (_isGoogleFlow) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _ownerNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Yetkili adı soyadı',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ad soyad gerekli'
                            : null,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        helperText: 'Zorunlu değil.',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Vergi dairesi/no ve şehir tasarımda burada; kayıt
                    // uçları bu alanları almıyor ve kayıt sırasında ikinci
                    // bir istek atmak hesabı yarım bırakma riski
                    // doğuruyor. Kullanıcıya nereden gireceği söyleniyor.
                    Text(
                      'Vergi dairesi, adres ve logonu kayıttan sonra '
                      'Ayarlar → Şirket ayarlarından girebilirsin.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                    ),
                  ],

                  if (_adim == 2) ...[
                    const SectionHeader(
                      'Ne iş yapıyorsun?',
                      subtitle:
                          'Seçtiklerine göre hazır iş türleri tanımlanır; '
                          'sonradan değiştirebilirsin.',
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _businessTypeOptions.map((type) {
                        final selected = _selectedBusinessTypes.contains(type);
                        return FilterChip(
                          label: Text(type),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedBusinessTypes.add(type);
                              } else {
                                _selectedBusinessTypes.remove(type);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  if (_errorText != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _errorText!,
                      style: TextStyle(color: palet.dangerText),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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
                  onPressed: _isSubmitting
                      ? null
                      : (_adim == 2 ? _submit : _ileriGit),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_adim == 2 ? 'Hesabı Oluştur' : 'Devam Et'),
                ),
              ),
              if (_adim == _ilkAdim)
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Zaten hesabın var mı? Giriş yap'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
