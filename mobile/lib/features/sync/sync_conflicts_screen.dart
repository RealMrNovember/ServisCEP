import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_trigger.dart';
import 'data/sync_conflict_repository.dart';

/// Senkron çakışmalarını çözme ekranı — bkz. ROADMAP.md § B10.
///
/// Aynı kayıt hem telefonda hem ofiste değiştirildiğinde sunucu mobilin
/// yazmasını reddeder (409) ve çakışmayı kaydeder. Karar ASLA otomatik
/// verilmez; kullanıcı burada iki hali yan yana görüp seçer.
class SyncConflictsScreen extends ConsumerWidget {
  const SyncConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(pendingConflictsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Senkron Çakışmaları')),
      body: conflictsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          onRetry: () => ref.invalidate(pendingConflictsProvider),
        ),
        data: (conflicts) {
          if (conflicts.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingConflictsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: conflicts.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return const _Explainer();
                return _ConflictCard(conflict: conflicts[index - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bu kayıtlar hem telefonda hem ofiste değiştirilmiş. '
              'Hangi halin kalacağını sen seç — hiçbir veri senin onayın '
              'olmadan üzerine yazılmaz.',
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConflictCard extends ConsumerStatefulWidget {
  const _ConflictCard({required this.conflict});
  final PendingConflict conflict;

  @override
  ConsumerState<_ConflictCard> createState() => _ConflictCardState();
}

class _ConflictCardState extends ConsumerState<_ConflictCard> {
  bool _busy = false;

  Future<void> _resolve(String resolution) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(syncConflictRepositoryProvider)
          .resolve(widget.conflict, resolution);
      if (!mounted) return;
      ref.invalidate(pendingConflictsProvider);
      // Sunucunun nihai hali hemen yerele insin.
      ref.read(syncTriggerProvider).syncNow();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Çakışma çözüldü.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çözülemedi — bağlantını kontrol edip tekrar dene.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final conflict = widget.conflict;
    final diffs = conflict.differences;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync_problem_rounded, size: 20, color: scheme.error),
                const SizedBox(width: 8),
                Text(
                  conflict.subjectLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (diffs.isEmpty)
              Text(
                'İki hal arasında görünür bir alan farkı yok — sürüm '
                'numaraları ayrıştığı için kayıt beklemeye alındı.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              )
            else
              ...diffs.map((diff) => _DiffRow(diff: diff)),

            const SizedBox(height: 16),
            if (_busy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _resolve('SUNUCU_TUTULDU'),
                      child: const Text('Ofistekini tut'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _resolve('MOBIL_TUTULDU'),
                      child: const Text('Benimkini tut'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.diff});
  final ConflictFieldDiff diff;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diff.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ValueBox(
                  caption: 'Ofis',
                  value: diff.server,
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ValueBox(
                  caption: 'Telefon',
                  value: diff.mine,
                  background: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  const _ValueBox({
    required this.caption,
    required this.value,
    required this.background,
    required this.foreground,
  });

  final String caption;
  final String value;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: foreground.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 13, color: foreground, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: scheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Bekleyen çakışma yok',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Telefonundaki tüm değişiklikler ofisle uyumlu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
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
            const Text(
              'Çakışmalar alınamadı',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bu ekran internet bağlantısı gerektirir.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
