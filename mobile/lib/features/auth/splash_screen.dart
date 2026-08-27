import 'package:flutter/material.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../shared/brand_footer.dart';
import '../../shared/wordmark.dart';

/// Açılış — tasarım teslimatı ekran 15.
///
/// Boş bir dönen halka yerine marka ve ne beklendiği yazılı. Açılışta
/// yerel veritabanı hazırlanıyor ve bu bazı cihazlarda bir saniyeyi
/// geçiyor; kullanıcıya "uygulama takıldı mı?" dedirtmemek için ne
/// olduğu söyleniyor.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Wordmark(fontSize: 34),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Saha servisin cebinde.\nİnternet olmasa da çalışır.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palet.textMuted),
            ),
            const SizedBox(height: AppSpacing.x3l),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palet.accent,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Yerel veriler hazırlanıyor…',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palet.textFaint),
            ),
            const Spacer(),
            const BrandFooter(),
          ],
        ),
      ),
    );
  }
}
