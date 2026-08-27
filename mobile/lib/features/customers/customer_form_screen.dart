import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants/customer_types.dart';
import '../../core/database/app_database.dart';
import '../../core/services/contact_picker.dart';
import '../auth/data/session_controller.dart';
import '../../shared/ui.dart';
import 'data/customers_repository.dart';

/// Yeni müşteri oluşturma / mevcut müşteriyi düzenleme.
///
/// [existing] verilirse düzenleme modunda çalışır — bkz. docs/06 § Form
/// Tasarımı: gereksiz alanlar "Daha Fazla" altında toplanır.
class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.existing});

  final Customer? existing;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _contactNameController = TextEditingController(
    text: widget.existing?.contactName ?? '',
  );
  late final _companyNameController = TextEditingController(
    text: widget.existing?.companyName ?? '',
  );
  late final _ibanController = TextEditingController(
    text: widget.existing?.iban ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.existing?.phone ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.existing?.email ?? '',
  );
  late final _addressController = TextEditingController(
    text: widget.existing?.address ?? '',
  );
  late final _ilController = TextEditingController(
    text: widget.existing?.il ?? '',
  );
  late final _ilceController = TextEditingController(
    text: widget.existing?.ilce ?? '',
  );
  late final _taxController = TextEditingController(
    text: widget.existing?.taxInfo ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.existing?.notes ?? '',
  );

  late String _type = widget.existing?.type ?? 'BIREYSEL';
  bool _showMore = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _contactNameController.dispose();
    _companyNameController.dispose();
    _ibanController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _ilController.dispose();
    _ilceController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _validateNameFields(String? _) {
    if (_contactNameController.text.trim().isNotEmpty) return null;
    if (_companyNameController.text.trim().isNotEmpty) return null;
    return 'Yetkili adı soyadı veya firma adından en az birini gir';
  }

  Future<void> _submit() async {
    String? olusturulanId;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final repo = ref.read(customersRepositoryProvider);
    try {
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          contactName: Value(_emptyToNull(_contactNameController.text)),
          companyName: Value(_emptyToNull(_companyNameController.text)),
          iban: Value(_emptyToNull(_ibanController.text)),
          type: _type,
          phone: Value(_emptyToNull(_phoneController.text)),
          email: Value(_emptyToNull(_emailController.text)),
          address: Value(_emptyToNull(_addressController.text)),
          il: Value(_emptyToNull(_ilController.text)),
          ilce: Value(_emptyToNull(_ilceController.text)),
          taxInfo: Value(_emptyToNull(_taxController.text)),
          notes: Value(_emptyToNull(_notesController.text)),
        );
        await repo.update(updated);
      } else {
        final session = ref.read(sessionControllerProvider).valueOrNull;
        if (session == null) return;

        final olusturulan = await repo.create(
          companyId: session.companyId,
          contactName: _emptyToNull(_contactNameController.text),
          companyName: _emptyToNull(_companyNameController.text),
          iban: _emptyToNull(_ibanController.text),
          type: _type,
          phone: _emptyToNull(_phoneController.text),
          email: _emptyToNull(_emailController.text),
          address: _emptyToNull(_addressController.text),
          il: _emptyToNull(_ilController.text),
          ilce: _emptyToNull(_ilceController.text),
          taxInfo: _emptyToNull(_taxController.text),
          notes: _emptyToNull(_notesController.text),
        );
        olusturulanId = olusturulan.id;
      }
      // Oluşturulan müşterinin kimliğiyle kapanır.
      //
      // Çağıran taraf (teklif formundaki müşteri seçici) bunu kullanıp
      // yeni müşteriyi otomatik seçer. Öncesinde sonuçsuz kapanıyordu:
      // kullanıcı "Yeni" deyip müşteriyi oluşturuyor, forma dönüyor ve
      // müşteri SEÇİLMEMİŞ oluyordu — ama seçtiğini sanıyordu. Belge
      // oluştur düğmesi de bu yüzden sönük kalıyordu.
      if (mounted) context.pop(olusturulanId);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _emptyToNull(String v) => v.trim().isEmpty ? null : v.trim();

  /// Rehberden kişi seç — ad ve telefon alanlarını doldurur. İzin
  /// istenmez (sistem seçicisi kullanılır, bkz. ContactPicker); seçilen
  /// veri yalnızca formu doldurur, ayrıca saklanmaz.
  Future<void> _pickFromContacts() async {
    try {
      final contact = await const ContactPicker().pick();
      if (contact == null || !mounted) return;

      setState(() {
        final name = contact.name?.trim();
        if (name != null && name.isNotEmpty) {
          _contactNameController.text = name;
        }
        final phone = contact.phone?.replaceAll(RegExp(r'\s+'), '');
        if (phone != null && phone.isNotEmpty) {
          _phoneController.text = phone;
        }
      });
      _formKey.currentState?.validate();
    } on ContactPickerException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Müşteriyi Düzenle' : 'Yeni Müşteri'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              // Müşteri tipi EN ÜSTTE ve tek dokunuşluk.
              //
              // Tasarımda iki parçalı bir düğme var; veri modelinde altı
              // tip olduğu için (apartman, site, kamu…) çipe çevrildi —
              // altı parçalı bir düğme telefona sığmıyor.
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final entry in customerTypeLabels.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _type == entry.key,
                      onSelected: (_) => setState(() => _type = entry.key),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              if (!_isEditing) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _pickFromContacts,
                    icon: const Icon(Icons.contacts_outlined, size: 20),
                    label: const Text('Rehberden seç'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextFormField(
                controller: _companyNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Firma adı'),
                validator: _validateNameFields,
                onChanged: (_) => _formKey.currentState?.validate(),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _contactNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Yetkili adı soyadı',
                  helperText: 'Firma adı ya da yetkili — en az biri gerekli.',
                  helperMaxLines: 2,
                ),
                validator: _validateNameFields,
                onChanged: (_) => _formKey.currentState?.validate(),
              ),

              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('İletişim'),
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
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Adres'),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ilController,
                      decoration: const InputDecoration(labelText: 'İl'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _ilceController,
                      decoration: const InputDecoration(labelText: 'İlçe'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(
                'Fatura ve ödeme',
                subtitle: 'Belgelerde bu bilgiler görünür.',
              ),
              TextFormField(
                controller: _taxController,
                decoration: const InputDecoration(
                  labelText: 'Vergi dairesi / no',
                  helperText: 'Örn. Ümraniye · 4820561700',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _ibanController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'IBAN',
                  helperText: 'Zorunlu değil.',
                ),
              ),

              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => setState(() => _showMore = !_showMore),
                icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
                label: Text(_showMore ? 'Notu gizle' : 'Not ekle'),
              ),
              if (_showMore)
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notlar',
                    helperText: 'Yalnızca sende görünür, belgelere geçmez.',
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Kaydet' : 'Müşteriyi Oluştur'),
          ),
        ),
      ),
    );
  }
}
