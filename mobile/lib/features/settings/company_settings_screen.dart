import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import 'data/company_repository.dart';

const _businessTypeOptions = [
  'Elektrik',
  'Kamera / Güvenlik',
  'Bilgisayar',
  'Diğer',
];

/// Şirket ayarları — ünvan, işletme türleri, IBAN.
///
/// IBAN, teklif/proforma PDF'lerinde ödeme bilgisi olarak kullanılır;
/// bu yüzden burada düzenlenebilir olması gerekiyor.
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
            : _CompanyForm(company: company),
      ),
    );
  }
}

class _CompanyForm extends ConsumerStatefulWidget {
  const _CompanyForm({required this.company});
  final Company company;

  @override
  ConsumerState<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends ConsumerState<_CompanyForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.company.name);
  late final _ibanController = TextEditingController(
    text: widget.company.iban ?? '',
  );
  late final Set<String> _selectedTypes = widget.company.businessTypes
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet();

  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ibanController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az bir işletme türü seçmelisin.')),
      );
      return;
    }

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
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şirket ayarları kaydedildi.')),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Firma / işletme adı'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Firma adı gerekli' : null,
          ),
          const SizedBox(height: 24),

          Text(
            'İşletme türün',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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

          const SizedBox(height: 24),
          TextFormField(
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
          const SizedBox(height: 8),
          Text(
            'IBAN, oluşturduğun teklif ve proforma belgelerinde ödeme '
            'bilgisi olarak görünür.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),

          const SizedBox(height: 28),
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
          const SizedBox(height: 12),
          Text(
            'Değişiklikler önce cihazına kaydedilir, bağlantı olduğunda '
            'sunucuyla eşitlenir.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
