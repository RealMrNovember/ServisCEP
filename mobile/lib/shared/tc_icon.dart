import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/palette.dart';
import 'tc_icon_names.dart';

export 'tc_icon_names.dart';

/// Tasarım sistemi ikonu.
///
/// Kaynak: TeknikCEP-Tasarim-Sistemi.md § 6. İkonlar 24x24 ızgarada,
/// 1.7 kalınlığında çizgi, dolgusuz.
///
/// [Icon] gibi davranır: boyut ve renk verilmezse çevredeki
/// [IconTheme]'den alır, böylece [ListTile], [AppBar] ve buton
/// içlerinde ek ayar gerekmeden doğru görünür.
///
/// Tasarım kuralı: ikon tek başına kullanılmaz, yanında daima yazı olur.
/// Kullanıcı kitlesi simge tahmin etmiyor, yazı okuyor.
class TcIcon extends StatelessWidget {
  const TcIcon(
    this.name, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  /// [TcIcons] içindeki ad. Doğrudan metin yazmak yerine sabiti kullan:
  /// yazım hatası derleme zamanında yakalanır.
  final String name;

  /// Kenar uzunluğu (dp). Verilmezse [IconTheme] boyutu, o da yoksa 24.
  final double? size;

  /// Çizgi rengi. Verilmezse [IconTheme] rengi.
  final Color? color;

  /// Ekran okuyucu etiketi. İkon yalnızca süslemeyse boş bırakılır.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final olcu = size ?? iconTheme.size ?? 24;
    final renk = color ?? iconTheme.color ?? context.palette.textMuted;

    return SvgPicture.asset(
      'assets/icons/tc/$name.svg',
      width: olcu,
      height: olcu,
      // İkonlar currentColor ile çizildiği için tüm çizgiler tek renge
      // boyanır; srcIn tam da bunu yapar.
      colorFilter: ColorFilter.mode(renk, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      // Asset çözülene kadar aynı boyutta boşluk bırakılır ki liste
      // satırları yükleme sırasında zıplamasın.
      placeholderBuilder: (_) => SizedBox(width: olcu, height: olcu),
    );
  }
}
