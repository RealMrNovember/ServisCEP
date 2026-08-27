import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/database/app_database.dart';
import '../../shared/logo_picker.dart';
import '../../shared/template_field.dart';
import '../../shared/ui.dart';
import 'data/company_repository.dart';

const _businessTypeOptions = [
  'Elektrik',
  'Kamera / Güvenlik',
  'Bilgisayar',
  'Diğer',
];

/// Şirket ayarları — ünvan, işletme türleri, belge antedi, logo, IBAN.
///
/// Buradaki alanların çoğu "ayar" değil, müşteriye giden teklif ve servis
/// formunun antedidir; bu yüzden ekran doğrudan belgenin nasıl görüneceğini
/// anlatacak şekilde gruplanmıştır.
class CompanySettingsScreen extends ConsumerWidget {
  const CompanySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyAsync = ref.watch(currentCompanyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Şirket ayarları')),
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Şirket bilgileri yüklenemedi.')),
        data: (company) => company == null
            ? const Center(child: Text('Şirket bulunamadı.'))
            : _CompanyForm(key: ValueKey(company.id), company: company),
      ),
    );
  }
}

class _CompanyForm extends ConsumerStatefulWidget {
  const _CompanyForm({super.key, required this.company});
  final Company company;

  @override
  ConsumerState<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends ConsumerState<_CompanyForm> {
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(text: widget.company.name);
  late final _addressController = TextEditingController(
    text: widget.company.address ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.company.phone ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.company.email ?? '',
  );
  late final _taxController = TextEditingController(
    text: widget.company.taxInfo ?? '',
  );
  late final _ibanController = TextEditingController(
    text: widget.company.iban ?? '',
  );
  late final _introController = TextEditingController(
    text: widget.company.introText ?? '',
  );
  late final _paymentTermsController = TextEditingController(
    text: widget.company.paymentTerms ?? '',
  );
  late final _deliveryTimeController = TextEditingController(
    text: widget.company.deliveryTime ?? '',
  );
  late final _warrantyTermsController = TextEditingController(
    text: widget.company.warrantyTerms ?? '',
  );

  late final Set<String> _selectedTypes = widget.company.businessTypes
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet();

  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _addressController,
      _phoneController,
      _emailController,
      _taxController,
      _ibanController,
      _introController,
      _paymentTermsController,
      _deliveryTimeController,
      _warrantyTermsController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir işletme türü seçmelisin.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final iban = _ibanController.text.replaceAll(' ', '').trim();
      await ref
          .read(companyRepositoryProvider)
          .update(
            companyId: widget.company.id,
            name: _nameController.text.trim(),
            businessTypes: _selectedTypes.toList(),
            iban: iban.isEmpty ? null : iban,
            address: _trimmedOrNull(_addressController),
            phone: _trimmedOrNull(_phoneController),
            email: _trimmedOrNull(_emailController),
            taxInfo: _trimmedOrNull(_taxController),
            introText: _trimmedOrNull(_introController),
            paymentTerms: _trimmedOrNull(_paymentTermsController),
            deliveryTime: _trimmedOrNull(_deliveryTimeController),
            warrantyTerms: _trimmedOrNull(_warrantyTermsController),
          );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Şirket ayarları kaydedildi.')),
      );
      navigator.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.read(companyRepositoryProvider);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          40,
        ),
        children: [
          AppCard(
            child: LogoPickerField(
              currentPath: widget.company.logoPath,
              onPicked: (bytes) => repository.setLogo(
                companyId: widget.company.id,
                bytes: bytes,
              ),
              onRemoved: () => repository.removeLogo(widget.company.id),
              label: 'Firma logosu',
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'Kimlik',
            subtitle: 'Belgelerin en üstünde bu bilgiler görünür.',
          ),
          AppCard(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Firma / işletme adı',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Firma adı gerekli'
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Adres',
                    helperText: 'Teklif antedinde tek satır olarak yazılır.',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return null;
                    return value.contains('@')
                        ? null
                        : 'Geçerli bir e-posta gir';
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _taxController,
                  decoration: const InputDecoration(
                    labelText: 'Vergi dairesi / numarası',
                    hintText: 'Örn. Kadıköy V.D. 1234567890',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'İşletme türün',
            subtitle: 'Hazır iş türleri ve raporlar buna göre şekillenir.',
          ),
          AppCard(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _businessTypeOptions.map((type) {
                final selected = _selectedTypes.contains(type);
                return FilterChip(
                  label: Text(type),
                  selected: selected,
                  onSelected: (value) => setState(() {
                    if (value) {
                      _selectedTypes.add(type);
                    } else {
                      _selectedTypes.remove(type);
                    }
                  }),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'Ödeme',
            subtitle: 'Teklif ve proformaların altındaki ödeme kutusu.',
          ),
          AppCard(
            child: TextFormField(
              controller: _ibanController,
              decoration: const InputDecoration(
                labelText: 'IBAN (opsiyonel)',
                hintText: 'TR00 0000 0000 0000 0000 0000 00',
              ),
              validator: (v) {
                final value = (v ?? '').replaceAll(' ', '').trim();
                if (value.isEmpty) return null;
                if (value.length < 16 || value.length > 34) {
                  return 'IBAN uzunluğu geçersiz görünüyor';
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'Belge metinleri',
            subtitle:
                'Teklif ve proformalarda varsayılan olarak kullanılır. Her '
                'belgede ayrıca değiştirebilirsin.',
          ),
          DocumentTextsSection(
            intro: _introController,
            paymentTerms: _paymentTermsController,
            deliveryTime: _deliveryTimeController,
            warrantyTerms: _warrantyTermsController,
            introHelper:
                'Boş bırakırsan belgede standart bir giriş metni kullanılır.',
          ),

          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Değişiklikler önce cihazına kaydedilir, bağlantı olduğunda '
            'sunucuyla eşitlenir.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
          ),
        ],
      ),
    );
  }
}
