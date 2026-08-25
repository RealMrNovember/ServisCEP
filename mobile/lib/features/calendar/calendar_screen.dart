import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/constants/job_constants.dart';
import '../../core/utils/customer_display.dart';
import '../jobs/data/jobs_repository.dart';

/// Randevu / Takvim — bkz. docs/05 § Randevu / Takvim.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Takvim')),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (jobs) {
          final jobsByDay = <DateTime, List<JobWithCustomer>>{};
          for (final item in jobs) {
            if (item.job.appointmentDate == null) continue;
            final day = _dayOnly(item.job.appointmentDate!);
            jobsByDay.putIfAbsent(day, () => []).add(item);
          }

          final selectedJobs = jobsByDay[_dayOnly(_selectedDay)] ?? const [];

          return Column(
            children: [
              TableCalendar<JobWithCustomer>(
                locale: 'tr_TR',
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) => jobsByDay[_dayOnly(day)] ?? const [],
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: selectedJobs.isEmpty
                    ? Center(
                        child: Text(
                          'Bu günde iş yok',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: selectedJobs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = selectedJobs[index];
                          final job = item.job;
                          final priorityColor =
                              jobPriorityColors[job.priority] ?? Colors.grey;
                          return Card(
                            child: ListTile(
                              onTap: () => context.push('/jobs/${job.id}'),
                              leading: Container(
                                width: 8,
                                decoration: BoxDecoration(
                                  color: priorityColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              title: Text(
                                DateFormat(
                                  'HH:mm',
                                ).format(job.appointmentDate!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${item.customer.displayName} · ${job.title}',
                              ),
                              trailing: Text(
                                jobStatusLabels[job.status] ?? job.status,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
