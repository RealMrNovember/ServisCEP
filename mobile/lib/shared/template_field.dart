import 'package:flutter/material.dart';

import '../shared/tc_icon.dart';

import '../app/theme.dart';
import '../core/models/document_templates.dart';
import 'ui.dart';

/// Hazır şablon seçilebilen metin alanı.
///
/// Alan boş bırakıldığında belge yarım görünüyor; sıfırdan cümle yazmak da
/// saha koşullarında kimsenin yapmak istediği bir iş değil. Bu yüzden her
/// metin alanının yanında tek dokunuşluk hazır ifadeler var — seçilen metin
/// alana yazılır ve oradan serbestçe düzenlenebilir.
class TemplateField extends StatelessWidget {
  const TemplateField({
    super.key,
    required this.controller,
    required this.label,
    required this.templates,
    this.hintText,
    this.maxLines = 1,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final List<DocumentTemplate> templates;
  final String? hintText;
  final int maxLines;
  final String? helper;

  Future<void> _pickTemplate(BuildContext context) async {
    final selected = await showModalBottomSheet<DocumentTemplate>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label — hazır ifadeler',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Seçtikten sonra metni istediğin gibi düzenleyebilirsin.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(
                          sheetContext,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return ListTile(
                      title: Text(template.label),
                      subtitle: Text(
                        template.text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context, template),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      controller.text = selected.text;
      // İmleci sona al ki kullanıcı seçtiği metnin devamını yazabilsin.
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickTemplate(context),
              icon: const TcIcon(TcIcons.sparkle, size: 17),
              label: const Text('Hazır ifade'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hintText,
            isDense: maxLines == 1,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helper!,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Belge metinlerinin tamamını tek kartta toplayan bölüm — hem teklif
/// formunda hem şirket ayarlarında aynı düzen kullanılır.
class DocumentTextsSection extends StatelessWidget {
  const DocumentTextsSection({
    super.key,
    required this.intro,
    required this.paymentTerms,
    required this.deliveryTime,
    required this.warrantyTerms,
    this.notes,
    this.introHelper,
  });

  final TextEditingController intro;
  final TextEditingController paymentTerms;
  final TextEditingController deliveryTime;
  final TextEditingController warrantyTerms;

  /// Serbest not alanı yalnızca belge formunda var; şirket ayarlarında
  /// "varsayılan not" tutmak yanıltıcı olurdu (her teklifin notu farklı).
  final TextEditingController? notes;
  final String? introHelper;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TemplateField(
            controller: intro,
            label: 'Giriş yazısı',
            templates: DocumentTemplates.intros,
            maxLines: 5,
            hintText: 'Sayın Yetkili, …',
            helper: introHelper,
          ),
          const SizedBox(height: AppSpacing.xl),
          TemplateField(
            controller: paymentTerms,
            label: 'Ödeme koşulları',
            templates: DocumentTemplates.paymentTerms,
            hintText: '%50 sipariş onayında, %50 teslimatta',
          ),
          const SizedBox(height: AppSpacing.xl),
          TemplateField(
            controller: deliveryTime,
            label: 'Teslim süresi',
            templates: DocumentTemplates.deliveryTimes,
            hintText: 'Sipariş onayından sonra 5 iş günü',
          ),
          const SizedBox(height: AppSpacing.xl),
          TemplateField(
            controller: warrantyTerms,
            label: 'Garanti',
            templates: DocumentTemplates.warrantyTerms,
            hintText: '2 yıl ürün, 1 yıl işçilik garantisi',
          ),
          if (notes != null) ...[
            const SizedBox(height: AppSpacing.xl),
            TemplateField(
              controller: notes!,
              label: 'Notlar',
              templates: DocumentTemplates.notes,
              maxLines: 4,
              hintText: 'Belgede "Şartlar ve Notlar" kutusunda görünür',
            ),
          ],
        ],
      ),
    );
  }
}
