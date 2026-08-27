import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/constants/job_constants.dart';
import '../../core/services/notification_service.dart';
import '../auth/data/session_controller.dart';
import '../settings/data/job_types_repository.dart';
import '../customers/data/customers_repository.dart';
import '../../shared/customer_picker.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
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
    final messenger = ScaffoldMessenger.of(context);
    if (!_formKey.currentState!.validate()) return;

    // Eksik neyse adıyla söyleniyor: eskiden müşteri seçilmediğinde
    // düğme sessizce hiçbir şey yapmıyor, kullanıcı sebebini
    // bulamıyordu.
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

  /// Müşteri seçiciyi açar.
  ///
  /// Açılır liste yerine aramalı alt sayfa: müşteri sayısı üç haneye
  /// çıkınca açılır listede aranan kayıt bulunamıyordu.
  Future<void> _pickCustomer() async {
    final id = await showCustomerPicker(context);
    if (id != null && mounted) setState(() => _customerId = id);
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersListProvider);
    final musteriYok = (customersAsync.valueOrNull ?? const []).isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni İş')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              const SectionHeader('Müşteri'),
              if (customersAsync.isLoading)
                const LinearProgressIndicator()
              else if (musteriYok)
                _NoCustomersNotice(
                  onCreateCustomer: () => context.push('/customers/new'),
                )
              else
                CustomerSlot(customerId: _customerId, onPick: _pickCustomer),

              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader('İş'),
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
                      labelText: 'İş başlığı',
                      hintText: 'ör. Kamera sistemi arıza',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Bu alan gerekli'
                        : null,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Açıklama'),
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
              const SectionHeader('Randevu'),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const TcIcon(TcIcons.calendar, size: 18),
                      label: Text('${_date.day}.${_date.month}.${_date.year}'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const TcIcon(TcIcons.clock, size: 18),
                      label: Text(_time.format(context)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader('Öncelik'),
              // Açılır liste değil: üç seçenek var ve öncelik, işi
              // oluşturan kullanıcının en sık değiştirdiği alan.
              SegmentedButton<String>(
                segments: [
                  for (final entry in jobPriorityLabels.entries)
                    ButtonSegment(value: entry.key, label: Text(entry.value)),
                ],
                selected: {_priority},
                onSelectionChanged: (secim) =>
                    setState(() => _priority = secim.first),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
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
                      : const Text('İşi Oluştur'),
                ),
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
