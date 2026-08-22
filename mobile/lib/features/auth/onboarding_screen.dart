import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ServisCEP\'e hoş geldin',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isGoogleFlow
                      ? 'Google hesabınla bağlandın — son adım: işletme bilgilerin.'
                      : 'İşletmeni birkaç adımda kur, hemen kullanmaya başla.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                _SectionTitle('İşletme türün'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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

                const SizedBox(height: 32),
                _SectionTitle('Firma bilgileri'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _companyNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Firma / işletme adı',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Firma adı gerekli'
                      : null,
                ),

                const SizedBox(height: 32),
                _SectionTitle('Senin bilgilerin'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ownerNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Ad Soyad'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ad soyad gerekli'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isGoogleFlow,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-posta',
                    suffixIcon: _isGoogleFlow
                        ? const Icon(
                            Icons.verified,
                            size: 18,
                            color: Colors.green,
                          )
                        : null,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'E-posta gerekli';
                    if (!v.contains('@')) return 'Geçerli bir e-posta gir';
                    return null;
                  },
                ),
                if (!_isGoogleFlow) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon (opsiyonel)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Parola'),
                    validator: (v) {
                      if (v == null || v.length < 6)
                        return 'En az 6 karakter olmalı';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordConfirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Parola (tekrar)',
                    ),
                    validator: (v) {
                      if (v != _passwordController.text)
                        return 'Parolalar eşleşmiyor';
                      return null;
                    },
                  ),
                ],

                if (_errorText != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorText!, style: TextStyle(color: scheme.error)),
                ],

                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Hesabı oluştur'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Zaten hesabın var mı? Giriş yap'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
