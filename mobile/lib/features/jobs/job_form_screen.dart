import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/job_constants.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/customer_display.dart';
import '../auth/data/session_controller.dart';
import '../settings/data/job_types_repository.dart';
import '../customers/data/customers_repository.dart';
import 'data/jobs_repository.dart';

/// Yeni iş oluşturma — bkz. docs/06 § Form Tasarımı örneği.
class JobFormScreen extends ConsumerStatefulWidget {
  const JobFormScreen({super.key, this.preselectedCustomerId});

  final String? preselectedCustomerId;

  @override
  ConsumerState<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends ConsumerState<JobFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  String? _customerId;
  String _priority = 'NORMAL';
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _customerId = widget.preselectedCustomerId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customerId == null) return;

    setState(() => _isSubmitting = true);
    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) return;

    final appointment = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    try {
      final job = await ref
          .read(jobsRepositoryProvider)
          .create(
            companyId: session.companyId,
            customerId: _customerId!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            appointmentDate: appointment,
            startTime:
                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
            priority: _priority,
          );
      await NotificationService.scheduleJobReminder(job);
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni İş')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            children: [
              customersAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Müşteriler yüklenemedi: $e'),
                data: (customers) {
                  if (customers.isEmpty) {
                    return _NoCustomersNotice(
                      onCreateCustomer: () => context.push('/customers/new'),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    initialValue: _customerId,
                    decoration: const InputDecoration(labelText: 'Müşteri'),
                    items: [
                      for (final c in customers)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.displayName),
                        ),
                    ],
                    onChanged: (v) => setState(() => _customerId = v),
                    validator: (v) => v == null ? 'Müşteri seçmelisin' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  final allTypes = ref.watch(allJobTypeNamesProvider);
                  return allTypes.where(
                    (t) => t.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
                  );
                },
                onSelected: (selection) => _titleController.text = selection,
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  controller.text = _titleController.text;
                  return TextFormField(
                    controller: _titleController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'İş türü / başlık',
                      hintText: 'ör. Kamera arızası',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Bu alan gerekli'
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Açıklama / talep',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adres (opsiyonel)',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Öncelik'),
                items: jobPriorityLabels.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _priority = v ?? _priority),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text('${_date.day}.${_date.month}.${_date.year}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(_time.format(context)),
                    ),
                  ),
                ],
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
                    : const Text('İşi Oluştur'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoCustomersNotice extends StatelessWidget {
  const _NoCustomersNotice({required this.onCreateCustomer});
  final VoidCallback onCreateCustomer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('İş oluşturmak için önce bir müşteri eklemelisin.'),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: onCreateCustomer,
            child: const Text('Müşteri Ekle'),
          ),
        ],
      ),
    );
  }
}
