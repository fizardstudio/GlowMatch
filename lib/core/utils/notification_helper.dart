import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:isar/isar.dart';
import '../network/database_service.dart';
import '../../features/pouch/data/models/pouch_item.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
    );

    // Daftarkan channel notifikasi alarm untuk Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'expiry_alerts',
      'Peringatan Kedaluwarsa Kosmetik',
      description: 'Notifikasi peringatan kosmetik di pouch yang mendekati kedaluwarsa PAO.',
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> scheduleExpiryNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Jika tanggal terjadwal berada di masa lampau, lewati
    if (scheduledDate.isBefore(DateTime.now())) return;

    final tz.TZDateTime tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'expiry_alerts',
      'Peringatan Kedaluwarsa Kosmetik',
      channelDescription: 'Notifikasi peringatan kosmetik di pouch yang mendekati kedaluwarsa PAO.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  // Menghitung dan menjadwalkan ulang notifikasi kedaluwarsa untuk semua kosmetik di Pouch
  static Future<void> scheduleAllPouchNotifications() async {
    try {
      // Hapus seluruh jadwal notifikasi yang lama untuk menghindari duplikasi
      await cancelAllNotifications();

      final isar = DatabaseService().isar;
      final items = await isar.pouchItems.where().findAll();
      final now = DateTime.now();

      for (final item in items) {
        final expirationDate = item.openedDate.add(Duration(days: item.paoMonths * 30));
        // Kirim pengingat tepat 7 hari sebelum masa PAO habis
        final notificationDate = expirationDate.subtract(const Duration(days: 7));

        if (notificationDate.isAfter(now)) {
          final id = item.id;
          final title = '🚨 Kedaluwarsa PAO: ${item.productName}';
          final body = 'Kosmetik ${item.brand} (${item.shadeName}) di Pouch Anda akan kedaluwarsa dalam 7 hari lagi. Jaga kesehatan kulit Anda! ✨';

          await scheduleExpiryNotification(
            id: id,
            title: title,
            body: body,
            scheduledDate: notificationDate,
          );
        }
      }
    } catch (_) {
      // Menghindari crash saat penulisan database atau runtime luring
    }
  }
}
