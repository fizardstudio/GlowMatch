import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/product_shade.dart';
import '../../features/pouch/data/models/pouch_item.dart';

class SupabaseSyncService {
  /// Memeriksa apakah klien Supabase telah diinisialisasi
  static bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sinkronisasi katalog kosmetik Supabase ke Isar DB luring
  static Future<void> syncCatalog(Isar isar) async {
    if (!isInitialized) {
      debugPrint("SUPABASE_SYNC: Supabase tidak diinisialisasi. Lewati sinkronisasi.");
      return;
    }

    try {
      debugPrint("SUPABASE_SYNC: Memulai sinkronisasi katalog kosmetik dari cloud...");

      // Mengambil data shade dengan join table ke products dan brands
      final List<dynamic> response = await Supabase.instance.client
          .from('product_shades')
          .select('*, products(*, brands(*))');

      if (response.isEmpty) {
        debugPrint("SUPABASE_SYNC: Katalog cloud kosong.");
        return;
      }

      final List<ProductShade> shadesToPut = [];

      for (var item in response) {
        final product = item['products'];
        final brand = product != null ? product['brands'] : null;

        final String brandName = brand != null ? (brand['name'] ?? 'Unknown') : 'Unknown';
        final String productName = product != null ? (product['name'] ?? 'Unknown') : 'Unknown';
        final String category = product != null ? (product['category'] ?? 'Foundation') : 'Foundation';

        final String shadeName = item['name'] ?? 'Unknown';
        final String hexCode = item['hex_code'] ?? '#FFFFFF';
        final double l = (item['lab_l'] as num?)?.toDouble() ?? 100.0;
        final double a = (item['lab_a'] as num?)?.toDouble() ?? 0.0;
        final double b = (item['lab_b'] as num?)?.toDouble() ?? 0.0;
        final double deltaLOffset = (item['delta_l_offset'] as num?)?.toDouble() ?? 0.0;
        final String affiliateUrl = item['affiliate_url'] ?? '';

        // Cari apakah shade sudah ada di Isar luring
        final existing = await isar.productShades
            .filter()
            .brandEqualTo(brandName)
            .and()
            .productNameEqualTo(productName)
            .and()
            .shadeNameEqualTo(shadeName)
            .findFirst();

        final ProductShade shade = existing ?? ProductShade();
        shade.brand = brandName;
        shade.productName = productName;
        shade.shadeName = shadeName;
        shade.hexCode = hexCode;
        shade.l = l;
        shade.a = a;
        shade.b = b;
        shade.category = category;
        shade.affiliateUrl = affiliateUrl;
        shade.deltaLOffset = deltaLOffset;

        shadesToPut.add(shade);
      }

      // Tulis batch transaksi ke Isar DB
      await isar.writeTxn(() async {
        await isar.productShades.putAll(shadesToPut);
      });

      debugPrint("SUPABASE_SYNC: Berhasil mensinkronkan ${shadesToPut.length} shade kosmetik dari Supabase.");
    } catch (e) {
      debugPrint("SUPABASE_SYNC_ERROR: Gagal sinkronisasi katalog: $e");
    }
  }

  /// Mengunggah ulasan pouch luring yang belum tersinkronisasi ke cloud
  static Future<void> syncOfflineReviews(Isar isar) async {
    if (!isInitialized) return;

    try {
      // Ambil pouch yang ulasannya belum sinkron dan memiliki nilai ulasan
      final unsyncedItems = await isar.pouchItems
          .filter()
          .isReviewSyncedEqualTo(false)
          .and()
          .feedbackScoreIsNotNull()
          .findAll();

      if (unsyncedItems.isEmpty) return;

      debugPrint("SUPABASE_SYNC: Menemukan ${unsyncedItems.length} ulasan luring untuk disinkronkan...");

      for (var item in unsyncedItems) {
        // Cari ID shade di Supabase berdasarkan Nama Brand, Produk, dan Shade
        final shadeRes = await Supabase.instance.client
            .from('product_shades')
            .select('id, products!inner(name, brands!inner(name))')
            .eq('name', item.shadeName)
            .eq('products.name', item.productName)
            .eq('products.brands.name', item.brand)
            .maybeSingle();

        if (shadeRes != null && shadeRes['id'] != null) {
          final int shadeId = shadeRes['id'];

          // Masukkan ulasan ke Supabase
          await Supabase.instance.client.from('community_reviews').insert({
            'shade_id': shadeId,
            'feedback_score': item.feedbackScore,
          });

          // Tandai sebagai tersinkron di Isar lokal
          await isar.writeTxn(() async {
            item.isReviewSynced = true;
            await isar.pouchItems.put(item);
          });

          debugPrint("SUPABASE_SYNC: Berhasil mensinkronkan ulasan shade '${item.shadeName}' (${item.feedbackScore}).");
        } else {
          debugPrint("SUPABASE_SYNC_WARN: Shade '${item.shadeName}' dari brand '${item.brand}' tidak ditemukan di cloud database.");
        }
      }
    } catch (e) {
      debugPrint("SUPABASE_SYNC_ERROR: Gagal mensinkronkan ulasan luring: $e");
    }
  }
}
