import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/theme.dart';
import 'logo_cropper.dart';

/// Logo seçme alanı: kaynak seç → kırp → çağırana bayt olarak ver.
///
/// Kırpma adımı bilinçli olarak seçimin hemen ardında zorunlu: belgeye
/// gömülecek görselin çerçevesi kullanıcının elinde olmazsa, telefonla
/// çekilmiş yamuk bir logo teklifin en tepesinde duruyor.
class LogoPickerField extends StatefulWidget {
  const LogoPickerField({
    super.key,
    required this.currentPath,
    required this.onPicked,
    required this.onRemoved,
    this.label = 'Logo',
    this.helper,
  });

  /// Halihazırda kayıtlı logonun yerel yolu (yoksa null).
  final String? currentPath;

  /// Kırpılmış PNG baytları.
  final ValueChanged<Uint8List> onPicked;
  final VoidCallback onRemoved;

  final String label;
  final String? helper;

  @override
  State<LogoPickerField> createState() => _LogoPickerFieldState();
}

class _LogoPickerFieldState extends State<LogoPickerField> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Kırpma zaten küçültüyor; buradaki sınır yalnızca çok büyük
        // fotoğrafların belleği zorlamasını engellemek için.
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => LogoCropperScreen(bytes: bytes),
          fullscreenDialog: true,
        ),
      );
      if (cropped != null) widget.onPicked(cropped);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSourceSheet() async {
    final hasLogo = widget.currentPath != null;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamerayla çek'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (hasLogo)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Logoyu kaldır',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );

    switch (action) {
      case 'gallery':
        await _pick(ImageSource.gallery);
      case 'camera':
        await _pick(ImageSource.camera);
      case 'remove':
        widget.onRemoved();
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = widget.currentPath;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LogoThumb(path: path, busy: _busy, onTap: _busy ? null : _openSourceSheet),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.helper ??
                    'Teklif ve servis formlarının en üstünde görünür. '
                        'Seçtikten sonra çerçeveyi kendin ayarlayabilirsin.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                    ),
                    onPressed: _busy ? null : _openSourceSheet,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(path == null ? 'Logo ekle' : 'Değiştir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoThumb extends StatelessWidget {
  const _LogoThumb({required this.path, required this.busy, this.onTap});

  final String? path;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.card,
          border: Border.all(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: busy
            ? const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : path == null
            ? Icon(
                Icons.add_photo_alternate_outlined,
                color: scheme.onSurfaceVariant,
              )
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                // Dosya silinmiş/bozulmuşsa ekran çökmemeli.
                errorBuilder: (_, _, _) => Icon(
                  Icons.broken_image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
