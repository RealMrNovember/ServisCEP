import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/job_constants.dart';
import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
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
    final palet = context.palette;
    final custom = ref.watch(customJobTypesProvider).valueOrNull ?? const [];
    final hazirSayisi = jobTypeCatalog.values.fold<int>(
      0,
      (toplam, liste) => toplam + liste.length,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('İş türleri'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              bottom: AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${custom.length + hazirSayisi} tür',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tür ekle'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        children: [
          AppCard(
            child: Row(
              children: [
                TcIcon(TcIcons.bulb, size: 18, color: palet.accent),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Buradaki türler, iş oluştururken "İş başlığı" alanında '
                    'öneri olarak çıkar.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          const SectionHeader('Kendi türlerin'),
          if (custom.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Henüz kendi iş türünü eklemedin.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: palet.textMuted),
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
                  icon: TcIcon(
                    TcIcons.trash,
                    size: 18,
                    color: palet.dangerText,
                  ),
                  tooltip: 'Sil',
                  onPressed: () =>
                      ref.read(jobTypesRepositoryProvider).remove(type.id),
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(
            'Hazır katalog',
            subtitle: 'Uygulamayla birlikte gelir, değiştirilemez.',
          ),
          ...jobTypeCatalog.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: palet.textMuted),
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
