import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/sync/sync_status.dart';
import '../../core/sync/sync_trigger.dart';
import '../sync/data/sync_conflict_repository.dart';
import '../sync/sync_conflicts_screen.dart';

/// Senkron durumu — "verim sunucuya ulaştı mı?" sorusunun cevabı.
///
/// Offline-first bir uygulamada kullanıcı yazdığı verinin cihazda mı
/// kaldığını yoksa ofise de ulaştığını bilemez; bu belirsizlik güveni
/// zedeler. Bu ekran durumu açıkça gösterir ve elle senkron imkânı verir.
class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  static String _relative(DateTime? at) {
    if (at == null) return 'Henüz senkronlanmadı';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return DateFormat('d MMM y HH:mm', 'tr_TR').format(at);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final lastSync = ref.watch(lastSyncProvider).valueOrNull;
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final failed = ref.watch(failedSyncCountProvider).valueOrNull ?? 0;
    final conflicts = ref.watch(localConflictCountProvider).valueOrNull ?? 0;
    final online = ref.watch(isOnlineProvider).valueOrNull;

    final allClear = pending == 0 && failed == 0 && conflicts == 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Senkron durumu')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: allClear
                  ? scheme.primaryContainer
                  : scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  allClear
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_sync_rounded,
                  size: 44,
                  color: allClear
                      ? scheme.onPrimaryContainer
                      : scheme.onTertiaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  allClear
                      ? 'Her şey eşitlendi'
                      : 'Bekleyen değişiklikler var',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: allClear
                        ? scheme.onPrimaryContainer
                        : scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Son senkron: ${_relative(lastSync)}',
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        (allClear
                                ? scheme.onPrimaryContainer
                                : scheme.onTertiaryContainer)
                            .withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _StatusRow(
            icon: online == false
                ? Icons.wifi_off_rounded
                : Icons.wifi_rounded,
            label: 'Bağlantı',
            value: switch (online) {
              true => 'Çevrimiçi',
              false => 'Çevrimdışı',
              null => 'Kontrol ediliyor…',
            },
            warn: online == false,
          ),
          _StatusRow(
            icon: Icons.upload_rounded,
            label: 'Gönderilmeyi bekleyen',
            value: '$pending kayıt',
            warn: pending > 0,
          ),
          if (failed > 0)
            _StatusRow(
              icon: Icons.error_outline_rounded,
              label: 'Gönderilemeyen',
              value: '$failed kayıt',
              warn: true,
            ),
          if (conflicts > 0)
            _StatusRow(
              icon: Icons.sync_problem_rounded,
              label: 'Çakışma',
              value: '$conflicts kayıt',
              warn: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncConflictsScreen()),
              ),
            ),

          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: online == false
                ? null
                : () {
                    ref.read(syncTriggerProvider).syncNow();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Senkron başlatıldı.')),
                    );
                  },
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Şimdi senkronla'),
          ),

          const SizedBox(height: 16),
          Text(
            pending > 0
                ? 'Bekleyen kayıtlar cihazında güvenle duruyor. Bağlantı '
                      'kurulduğunda otomatik olarak gönderilecek — uygulamayı '
                      'açık tutmana gerek yok.'
                : 'Verilerin sunucuyla eşitlenmiş durumda. Uygulama '
                      'bağlantı geldiğinde, öne alındığında ve birkaç '
                      'dakikada bir otomatik senkronlanır.',
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    this.warn = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool warn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = warn ? scheme.error : scheme.onSurfaceVariant;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14.5)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: warn ? scheme.error : scheme.onSurface,
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}
