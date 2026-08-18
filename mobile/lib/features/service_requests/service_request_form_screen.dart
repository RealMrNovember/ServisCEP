import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/job_constants.dart';
import '../../core/utils/customer_display.dart';
import '../auth/data/session_controller.dart';
import '../customers/data/customers_repository.dart';
import 'data/service_requests_repository.dart';

class ServiceRequestFormScreen extends ConsumerStatefulWidget {
  const ServiceRequestFormScreen({super.key});

  @override
  ConsumerState<ServiceRequestFormScreen> createState() => _ServiceRequestFormScreenState();
}

class _ServiceRequestFormScreenState extends ConsumerState<ServiceRequestFormScreen> {
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
    if (!_formKey.currentState!.validate() || _customerId == null) return;
    setState(() => _isSubmitting = true);
    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) return;

    try {
      await ref
          .read(serviceRequestsRepositoryProvider)
          .create(
            companyId: session.companyId,
            customerId: _customerId!,
            description: _descriptionController.text.trim(),
            priority: _priority,
            address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Talep')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            customersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Müşteriler yüklenemedi: $e'),
              data: (customers) => DropdownButtonFormField<String>(
                initialValue: _customerId,
                decoration: const InputDecoration(labelText: 'Müşteri'),
                items: [
                  for (final c in customers) DropdownMenuItem(value: c.id, child: Text(c.displayName)),
                ],
                onChanged: (v) => setState(() => _customerId = v),
                validator: (v) => v == null ? 'Müşteri seçmelisin' : null,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Talep', hintText: 'ör. 3 kamera görüntü vermiyor'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Bu alan gerekli' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Adres (opsiyonel)'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Öncelik'),
              items: jobPriorityLabels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Talebi Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
