import 'package:flutter/material.dart';

import '../app/palette.dart';

/// "Teknik**CEP**" kelime markası.
///
/// İki parça iki ağırlıkta: "Teknik" normal, "CEP" vurgu renginde ve
/// kalın. Marka adı üç ekranda (açılış, karşılama, giriş) aynı görünmeli;
/// her birinde ayrı yazıldığında ağırlıklar birbirini tutmuyordu.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 30});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Teknik',
            style: TextStyle(color: palet.text, fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: 'CEP',
            style: TextStyle(color: palet.accent, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      style: TextStyle(fontSize: fontSize, letterSpacing: -0.5, height: 1.1),
    );
  }
}
