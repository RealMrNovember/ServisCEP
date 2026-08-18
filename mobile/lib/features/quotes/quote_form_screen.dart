import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/doc_item_draft.dart';
import '../../shared/document_items_editor.dart';
import '../auth/data/session_controller.dart';
import '../customers/data/customers_repository.dart';
import 'data/quotes_repository.dart';

class QuoteFormScreen extends ConsumerStatefulWidget {
  const QuoteFormScreen({super.key});

  @override
  ConsumerState<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends ConsumerState<QuoteFormScreen> {
  String? _customerId;
  final _notesController = TextEditingController();
  final List<DocItemDraft> _items = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_customerId == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Müşteri seç ve en az bir kalem ekle')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) return;

    try {
      await ref
          .read(quotesRepositoryProvider)
          .create(
            companyId: session.companyId,
            customerId: _customerId!,
            items: _items,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
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
      appBar: AppBar(title: const Text('Yeni Teklif')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          customersAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Müşteriler yüklenemedi: $e'),
            data: (customers) => DropdownButtonFormField<String>(
              initialValue: _customerId,
              decoration: const InputDecoration(labelText: 'Müşteri'),
              items: [
                for (final c in customers) DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _customerId = v),
            ),
          ),
          const SizedBox(height: 24),
          DocumentItemsEditor(
            items: _items,
            onChanged: (items) => setState(() {
              _items
                ..clear()
                ..addAll(items);
            }),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notlar (opsiyonel)'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Teklifi Oluştur (Taslak)'),
          ),
        ],
      ),
    );
  }
}
