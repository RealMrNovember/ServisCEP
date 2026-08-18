import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../database/app_database.dart';

/// Yerel iş randevu hatırlatmaları — bkz. docs/05 § Bildirimler.
///
/// Sunucu tarafı push (FCM) ayrı bir aşamadır (docs/06); bu servis internet
/// gerektirmeden, tamamen cihaz üzerinde zamanlanan hatırlatmaları yönetir.
/// Kasıtlı olarak "exact alarm" izni istenmiyor — [AndroidScheduleMode]
/// inexact varyantı kullanılıyor, böylece kullanıcıya ekstra bir izin
/// ekranı çıkmıyor (birkaç dakikalık sapma bu senaryoda kabul edilebilir).
abstract final class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'job_reminders';
  static const _channelName = 'İş Hatırlatmaları';
  static const _reminderLead = Duration(minutes: 30);

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static int _notificationIdFor(String jobId) => jobId.hashCode & 0x7fffffff;

  /// İş için randevu saatinden [_reminderLead] önce bir hatırlatma zamanlar.
  /// Randevu yoksa, geçmişse ya da hatırlatma penceresi geçmişse zamanlama
  /// sessizce atlanır.
  static Future<void> scheduleJobReminder(Job job) async {
    final appointment = job.appointmentDate;
    if (appointment == null) return;

    final fireAt = appointment.subtract(_reminderLead);
    if (fireAt.isBefore(DateTime.now())) return;

    await init();

    await _plugin.zonedSchedule(
      id: _notificationIdFor(job.id),
      title: 'Yaklaşan İş: ${job.title}',
      body:
          '${job.code} — ${DateFormat('d MMM y HH:mm', 'tr_TR').format(appointment)} tarihinde randevunuz var.',
      scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Planlanan iş randevuları için hatırlatmalar',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Randevu iptal edildiğinde ya da iş tamamlandığında zamanlanmış
  /// hatırlatmayı geri alır.
  static Future<void> cancelJobReminder(String jobId) async {
    await init();
    await _plugin.cancel(id: _notificationIdFor(jobId));
  }
}
