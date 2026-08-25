import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

/// Dijital imza yakalama — bkz. docs/03 § Dijital İmza.
///
/// ⚠️ Bu, resmi elektronik imza (5070 sayılı kanun kapsamındaki nitelikli
/// elektronik imza) yerine geçmez — yalnızca servis kaydına bağlı,
/// değiştirilemez bir onay kaydıdır. Bkz. docs/03 § 2.
class SignatureCaptureScreen extends StatefulWidget {
  const SignatureCaptureScreen({super.key});

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  final _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İmza sahibinin adını gir')));
      return;
    }
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lütfen imza at')));
      return;
    }
    final bytes = await _controller.toPngBytes();
    if (bytes == null || !mounted) return;
    Navigator.of(context).pop((_nameController.text.trim(), bytes));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Müşteri İmzası'),
        actions: [
          TextButton(
            onPressed: () => _controller.clear(),
            child: const Text('Temizle'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'İmza sahibinin adı soyadı',
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Signature(
                    controller: _controller,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu imza resmi elektronik imza yerine geçmez; yalnızca servis kaydına bağlı bir onaydır.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: const Text('İmzayı Kaydet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
