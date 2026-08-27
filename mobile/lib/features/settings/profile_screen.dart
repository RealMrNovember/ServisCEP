import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/sync_api_client.dart';
import '../../core/utils/customer_display.dart';
import '../../shared/ui.dart';
import '../auth/data/session_controller.dart';
import 'data/personnel_repository.dart' show roleLabels;

/// Kendi profilim — ad/telefon düzenleme ve parola değiştirme.
///
/// Parola değiştirme özellikle önemli: personel hesapları işletme sahibi
/// tarafından bir başlangıç parolasıyla açılıyor ve o parola sahiple
/// paylaşılmış oluyor. Kullanıcının onu değiştirebilmesi güvenlik gereği.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _phoneController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionControllerProvider).valueOrNull;
    _nameController = TextEditingController(text: session?.fullName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(syncApiClientProvider).updateProfile({
        'full_name': _nameController.text.trim(),
        if (_phoneController.text.trim().isNotEmpty)
          'phone': _phoneController.text.trim(),
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Profilin güncellendi.')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final adSoyad = session?.fullName ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palet.accent.withValues(alpha: 0.12),
                    borderRadius: AppRadius.card,
                  ),
                  child: Text(
                    initialsOf(adSoyad),
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: palet.accent),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adSoyad,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          roleLabels[session?.role] ?? (session?.role ?? ''),
                          if (session?.companyName.isNotEmpty ?? false)
                            session!.companyName,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxl),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Ad soyad'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ad soyad gerekli' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon',
                hintText: 'Boş bırakırsan değişmez',
                helperText:
                    'E-posta adresin kimliğindir; değiştirmek için web '
                    'panelini kullanman gerekir.',
                helperMaxLines: 3,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('Şifre'),
                subtitle: const Text('Diğer cihazlardaki oturumlar kapanır'),
                trailing: TextButton(
                  onPressed: _changePassword,
                  child: const Text('Değiştir'),
                ),
                onTap: _changePassword,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kaydet'),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(syncApiClientProvider)
          .updatePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Parolan güncellendi.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parolamı değiştir',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mevcut parolan'),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Mevcut parolan gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Yeni parola'),
              validator: (v) => (v == null || v.length < 8)
                  ? 'En az 8 karakter olmalı'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Yeni parola (tekrar)',
              ),
              validator: (v) =>
                  v != _newController.text ? 'Parolalar eşleşmiyor' : null,
            ),
            const SizedBox(height: 20),
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
                    : const Text('Değiştir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
