import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';

/// Dijital imza yakalama — bkz. docs/03 § Dijital İmza.
///
/// ⚠️ Bu, resmi elektronik imza (5070 sayılı kanun kapsamındaki nitelikli
/// elektronik imza) yerine geçmez — yalnızca servis kaydına bağlı,
/// değiştirilemez bir onay kaydıdır. Bkz. docs/03 § 2.
class SignatureCaptureScreen extends StatefulWidget {
  const SignatureCaptureScreen({super.key, this.altBaslik});

  /// "Demir Market · IS-2026-0412" gibi bağlam satırı.
  ///
  /// Telefon müşteriye uzatıldığında ekranda kimin, hangi iş için imza
  /// attığı yazılı olmalı — imza atan kişi uygulamayı tanımıyor.
  final String? altBaslik;

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  final _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  final _nameController = TextEditingController();

  static final _damga = DateFormat('dd.MM.y HH:mm', 'tr_TR');

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_nameController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('İmza sahibinin adını gir')),
      );
      return;
    }
    if (_controller.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Lütfen imza at')));
      return;
    }
    final bytes = await _controller.toPngBytes();
    if (bytes == null || !mounted) return;
    Navigator.of(context).pop((_nameController.text.trim(), bytes));
  }

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Müşteri İmzası'),
        bottom: widget.altBaslik == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xl,
                    right: AppSpacing.xl,
                    bottom: AppSpacing.sm,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.altBaslik!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                    ),
                  ),
                ),
              ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Telefonu müşteriye uzat',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'Aşağıdaki alana parmakla imzalaması yeterli.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'İmza sahibinin adı soyadı',
                  isDense: true,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                // Tuval her iki temada da BEYAZ: imza belgeye siyah
                // mürekkeple gidiyor, kullanıcı burada ne göreceğini
                // olduğu gibi görmeli.
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: palet.border),
                    borderRadius: AppRadius.card,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Signature(
                    controller: _controller,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'İmza · ${_damga.format(DateTime.now())}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                'Bu imza resmi elektronik imza yerine geçmez; yalnızca bu iş '
                'kaydına bağlı bir onaydır.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _controller.clear(),
                      child: const Text('Temizle'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('İmzayı Kaydet'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
