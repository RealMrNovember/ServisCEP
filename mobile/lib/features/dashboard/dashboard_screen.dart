import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Ana Sayfa / Dashboard.
///
/// Ürün vizyonunun merkezi ekranı — bkz. docs/01 § Ana Kullanıcı Deneyimi:
/// kullanıcı uygulamayı açtığında "Bugün ne yapacağım?" sorusunun cevabını
/// doğrudan görmelidir.
///
/// NOT: Bu ekrandaki iş/tahsilat verileri şu an MOCK'tur — backend API'si
/// (Phase 7-9, Phase 15) hazır olduğunda gerçek veriyle değiştirilecektir.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('d MMMM, EEEE', 'tr_TR').format(DateTime.now());
    final jobs = _mockTodayJobs;
    final expectedCollection = jobs.fold<double>(
      0,
      (sum, job) => sum + job.expectedAmount,
    );

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
                    Text(
                      jobs.isEmpty
                          ? 'Bugün planlanmış işin yok.'
                          : 'Bugün ${jobs.length} işin var.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: _CollectionSummaryCard(amount: expectedCollection),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverList.separated(
                itemCount: jobs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _JobCard(job: jobs[index]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yeni iş oluşturma yakında.')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni İş'),
      ),
    );
  }
}

class _CollectionSummaryCard extends StatelessWidget {
  const _CollectionSummaryCard({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatted = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    ).format(amount);

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
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatted,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
  const _JobCard({required this.job});

  final _MockJob job;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Text(
                  job.time,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.customerName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _PriorityChip(priority: job.priority),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final _Priority priority;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      _Priority.high => ('Yüksek', Colors.red),
      _Priority.normal => ('Normal', Colors.blue),
      _Priority.low => ('Düşük', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

enum _Priority { high, normal, low }

class _MockJob {
  const _MockJob({
    required this.time,
    required this.customerName,
    required this.description,
    required this.priority,
    required this.expectedAmount,
  });

  final String time;
  final String customerName;
  final String description;
  final _Priority priority;
  final double expectedAmount;
}

const _mockTodayJobs = [
  _MockJob(
    time: '10:00',
    customerName: 'ABC Market',
    description: 'Kamera arızası',
    priority: _Priority.high,
    expectedAmount: 2500,
  ),
  _MockJob(
    time: '14:00',
    customerName: 'Mehmet Kaya',
    description: 'Bilgisayar kurulumu',
    priority: _Priority.normal,
    expectedAmount: 1200,
  ),
  _MockJob(
    time: '18:00',
    customerName: 'XYZ Apartmanı',
    description: 'İnterkom arızası',
    priority: _Priority.normal,
    expectedAmount: 1050,
  ),
];
