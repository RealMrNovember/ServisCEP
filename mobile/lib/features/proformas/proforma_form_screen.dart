import 'package:flutter/material.dart';

import '../documents/document_form_screen.dart';

/// Yeni proforma fatura — teklifle aynı form gövdesi
/// (bkz. [DocumentFormScreen]), yalnızca açılış türü farklı.
class ProformaFormScreen extends StatelessWidget {
  const ProformaFormScreen({super.key, this.preselectedCustomerId});

  final String? preselectedCustomerId;

  @override
  Widget build(BuildContext context) {
    return DocumentFormScreen(
      initialKind: DocumentKind.proforma,
      preselectedCustomerId: preselectedCustomerId,
    );
  }
}
