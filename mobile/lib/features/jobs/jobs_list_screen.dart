import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/job_constants.dart';
import '../../core/utils/customer_display.dart';
import '../../core/utils/money.dart';
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

class _JobsListScreenState extends State<JobsListScreen> with SingleTickerProviderStateMixin {
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'İşler'), Tab(text: 'Talepler')],
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
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ServiceRequestFormScreen()));
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Bir hata oluştu: $e')),
            data: (jobs) {
              final filtered = _statusFilter == null
                  ? jobs
                  : jobs.where((j) => j.job.status == _statusFilter).toList();

              if (jobs.isEmpty) {
                return _EmptyState(onAdd: () => context.push('/jobs/new'));
              }
              if (filtered.isEmpty) {
                return Center(
                  child: Text('Bu durumda iş yok', style: TextStyle(color: scheme.onSurfaceVariant)),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _JobTile(item: filtered[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

const _requestStatusLabels = {
  'BEKLIYOR': 'Bekliyor',
  'ISLEME_ALINDI': 'İşleme Alındı',
  'REDDEDILDI': 'Reddedildi',
  'ISE_DONUSTU': 'İşe Dönüştü',
};

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(serviceRequestsListProvider);
    final scheme = Theme.of(context).colorScheme;

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Bir hata oluştu: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 56, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz talep yok',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
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

class _RequestTile extends ConsumerWidget {
  const _RequestTile({required this.item});
  final RequestWithCustomer item;

  Future<void> _convert(BuildContext context, WidgetRef ref) async {
    final job = await ref.read(serviceRequestsRepositoryProvider).convertToJob(item.request);
    if (context.mounted) context.push('/jobs/${job.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = item.request;
    final canConvert = request.status == 'BEKLIYOR' || request.status == 'ISLEME_ALINDI';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.customer.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Text(request.code, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(request.description),
            const SizedBox(height: 10),
            Row(
              children: [
                Chip(
                  label: Text(
                    _requestStatusLabels[request.status] ?? request.status,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                if (canConvert)
                  FilledButton.tonal(
                    onPressed: () => _convert(context, ref),
                    child: const Text('İşe Dönüştür'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.item});
  final JobWithCustomer item;

  @override
  Widget build(BuildContext context) {
    final job = item.job;
    final statusColor = jobStatusColors[job.status] ?? Colors.grey;
    final priorityColor = jobPriorityColors[job.priority] ?? Colors.grey;
    final dateLabel = job.appointmentDate != null
        ? DateFormat('d MMM, HH:mm', 'tr_TR').format(job.appointmentDate!)
        : 'Tarih belirlenmedi';

    // Gerçekleşen ücret yoksa tahmini fiyata düşülmez: tamamlanmış bir işte
    // tahmini rakam göstermek, tahsil edilen tutarmış gibi okunur.
    final priceMinor = job.status == 'TAMAMLANDI' ? job.actualPriceMinor : null;
    final priceLabel = priceMinor == null || priceMinor == 0
        ? null
        : Money.formatMinor(priceMinor);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/jobs/${job.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(item.customer.displayName, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    dateLabel,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  // Tamamlanan işlerde alınan ücret kartta görünür:
                  // kullanıcı "bu işten ne kazandım" sorusunun cevabını
                  // detaya girmeden görebilmeli. Ücret girilmemişse hiçbir
                  // şey gösterilmez — "₺0,00" yazmak yanıltıcı olurdu.
                  if (priceLabel != null) ...[
                    Text(
                      priceLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: jobStatusColors['TAMAMLANDI'] ?? statusColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      jobStatusLabels[job.status] ?? job.status,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
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
            Icon(Icons.work_outline_rounded, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Henüz iş yok',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk işini oluşturarak başla.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('İş Oluştur')),
          ],
        ),
      ),
    );
  }
}
