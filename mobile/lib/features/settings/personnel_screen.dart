import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/customer_display.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import 'data/personnel_repository.dart';

/// Kullanıcılar ve yetkiler — bkz. docs/09 § 1.
///
/// Yalnızca işletme sahibi görebilir (menüde de öyle gösterilir); sunucu
/// da ayrıca doğrular, istemci gizlemesine güvenilmez.
class PersonnelScreen extends ConsumerWidget {
  const PersonnelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(personnelListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcılar ve yetkiler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Personel ekle'),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error is ApiException
              ? error.message
              : 'Personel listesi alınamadı. Bu ekran internet gerektirir.',
          onRetry: () => ref.invalidate(personnelListProvider),
        ),
        data: (people) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(personnelListProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: people.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) return const _Explainer();
              return _PersonnelTile(person: people[index - 1]);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddPersonnelSheet(),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    return AppCard(
      child: Row(
        children: [
          TcIcon(TcIcons.shield, size: 18, color: palet.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Eklediğin kişi, verdiğin e-posta ve şifreyle uygulamaya '
              'girer. Teknisyen rolü işletmenin finansal verilerini görmez.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonnelTile extends ConsumerWidget {
  const _PersonnelTile({required this.person});
  final Personnel person;

  Future<void> _changeRole(BuildContext context, WidgetRef ref) async {
    // Messenger diyalogdan ÖNCE yakalanır: await sonrası context artık
    // geçerli olmayabilir (bkz. use_build_context_synchronously).
    final messenger = ScaffoldMessenger.of(context);
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('${person.fullName} — yeni rol'),
        children: assignableRoles
            .map(
              (role) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(role),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(roleLabels[role] ?? role),
                  subtitle: Text(
                    roleDescriptions[role] ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: role == person.role
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null || selected == person.role) return;

    await _run(
      messenger,
      ref,
      () =>
          ref.read(personnelRepositoryProvider).changeRole(person.id, selected),
      'Rol güncellendi.',
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Personeli sil'),
        content: Text(
          '${person.fullName} silinecek ve telefonundaki oturumu kapanacak. '
          'Oluşturduğu kayıtlar silinmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(
      messenger,
      ref,
      () => ref.read(personnelRepositoryProvider).remove(person.id),
      'Personel silindi.',
    );
  }

  Future<void> _run(
    ScaffoldMessengerState messenger,
    WidgetRef ref,
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      ref.invalidate(personnelListProvider);
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } on ApiException catch (e) {
      // Sunucunun gerekçesi kullanıcıya AYNEN gösterilir (ör. "Son işletme
      // sahibi silinemez", "Paketin 2 kullanıcıya izin veriyor").
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palet = context.palette;

    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palet.accent.withValues(alpha: 0.12),
            borderRadius: AppRadius.field,
          ),
          child: Text(
            initialsOf(person.fullName),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: palet.accent),
          ),
        ),
        title: Text(
          person.fullName,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              person.email,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
            ),
            const SizedBox(height: AppSpacing.xs),
            StatusPill(
              label: person.roleLabel,
              color: person.isOwner ? palet.accent : palet.textMuted,
              dense: true,
            ),
          ],
        ),
        isThreeLine: true,
        // İşletme sahibinin rolü değiştirilemez/silinemez — sunucu da
        // reddeder, burada menüyü hiç göstermiyoruz ki kullanıcı boşuna
        // denemesin.
        trailing: person.isOwner
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) => value == 'role'
                    ? _changeRole(context, ref)
                    : _remove(context, ref),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'role',
                    child: Text('Rolü değiştir'),
                  ),
                  const PopupMenuItem(value: 'remove', child: Text('Sil')),
                ],
              ),
      ),
    );
  }
}

class _AddPersonnelSheet extends ConsumerStatefulWidget {
  const _AddPersonnelSheet();

  @override
  ConsumerState<_AddPersonnelSheet> createState() => _AddPersonnelSheetState();
}

class _AddPersonnelSheetState extends ConsumerState<_AddPersonnelSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'TECHNICIAN';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(personnelRepositoryProvider)
          .create(
            fullName: _nameController.text.trim(),
            email: _emailController.text.trim(),
            role: _role,
            password: _passwordController.text,
            phone: _phoneController.text.trim(),
          );
      ref.invalidate(personnelListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Personel eklendi.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personel ekle',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Ad Soyad'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ad soyad gerekli' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'E-posta gerekli';
                  if (!v.contains('@')) return 'Geçerli bir e-posta gir';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon (opsiyonel)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Başlangıç parolası',
                  helperText: 'Bu parolayı personele kendin ileteceksin.',
                ),
                validator: (v) => (v == null || v.length < 8)
                    ? 'En az 8 karakter olmalı'
                    : null,
              ),
              const SizedBox(height: 16),

              Text(
                'Rol',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              RadioGroup<String>(
                groupValue: _role,
                onChanged: (value) => setState(() => _role = value ?? _role),
                child: Column(
                  children: assignableRoles
                      .map(
                        (role) => RadioListTile<String>(
                          value: role,
                          contentPadding: EdgeInsets.zero,
                          title: Text(roleLabels[role] ?? role),
                          subtitle: Text(
                            roleDescriptions[role] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ekle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
