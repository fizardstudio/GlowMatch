import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum AppThemeType { feminine, masculine }

class ThemeManager {
  static final ValueNotifier<AppThemeType> themeNotifier =
      ValueNotifier<AppThemeType>(AppThemeType.feminine);

  static AppThemeType get currentTheme => themeNotifier.value;
  static bool _isInitialized = false;

  /// Membaca konfigurasi tema tersimpan dari penyimpanan lokal.
  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/theme_config.txt');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim() == 'masculine') {
          themeNotifier.value = AppThemeType.masculine;
        } else {
          themeNotifier.value = AppThemeType.feminine;
        }
      }
    } catch (_) {
      // Fallback ke default (feminine) jika gagal
    }
    _isInitialized = true;
  }

  /// Menyimpan dan memperbarui konfigurasi tema secara asinkron.
  static Future<void> _saveTheme(AppThemeType theme) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/theme_config.txt');
      await file.writeAsString(theme == AppThemeType.masculine ? 'masculine' : 'feminine');
    } catch (_) {}
  }

  static void toggleTheme() {
    final nextTheme = themeNotifier.value == AppThemeType.feminine
        ? AppThemeType.masculine
        : AppThemeType.feminine;
    themeNotifier.value = nextTheme;
    _saveTheme(nextTheme);
  }

  static void setTheme(AppThemeType theme) {
    themeNotifier.value = theme;
    _saveTheme(theme);
  }

  // Warna khusus untuk Tema Feminim (Rose Gold / Ruby Peach yang lebih kaya dan merah)
  static const Color femPrimary = Color(0xFFE57E70); // Peach kemerahan yang segar
  static const Color femSecondary = Color(0xFFC89E88);
  static const Color femBgStart = Color(0xFFFFF2EF); // Putih rosy lembut
  static const Color femBgEnd = Color(0xFFFDE4DC);   // Peach-pink gradien
  static const Color femText = Color(0xFF4A3431);    // Cokelat-merah gelap (kontras tinggi)

  // Warna khusus untuk Tema Maskulin (Midnight Steel / Slate Navy)
  static const Color mascPrimary = Color(0xFFBF953F); // Emas metalik primer
  static const Color mascSecondary = Color(0xFF3B82F6); // Biru steel pendukung
  static const Color mascBgStart = Color(0xFF0F172A);  // Slate gelap 900
  static const Color mascBgEnd = Color(0xFF1E293B);    // Slate abu-gelap 800
  static const Color mascText = Color(0xFFF8FAFC);     // Off-white terang
  static const Color mascTextMuted = Color(0xFF94A3B8); // Slate terang 400

  // Apakah tema saat ini bertipe gelap (maskulin = gelap)
  static bool get isDark => currentTheme == AppThemeType.masculine;

  // Mendapatkan objek LinearGradient dinamis untuk background halaman
  static Gradient get pageGradient {
    if (currentTheme == AppThemeType.feminine) {
      return const LinearGradient(
        colors: [femBgStart, femBgEnd],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    } else {
      return const LinearGradient(
        colors: [mascBgStart, mascBgEnd],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }
  }

  // Mendapatkan warna background scaffold dinamis
  static Color get scaffoldBgColor {
    return isDark ? mascBgStart : femBgStart;
  }

  // Mendapatkan warna primer dinamis
  static Color get primaryColor {
    return isDark ? mascPrimary : femPrimary;
  }

  // Mendapatkan warna sekunder dinamis
  static Color get secondaryColor {
    return isDark ? mascSecondary : femSecondary;
  }

  // Mendapatkan warna teks utama dinamis
  static Color get textColor {
    return isDark ? mascText : femText;
  }

  // Mendapatkan warna teks redup dinamis
  static Color get textMutedColor {
    return isDark ? mascTextMuted : const Color(0xFF8E807E);
  }

  // Mendapatkan warna background card/sheet dinamis
  static Color get cardBgColor {
    return isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  }

  // Mendapatkan warna border card/sheet dinamis
  static Color get cardBorderColor {
    return isDark ? const Color(0xFFBF953F) : const Color(0xFFE57E70);
  }

  // Mendapatkan warna border emas premium dinamis (Emas di dark, Rose Coral di light)
  static Color get goldBorderColor {
    return isDark ? const Color(0xFFBF953F) : const Color(0xFFE57E70);
  }

  // Mendapatkan daftar BoxShadow premium dinamis (Pendaran tebal di mode siang/Feminim)
  static List<BoxShadow> get premiumGlowShadow {
    final shadowColor = isDark ? const Color(0xFFBF953F) : const Color(0xFFE57E70);
    return [
      BoxShadow(
        color: shadowColor.withOpacity(isDark ? 0.18 : 0.32),
        blurRadius: 12,
        spreadRadius: 1,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: shadowColor.withOpacity(isDark ? 0.12 : 0.22),
        blurRadius: 24,
        spreadRadius: 2,
        offset: const Offset(0, 8),
      ),
    ];
  }

  // Mendapatkan gradien emas/rose-gold dinamis untuk tombol utama (hero/capture)
  static Gradient get primaryGradient {
    if (currentTheme == AppThemeType.feminine) {
      return const LinearGradient(
        colors: [Color(0xFFE57E70), Color(0xFFE5A99E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return const LinearGradient(
        colors: [Color(0xFFBF953F), Color(0xFFAA771C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }
}
