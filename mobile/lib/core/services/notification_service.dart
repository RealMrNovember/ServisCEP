import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../app/theme.dart';
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

  static const channelId = 'job_reminders';
  static const channelName = 'İş Hatırlatmaları';
  static const _channelId = channelId;
  static const _channelName = channelName;

  /// Randevudan kaç dakika önce hatırlatılacağı. 0 = hatırlatma kapalı.
  /// Kullanıcı "Bildirimler" ayar ekranından değiştirir; varsayılan 30 dk.
  static const defaultReminderLeadMinutes = 30;
  static int reminderLeadMinutes = defaultReminderLeadMinutes;

  /// Sunucudan gelen (FCM) bir bildirimi, yerel hatırlatmalarla AYNI
  /// kanaldan gösterir — kullanıcı için tek bir "İş Hatırlatmaları"
  /// kanalı olur, ayarlarda ikinci bir kalem çıkmaz.
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Planlanan iş randevuları için hatırlatmalar',
          importance: Importance.high,
          priority: Priority.high,
          // Simge tek renkli olmak zorunda; marka rengi ayrıca verilir.
          color: AppColors.accent,
        ),
      ),
    );
  }

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Tek renkli bildirim simgesi — launcher ikonu (renkli) verilirse
    // Android yalnızca alfa kanalını kullandığı için simge tanınmaz bir
    // leke olarak görünür. Bkz. res/drawable/ic_notification.xml.
    const androidInit = AndroidInitializationSettings('@drawable/ic_notification');
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
    if (reminderLeadMinutes <= 0) return; // kullanıcı kapatmış

    final fireAt = appointment.subtract(
      Duration(minutes: reminderLeadMinutes),
    );
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
          // Simge tek renkli olmak zorunda; marka rengi ayrıca verilir.
          color: AppColors.accent,
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
