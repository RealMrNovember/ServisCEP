import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/palette.dart';
import '../../app/typography.dart';
import '../../shared/tc_icon.dart';

import '../../app/theme.dart';
import '../../core/constants/job_constants.dart';
import '../../core/utils/customer_display.dart';
import '../../core/utils/money.dart';
import '../../shared/skeleton.dart';
import '../../shared/sync_indicators.dart';
import '../../shared/ui.dart';
import '../service_requests/data/service_requests_repository.dart';
import '../service_requests/service_request_form_screen.dart';
import 'data/jobs_repository.dart';

/// İşler ekranı — bkz. docs/06 § Mobil Navigasyon. "Talepler" (docs/02 §
/// Talep Modülü) ayrı bir alt sekme olarak burada barındırılır; ayrı bir
/// bottom-nav sekmesi açmak sade navigasyon prensibine aykırı olurdu.
class JobsListScreen extends StatefulWidget {
  const JobsListScreen({super.key});

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isJobsTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İşler'),
        // Bekleyen kayıt rozeti — tasarım sistemi § 6.2. Sayı 0
        // olduğunda tamamen kaybolur.
        actions: const [
          PendingBadge(),
          SizedBox(width: AppSpacing.md),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'İşler'),
            Tab(text: 'Talepler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_JobsTab(), _RequestsTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (isJobsTab) {
            context.push('/jobs/new');
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ServiceRequestFormScreen(),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: Text(isJobsTab ? 'Yeni İş' : 'Yeni Talep'),
      ),
    );
  }
}

class _JobsTab extends ConsumerStatefulWidget {
  const _JobsTab();

  @override
  ConsumerState<_JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends ConsumerState<_JobsTab> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsListProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              _FilterChipItem(
                label: 'Tümü',
                selected: _statusFilter == null,
                onTap: () => setState(() => _statusFilter = null),
              ),
              for (final entry in jobStatusLabels.entries)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _FilterChipItem(
                    label: entry.value,
                    selected: _statusFilter == entry.key,
                    onTap: () => setState(() => _statusFilter = entry.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: jobsAsync.when(
            loading: () => const AppSkeleton(pattern: SkeletonPattern.cards),
            error: (_, _) => AppErrorState(
              message: 'İş listesi yüklenemedi.',
              onRetry: () => ref.invalidate(jobsListProvider),
            ),
            data: (jobs) {
              final filtered = _statusFilter == null
                  ? jobs
                  : jobs.where((j) => j.job.status == _statusFilter).toList();

              if (jobs.isEmpty) {
                return _EmptyState(onAdd: () => context.push('/jobs/new'));
              }
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'Bu durumda iş yok',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _JobTile(item: filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(serviceRequestsListProvider);

    return requestsAsync.when(
      loading: () => const AppSkeleton(pattern: SkeletonPattern.cards),
      error: (_, _) => AppErrorState(
        message: 'Servis talepleri yüklenemedi.',
        onRetry: () => ref.invalidate(serviceRequestsListProvider),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Talepler müşteriden gelir',
            message: 'Onayladığın talep otomatik olarak iş listesine düşer.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _RequestTile(item: requests[index]),
        );
      },
    );
  }
}

/// Servis talebi kartı — tasarım teslimatı ekran 19.
///
/// İki eylem yan yana: reddetmek de en az işe çevirmek kadar sık.
/// Önceden yalnızca "İşe Dönüştür" vardı; istemediği talebi kapatmanın
/// yolu olmayan kullanıcının listesi hiç boşalmıyordu.
class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.item});
  final RequestWithCustomer item;

  Future<void> _convert(BuildContext context, WidgetRef ref) async {
    final job = await ref
        .read(serviceRequestsRepositoryProvider)
        .convertToJob(item.request);
    if (context.mounted) context.push('/jobs/${job.id}');
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Talebi reddet'),
        content: const Text(
          'Talep listede "Reddedildi" olarak kalır, silinmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reddet'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    await ref.read(serviceRequestsRepositoryProvider).reject(item.request);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palet = context.palette;
    final request = item.request;
    final canConvert =
        request.status == 'BEKLIYOR' || request.status == 'ISLEME_ALINDI';

    final (durumMetni, durumRengi) = switch (request.status) {
      'BEKLIYOR' => ('Yeni', palet.accent),
      'ISLEME_ALINDI' => ('İncelendi', palet.warningText),
      'REDDEDILDI' => ('Reddedildi', palet.dangerText),
      _ => ('İşe dönüştü', palet.successText),
    };

    return AppCard(
      pending: request.syncStatus == 'PENDING',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.description,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 3),
          Text(
            '${item.customer.displayName} · ${_gecenSure(request.createdAt)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StatusPill(label: durumMetni, color: durumRengi, dense: true),
              const Spacer(),
              if (canConvert) ...[
                TextButton(
                  onPressed: () => _reject(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: palet.dangerText,
                  ),
                  child: const Text('Reddet'),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton.tonal(
                  onPressed: () => _convert(context, ref),
                  child: const Text('İşe Çevir'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// "2 saat önce" / "Dün 16:20" / "23 Ağu".
  ///
  /// Sahadaki kullanıcı için talebin ne kadar beklediği, tam tarihinden
  /// daha önemli — geciken talep müşteri kaybı demek.
  static String _gecenSure(DateTime an) {
    final fark = DateTime.now().difference(an);
    if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
    if (fark.inHours < 24) return '${fark.inHours} saat önce';
    if (fark.inDays == 1) return 'Dün ${DateFormat('HH:mm').format(an)}';
    return DateFormat('d MMM', 'tr_TR').format(an);
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

/// İş kartı — tasarım teslimatı ekran 02.
///
/// İki bölüm: üstte kim/ne, altta ne zaman/ne kadar. Aradaki çizgi
/// bilinçli — kullanıcı listede gezerken iki ayrı soruyu ayrı ayrı
/// tarıyor ("hangi iş?" ve "ne zaman?").
class _JobTile extends StatelessWidget {
  const _JobTile({required this.item});
  final JobWithCustomer item;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final job = item.job;
    final tamamlandi = job.status == 'TAMAMLANDI';

    // Gerçekleşen ücret yoksa tahmini fiyata düşülmez: tamamlanmış bir işte
    // tahmini rakam göstermek, tahsil edilen tutarmış gibi okunur.
    final tutarKurus = tamamlandi ? job.actualPriceMinor : null;
    final tutar = tutarKurus == null || tutarKurus == 0
        ? null
        : Money.formatMinor(tutarKurus, decimals: false);

    // Kayıt cihazda ama sunucuda değil. Kullanıcı bunu BİLMELİ: aksi halde
    // telefonunu kaybettiğinde neyin gitmediğini de bilmez.
    final bekliyor = job.syncStatus == 'PENDING';

    return AppCard(
      padding: EdgeInsets.zero,
      pending: bekliyor,
      onTap: () => context.push('/jobs/${job.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                _DurumSimgesi(status: job.status),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _musteriSatiri(item),
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
          ),
          Divider(height: 1, color: palet.border),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                _DurumRozeti(status: job.status, priority: job.priority),
                const SizedBox(width: AppSpacing.md),
                TcIcon(TcIcons.clock, size: 14, color: palet.textMuted),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    _zamanMetni(job.appointmentDate, job.startTime),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                // Ücret girilmemişse hiçbir şey gösterilmez — sıfır yazmak
                // yanıltıcı olurdu.
                if (tutar != null)
                  Text(tutar, style: AppTypography.mono.copyWith(fontSize: 14)),
              ],
            ),
          ),
          if (bekliyor)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  TcIcon(TcIcons.cloudOff, size: 14, color: palet.warningText),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Cihazda · gönderilmedi',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palet.warningText),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _musteriSatiri(JobWithCustomer i) {
    final ad = i.customer.displayName;
    final ilce = i.customer.ilce;
    return ilce == null || ilce.isEmpty ? ad : '$ad · $ilce';
  }

  /// "Bugün · 14:30" biçimi.
  ///
  /// Bugün/yarın kelimeyle yazılıyor: kullanıcı listeyi tararken tarihi
  /// kafasında çevirmek zorunda kalmamalı.
  static String _zamanMetni(DateTime? randevu, String? saat) {
    if (randevu == null) return 'Tarih belirlenmedi';

    final simdi = DateTime.now();
    final bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final gun = DateTime(randevu.year, randevu.month, randevu.day);
    final fark = gun.difference(bugun).inDays;

    final gunMetni = switch (fark) {
      0 => 'Bugün',
      1 => 'Yarın',
      -1 => 'Dün',
      _ => DateFormat('d MMM', 'tr_TR').format(randevu),
    };

    final saatMetni = saat ?? DateFormat('HH:mm').format(randevu);
    return '$gunMetni · $saatMetni';
  }
}

/// Kartın solundaki renkli daire.
class _DurumSimgesi extends StatelessWidget {
  const _DurumSimgesi({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final (renk, ikon) = switch (status) {
      'TAMAMLANDI' => (palet.successText, TcIcons.checkCircle),
      'IPTAL' => (palet.dangerText, TcIcons.x),
      'DEVAM_EDIYOR' => (palet.warningText, TcIcons.wrench),
      _ => (palet.accent, TcIcons.briefcase),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: AppRadius.field,
      ),
      child: Center(child: TcIcon(ikon, size: 18, color: renk)),
    );
  }
}

/// Durum rozeti.
///
/// Öncelik YÜKSEK ise durum yerine "Acil" gösteriliyor: kullanıcı listede
/// önce aciliyete bakıyor, durum ikinci sırada geliyor.
class _DurumRozeti extends StatelessWidget {
  const _DurumRozeti({required this.status, required this.priority});

  final String status;
  final String priority;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final acil = priority == 'YUKSEK' && status != 'TAMAMLANDI';

    final (metin, renk) = acil
        ? ('Acil', palet.dangerText)
        : switch (status) {
            'TAMAMLANDI' => ('Tamamlandı', palet.successText),
            'IPTAL' => ('İptal', palet.textMuted),
            'DEVAM_EDIYOR' => ('Devam', palet.warningText),
            _ => (jobStatusLabels[status] ?? status, palet.accent),
          };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            metin,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: renk, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.work_outline_rounded,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz iş yok',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk işini oluşturarak başla.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('İş Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
