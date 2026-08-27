import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/constants/job_constants.dart';
import '../auth/data/session_controller.dart';
import '../../shared/customer_picker.dart';
import '../../shared/ui.dart';
import '../customers/data/customers_repository.dart';
import 'data/service_requests_repository.dart';

class ServiceRequestFormScreen extends ConsumerStatefulWidget {
  const ServiceRequestFormScreen({super.key});

  @override
  ConsumerState<ServiceRequestFormScreen> createState() =>
      _ServiceRequestFormScreenState();
}

class _ServiceRequestFormScreenState
    extends ConsumerState<ServiceRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  String? _customerId;
  String _priority = 'NORMAL';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Önce bir müşteri seç.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) {
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Oturum bulunamadı, yeniden giriş yap.')),
      );
      return;
    }

    try {
      await ref
          .read(serviceRequestsRepositoryProvider)
          .create(
            companyId: session.companyId,
            customerId: _customerId!,
            description: _descriptionController.text.trim(),
            priority: _priority,
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Müşteri seçici — açılır liste yerine aramalı alt sayfa.
  Future<void> _pickCustomer() async {
    final id = await showCustomerPicker(context);
    if (id != null && mounted) setState(() => _customerId = id);
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);
    final musteriYok = (customersAsync.valueOrNull ?? const []).isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Servis Talebi')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const SectionHeader('Müşteri', subtitle: 'Talebi kim iletti?'),
            if (customersAsync.isLoading)
              const LinearProgressIndicator()
            else if (musteriYok)
              const AppCard(
                child: Text(
                  'Talep kaydetmek için önce bir müşteri eklemelisin.',
                ),
              )
            else
              CustomerSlot(customerId: _customerId, onPick: _pickCustomer),

            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader('Talep'),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Ne oldu?',
                hintText: 'ör. 3 kamera görüntü vermiyor',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bu alan gerekli' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adres',
                helperText: 'Boş bırakırsan müşterinin adresi kullanılır.',
                helperMaxLines: 2,
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader('Öncelik'),
            SegmentedButton<String>(
              segments: [
                for (final entry in jobPriorityLabels.entries)
                  ButtonSegment(value: entry.key, label: Text(entry.value)),
              ],
              selected: {_priority},
              onSelectionChanged: (secim) =>
                  setState(() => _priority = secim.first),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Talebi Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
