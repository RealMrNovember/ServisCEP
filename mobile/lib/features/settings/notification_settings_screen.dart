import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/notification_service.dart';

const _leadKey = 'reminder_lead_minutes';

/// Hatırlatma süresi tercihini kalıcı olarak okur/yazar ve
/// [NotificationService]'e uygular.
final reminderLeadProvider =
    StateNotifierProvider<ReminderLeadController, AsyncValue<int>>((ref) {
      return ReminderLeadController(ref);
    });

class ReminderLeadController extends StateNotifier<AsyncValue<int>> {
  ReminderLeadController(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final storage = _ref.read(secureStorageProvider);
    final raw = await storage.read(key: _leadKey);
    final minutes =
        int.tryParse(raw ?? '') ??
        NotificationService.defaultReminderLeadMinutes;
    NotificationService.reminderLeadMinutes = minutes;
    if (mounted) state = AsyncValue.data(minutes);
  }

  Future<void> set(int minutes) async {
    NotificationService.reminderLeadMinutes = minutes;
    state = AsyncValue.data(minutes);
    await _ref
        .read(secureStorageProvider)
        .write(key: _leadKey, value: '$minutes');
  }
}

/// Bildirim ayarları — yerel hatırlatmalar ve sunucu bildirimleri.
///
/// Not: sistem düzeyindeki bildirim izni uygulama içinden kapatılamaz
/// (Android bunu işletim sistemi ayarlarına bırakır) — bu yüzden burada
/// yalnızca uygulamanın kendi davranışı ayarlanır, izin durumu için
/// kullanıcı sistem ayarlarına yönlendirilir.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  static const _options = <int, String>{
    0: 'Kapalı',
    15: '15 dakika önce',
    30: '30 dakika önce',
    60: '1 saat önce',
    120: '2 saat önce',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final selected = ref.watch(reminderLeadProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            'İş randevusu hatırlatması',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Planlanmış bir işin randevu saatinden ne kadar önce '
            'hatırlatılmak istersin?',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),

          if (selected == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            // Flutter 3.32+ ile grup durumu RadioGroup ataşıyla yönetiliyor;
            // RadioListTile'ın kendi groupValue/onChanged'i kullanımdan kalktı.
            RadioGroup<int>(
              groupValue: selected,
              onChanged: (value) {
                if (value == null) return;
                ref.read(reminderLeadProvider.notifier).set(value);
              },
              child: Column(
                children: _options.entries
                    .map(
                      (entry) => RadioListTile<int>(
                        value: entry.key,
                        title: Text(entry.value),
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ),

          if (selected == 0)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 20,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Randevu hatırlatmaları kapalı. Yeni oluşturduğun '
                      'işler için hatırlatma zamanlanmayacak.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onTertiaryContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 36),

          Text(
            'Sunucu bildirimleri',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Abonelik onayı ve süre hatırlatması gibi bildirimler, uygulama '
            'kapalıyken de telefonuna iletilir. Bu bildirimleri tamamen '
            'kapatmak istersen telefonunun Ayarlar → Uygulamalar → TeknikCEP '
            '→ Bildirimler bölümünü kullanabilirsin.',
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
