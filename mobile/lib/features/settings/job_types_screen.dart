import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/job_constants.dart';
import '../auth/data/session_controller.dart';
import 'data/job_types_repository.dart';

/// İş türleri — hazır katalog (salt okunur) + kullanıcının kendi ekledikleri.
///
/// Buradaki türler iş oluşturma ekranındaki "İş türü / başlık" alanının
/// otomatik tamamlamasını besler; kullanıcı kendi işine özel türler
/// ekleyerek her seferinde aynı metni yazmaktan kurtulur.
class JobTypesScreen extends ConsumerWidget {
  const JobTypesScreen({super.key});

  Future<void> _addDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    var category = jobTypeCatalog.keys.first;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Yeni iş türü'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: jobTypeCatalog.keys
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'İş türü adı',
                  hintText: 'ör. Jeneratör bakımı',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();
    nameController.dispose();
    if (saved != true || name.isEmpty) return;

    final session = ref.read(sessionControllerProvider).valueOrNull;
    if (session == null) return;
    await ref
        .read(jobTypesRepositoryProvider)
        .add(companyId: session.companyId, category: category, name: name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final custom = ref.watch(customJobTypesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('İş türleri')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tür ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Buradaki türler, iş oluştururken "İş türü / başlık" '
                    'alanında öneri olarak çıkar.',
                    style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Kendi türlerin',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (custom.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Henüz kendi iş türünü eklemedin.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            ...custom.map(
              (type) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.label_outline_rounded),
                title: Text(type.name),
                subtitle: Text(type.category),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  tooltip: 'Sil',
                  onPressed: () =>
                      ref.read(jobTypesRepositoryProvider).remove(type.id),
                ),
              ),
            ),

          const Divider(height: 32),
          Text(
            'Hazır katalog',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Uygulamayla birlikte gelir, değiştirilemez.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...jobTypeCatalog.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: entry.value
                        .map(
                          (name) => Chip(
                            label: Text(
                              name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
