import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
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
      } on AuthException {
        // Bu Google hesabıyla eşleşen bir hesap yok — kayıt akışına,
        // Google bilgileri ön-dolu şekilde yönlendir (bkz. docs/09).
        if (mounted) context.go('/onboarding', extra: result);
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: AppColors.accent,
                          size: 32,
                        ),
                      ),
                    ),
                    Text(
                      'Tekrar hoş geldin',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Devam etmek için giriş yap',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: scheme.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'veya e-posta ile',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: scheme.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'E-posta gerekli'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Parola'),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Parola gerekli' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Giriş yap'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/onboarding'),
                      child: const Text('Hesabın yok mu? Kayıt ol'),
                    ),
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
