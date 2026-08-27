import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/palette.dart';
import '../../app/theme.dart';
import '../../app/typography.dart';
import '../../core/constants/job_constants.dart';
import '../../core/utils/customer_display.dart';
import '../../shared/tc_icon.dart';
import '../../shared/ui.dart';
import '../jobs/data/jobs_repository.dart';

/// Randevu / Takvim — bkz. docs/05 § Randevu / Takvim.
///
/// Tasarım teslimatı ekran 24: üstte ay ızgarası, altta seçili günün
/// saat saat programı. Saatler tek aralıklı ve sol sütunda hizalı —
/// kullanıcı günü tek bakışta tarıyor, satırları tek tek okumuyor.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  static final _gunBasligi = DateFormat('d MMMM, EEEE', 'tr_TR');

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final jobsAsync = ref.watch(jobsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Takvim')),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => AppErrorState(
          message: 'Takvim yüklenemedi.',
          onRetry: () => ref.invalidate(jobsListProvider),
        ),
        data: (jobs) {
          final gunlere = <DateTime, List<JobWithCustomer>>{};
          for (final item in jobs) {
            if (item.job.appointmentDate == null) continue;
            final day = _dayOnly(item.job.appointmentDate!);
            gunlere.putIfAbsent(day, () => []).add(item);
          }

          final secilenler = [...?gunlere[_dayOnly(_selectedDay)]]
            ..sort((a, b) => _saat(a).compareTo(_saat(b)));

          return Column(
            children: [
              TableCalendar<JobWithCustomer>(
                locale: 'tr_TR',
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: (day) => gunlere[_dayOnly(day)] ?? const [],
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: palet.accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(color: palet.accent),
                  selectedDecoration: BoxDecoration(
                    color: palet.accentSolid,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: palet.accent,
                    shape: BoxShape.circle,
                  ),
                  markerSize: 4,
                  outsideTextStyle: TextStyle(color: palet.textFaint),
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),
              Divider(height: 1, color: palet.border),

              // Gün başlığı ve iş sayısı: ızgarada bir güne dokunan
              // kullanıcı "o gün kaç iş var" sorusunun cevabını aşağıyı
              // saymadan görüyor.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _gunBasligi.format(_selectedDay),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      secilenler.isEmpty
                          ? 'iş yok'
                          : '${secilenler.length} iş planlı',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palet.textMuted),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: secilenler.isEmpty
                    ? const AppEmptyState(
                        icon: TcIcons.calendar,
                        title: 'Bu günde iş yok',
                        message:
                            'Randevu verdiğin işler burada saat sırasıyla '
                            'görünür.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          0,
                          AppSpacing.xl,
                          AppSpacing.xxl,
                        ),
                        itemCount: secilenler.length,
                        itemBuilder: (context, index) =>
                            _ProgramSatiri(item: secilenler[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Sıralama anahtarı: önce iş kaydındaki başlangıç saati, o yoksa
  /// randevu tarihinin saati.
  static String _saat(JobWithCustomer item) {
    final baslangic = item.job.startTime?.trim();
    if (baslangic != null && baslangic.isNotEmpty) return baslangic;
    final tarih = item.job.appointmentDate;
    return tarih == null ? '99:99' : DateFormat('HH:mm').format(tarih);
  }
}

/// Günün programındaki tek satır.
class _ProgramSatiri extends StatelessWidget {
  const _ProgramSatiri({required this.item});

  final JobWithCustomer item;

  @override
  Widget build(BuildContext context) {
    final palet = context.palette;
    final job = item.job;
    final oncelikRengi = jobPriorityColors[job.priority] ?? palet.textMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Text(
                _CalendarScreenState._saat(item).replaceAll('99:99', '—'),
                style: AppTypography.mono.copyWith(
                  fontSize: 13,
                  color: palet.textMuted,
                ),
              ),
            ),
          ),
          Expanded(
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: () => context.push('/jobs/${job.id}'),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 34,
                    decoration: BoxDecoration(
                      color: oncelikRengi,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.customer.displayName,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palet.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
