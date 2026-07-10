import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../network/database_service.dart';
import '../../features/pouch/data/models/pouch_item.dart';
import '../../features/premium_subscription/data/models/app_settings.dart';

class WidgetHelper {
  static const _channel = MethodChannel('com.fizardstudio.glowmatch/widget');

  static Future<void> updateExpiryWidget() async {
    try {
      final isar = DatabaseService().isar;
      final settings = await isar.appSettings.get(0);
      final isPremium = settings?.isPremium ?? false;

      String productName = 'Semua produk aman ✨';
      String status = 'Pouch kosmetik kosong.';

      if (!isPremium) {
        productName = '👑 Expiry Alert Widget';
        status = 'Aktifkan Premium di aplikasi GlowMatch';
      } else {
        final items = await isar.pouchItems.where().findAll();
        if (items.isNotEmpty) {
          final now = DateTime.now();
          PouchItem? closestItem;
          int? minDaysLeft;

          for (final item in items) {
            final expirationDate = item.openedDate.add(Duration(days: item.paoMonths * 30));
            final daysLeft = expirationDate.difference(now).inDays;
            if (minDaysLeft == null || daysLeft < minDaysLeft) {
              minDaysLeft = daysLeft;
              closestItem = item;
            }
          }

          if (closestItem != null && minDaysLeft != null) {
            if (minDaysLeft <= 0) {
              productName = '🚨 ${closestItem.productName}';
              status = 'SUDAH KEDALUWARSA! Segera ganti.';
            } else {
              productName = closestItem.productName;
              final expirationDate = closestItem.openedDate.add(Duration(days: closestItem.paoMonths * 30));
              status = 'Sisa $minDaysLeft hari (${expirationDate.day}/${expirationDate.month}/${expirationDate.year})';
            }
          }
        }
      }

      await _channel.invokeMethod('updateWidgetData', {
        'productName': productName,
        'status': status,
      });
    } catch (_) {
      // Menghindari crash jika berjalan di platform non-Android
    }
  }
}
