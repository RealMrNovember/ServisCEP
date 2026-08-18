import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/customer_types.dart';
import '../../core/database/app_database.dart';
import '../auth/data/session_controller.dart';
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
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _phoneController = TextEditingController(text: widget.existing?.phone ?? '');
  late final _emailController = TextEditingController(text: widget.existing?.email ?? '');
  late final _addressController = TextEditingController(text: widget.existing?.address ?? '');
  late final _ilController = TextEditingController(text: widget.existing?.il ?? '');
  late final _ilceController = TextEditingController(text: widget.existing?.ilce ?? '');
  late final _taxController = TextEditingController(text: widget.existing?.taxInfo ?? '');
  late final _notesController = TextEditingController(text: widget.existing?.notes ?? '');

  late String _type = widget.existing?.type ?? 'BIREYSEL';
  bool _showMore = false;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _ilController.dispose();
    _ilceController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final repo = ref.read(customersRepositoryProvider);
    try {
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          name: _nameController.text.trim(),
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
        await repo.create(
          companyId: session.companyId,
          name: _nameController.text.trim(),
          type: _type,
          phone: _emptyToNull(_phoneController.text),
          email: _emptyToNull(_emailController.text),
          address: _emptyToNull(_addressController.text),
          il: _emptyToNull(_ilController.text),
          ilce: _emptyToNull(_ilceController.text),
          taxInfo: _emptyToNull(_taxController.text),
          notes: _emptyToNull(_notesController.text),
        );
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _emptyToNull(String v) => v.trim().isEmpty ? null : v.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Müşteriyi Düzenle' : 'Yeni Müşteri')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ad Soyad / Firma adı'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Bu alan gerekli' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Müşteri tipi'),
                items: customerTypeLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Adres'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _showMore = !_showMore),
                icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
                label: Text(_showMore ? 'Daha az göster' : 'Daha fazla alan göster'),
              ),
              if (_showMore) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ilController,
                        decoration: const InputDecoration(labelText: 'İl'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _ilceController,
                        decoration: const InputDecoration(labelText: 'İlçe'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _taxController,
                  decoration: const InputDecoration(labelText: 'Vergi bilgileri'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notlar'),
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
                    : Text(_isEditing ? 'Kaydet' : 'Müşteriyi Oluştur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
