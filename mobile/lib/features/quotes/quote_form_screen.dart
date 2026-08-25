import 'package:flutter/material.dart';

import '../documents/document_form_screen.dart';

/// Yeni teklif. Gövde [DocumentFormScreen] ile paylaşılır; kullanıcı formun
/// içinden belgeyi proforma faturaya çevirebilir.
class QuoteFormScreen extends StatelessWidget {
  const QuoteFormScreen({super.key, this.preselectedCustomerId});

  final String? preselectedCustomerId;

  @override
  Widget build(BuildContext context) {
    return DocumentFormScreen(preselectedCustomerId: preselectedCustomerId);
  }
}
