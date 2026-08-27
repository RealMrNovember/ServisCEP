import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../shared/brand_footer.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import '../../shared/wordmark.dart';
import 'data/auth_repository.dart';
import 'data/google_auth_service.dart';
import 'data/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _googleAuth = GoogleAuthService();
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (mounted) context.go('/dashboard');
    } on AuthException catch (e) {
      setState(() => _errorText = e.message);
    } catch (_) {
      setState(
        () => _errorText = 'Giriş sırasında bir sorun oluştu, tekrar dene.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isGoogleSubmitting = true;
      _errorText = null;
    });
    try {
      final result = await _googleAuth.signIn();
      if (result == null) return; // kullanıcı iptal etti

      try {
        await ref
            .read(sessionControllerProvider.notifier)
            .continueWithGoogle(result.idToken, email: result.email);
        if (mounted) context.go('/dashboard');
      } on AuthException catch (e) {
        // Kayıt akışına YALNIZCA sunucu "böyle bir hesap yok" dediğinde
        // gidilir (bkz. docs/09).
        //
        // Daha önce her AuthException kayda yönlendiriyordu: sunucuya
        // ulaşılamadığında mevcut — hatta ücretli — bir hesabın sahibi
        // "hesabı oluştur" ekranında buluyordu kendini. Ağ hatasında
        // kullanıcıyı giriş ekranında tutup tekrar denemesini istemek
        // doğru davranış.
        if (!mounted) return;
        if (e.accountMissing) {
          context.go('/onboarding', extra: result);
          return;
        }
        setState(() => _errorText = e.message);
      }
    } catch (e) {
      // Ham hata mesajı bilinçli olarak gösteriliyor — jenerik metin,
      // destek talebi geldiğinde asıl nedeni (ör. ApiException: 10)
      // gizliyordu ve teşhisi imkansız kılıyordu.
      setState(() => _errorText = 'Google ile giriş başarısız oldu: $e');
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palet = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Wordmark(fontSize: 26),
                    ),
                    const SizedBox(height: AppSpacing.x3l),
                    Text(
                      'Tekrar hoş geldin',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'E-posta ve şifrenle giriş yap.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: palet.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'E-posta gerekli'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Şifre'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Şifre gerekli' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        _errorText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palet.dangerText),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Giriş Yap'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(child: Divider(color: scheme.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            'veya',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palet.textMuted),
                          ),
                        ),
                        Expanded(child: Divider(color: scheme.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: _isGoogleSubmitting
                          ? null
                          : _continueWithGoogle,
                      icon: _isGoogleSubmitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const _GoogleIcon(),
                      label: const Text('Google ile devam et'),
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    // Çevrimdışı girişin çalıştığını burada söylemek
                    // gerekiyor: sahada bağlantısı olmayan kullanıcı
                    // uygulamayı hiç açamayacağını sanıp vazgeçiyordu.
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          TcIcon(
                            TcIcons.cloudOff,
                            size: 18,
                            color: palet.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Çevrimdışı giriş açık',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Daha önce giriş yaptıysan internet '
                                  'olmadan da uygulamayı açabilirsin.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: palet.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: () => context.go('/onboarding'),
                      child: const Text('Hesabın yok mu? Kayıt ol'),
                    ),
                    const BrandFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google'ın resmi çok renkli "G" logosu (marka kurallarına uygun basit
/// vektör — Google Sign-In butonlarında harici asset olmadan kullanılabilir).
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      width: 18,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final r = s / 2;
    final strokeWidth = s * 0.22;
    final rect = Rect.fromCircle(center: center, radius: r - strokeWidth / 2);

    void arc(double startDeg, double sweepDeg, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect,
        startDeg * 3.14159265 / 180,
        sweepDeg * 3.14159265 / 180,
        false,
        paint,
      );
    }

    arc(-45, 90, const Color(0xFF4285F4));
    arc(45, 90, const Color(0xFF34A853));
    arc(135, 45, const Color(0xFFFBBC05));
    arc(180, 45, const Color(0xFFEA4335));

    final barPaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - strokeWidth / 2, r, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
