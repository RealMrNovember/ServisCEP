import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/job_constants.dart';
import '../../core/utils/money.dart';
import '../../shared/brand_footer.dart';
import '../../shared/update_banner.dart';
import '../auth/data/session_controller.dart';
import '../jobs/data/jobs_repository.dart';

/// Ana Sayfa / Dashboard.
///
/// Ürün vizyonunun merkezi ekranı — bkz. docs/01 § Ana Kullanıcı Deneyimi:
/// kullanıcı uygulamayı açtığında "Bugün ne yapacağım?" sorusunun cevabını
/// doğrudan görmelidir. Yerel veritabanından gerçek veriyle beslenir.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('d MMMM, EEEE', 'tr_TR').format(DateTime.now());
    final session = ref.watch(sessionControllerProvider).valueOrNull;
    final jobsAsync = ref.watch(todaysJobsProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (session != null)
                      Text(
                        session.companyName,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.only(top: 8), child: UpdateBanner()),
            ),
            SliverToBoxAdapter(
              child: jobsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (jobs) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Text(
                    jobs.isEmpty ? 'Bugün planlanmış işin yok.' : 'Bugün ${jobs.length} işin var.',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: jobsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (jobs) {
                  final expected = jobs
                      .where((j) => j.job.actualPriceMinor == null)
                      .fold<int>(0, (sum, j) => sum + (j.job.estimatedPriceMinor ?? 0));
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: _CollectionSummaryCard(amountMinor: expected),
                  );
                },
              ),
            ),
            jobsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(padding: const EdgeInsets.all(20), child: Text('Bir hata oluştu: $e')),
              ),
              data: (jobs) {
                if (jobs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: _EmptyTodayState(onCreateJob: () => context.push('/jobs/new')),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  sliver: SliverList.separated(
                    itemCount: jobs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _JobCard(item: jobs[index]),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.only(bottom: 90), child: BrandFooter()),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/jobs/new'),
        icon: const Icon(Icons.add),
        label: const Text('Yeni İş'),
      ),
    );
  }
}

class _CollectionSummaryCard extends StatelessWidget {
  const _CollectionSummaryCard({required this.amountMinor});

  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.payments_outlined, color: scheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bugün tahsil edilmesi beklenen',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Money.formatMinor(amountMinor, decimals: false),
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.item});

  final JobWithCustomer item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final job = item.job;
    final timeLabel = job.appointmentDate != null
        ? DateFormat('HH:mm').format(job.appointmentDate!)
        : '--:--';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/jobs/${job.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.customer.name,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.title,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _PriorityChip(priority: job.priority),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = jobPriorityColors[priority] ?? Colors.grey;
    final label = jobPriorityLabels[priority] ?? priority;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _EmptyTodayState extends StatelessWidget {
  const _EmptyTodayState({required this.onCreateJob});
  final VoidCallback onCreateJob;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.wb_sunny_outlined, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Bugün için planlanmış iş yok',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Yeni bir iş oluşturarak günü planla.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateJob,
              icon: const Icon(Icons.add),
              label: const Text('İş Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
