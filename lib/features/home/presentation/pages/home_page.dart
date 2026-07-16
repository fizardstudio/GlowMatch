import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../../../core/theme/theme_manager.dart';
import '../../../scanner/presentation/pages/scanner_page.dart';
import '../../../catalog/presentation/pages/shade_converter_page.dart';
import '../../../catalog/data/repositories/shade_matcher_repository_impl.dart';
import '../../../pouch/presentation/pages/makeup_pouch_page.dart';
import '../../../pouch/data/models/pouch_item.dart';
import '../../../../features/premium_subscription/presentation/pages/ar_try_on_page.dart';
import '../../../../features/premium_subscription/presentation/pages/photo_try_on_page.dart';
import '../../../../features/premium_subscription/presentation/pages/makeup_detector_page.dart';
import '../../../../features/color_mixer/presentation/pages/color_mixer_page.dart';
import '../../../../features/premium_subscription/presentation/pages/skincare_scanner_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Isar _isar = DatabaseService().isar;
  int _totalPouchItems = 0;
  int _expiredPouchItems = 0;

  @override
  void initState() {
    super.initState();
    _fetchPouchSummary();
  }

  Future<void> _fetchPouchSummary() async {
    try {
      final items = await _isar.pouchItems.where().findAll();
      final now = DateTime.now();
      int expiredCount = 0;
      for (final item in items) {
        final expirationDate = item.openedDate.add(Duration(days: item.paoMonths * 30));
        if (expirationDate.isBefore(now)) {
          expiredCount++;
        }
      }
      if (mounted) {
        setState(() {
          _totalPouchItems = items.length;
          _expiredPouchItems = expiredCount;
        });
      }
    } catch (_) {}
  }

@override
  Widget build(BuildContext context) {
    final isDark = ThemeManager.isDark;
    final textColor = ThemeManager.textColor;
    final textMutedColor = ThemeManager.textMutedColor;

    return Container(
      decoration: BoxDecoration(
        gradient: ThemeManager.pageGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: const AppNavigationDrawer(),
        appBar: AppBar(
          systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          title: Text(
            'GlowMatch Dashboard',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          actions: [
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: textColor,
              ),
              onPressed: () {
                setState(() {
                  ThemeManager.toggleTheme();
                });
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Welcome Header
                Text(
                  isDark ? 'Hi, Champ! ⚡' : 'Hi, Gorgeous! ✨',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Temukan kecocokan kosmetik ideal untuk rona kulitmu hari ini secara luring.',
                  style: TextStyle(
                    fontSize: 13,
                    color: textMutedColor,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Core Feature: AI Face Scanner Hero Card
                _buildHeroCard(
                  title: 'AI Face Scanner 📸',
                  subtitle: 'Pindai wajah secara real-time untuk mendeteksi kecerahan kulit, undertone, dan katalog shade terdekat.',
                  buttonText: 'Mulai Pindai Sekarang',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScannerPage()),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 3. Virtual Pouch Live Status Banner
                _buildPouchStatusCard(),
                const SizedBox(height: 28),

                // 4. Features Grid
                Text(
                  'Menu Riasan & Analisis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.15,
                  children: [
                    _buildMenuCard(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Shade Converter',
                      subtitle: 'Padanan kosmetik antar merek.',
                      color: const Color(0xFFFBF4F1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShadeConverterPage(
                              repository: ShadeMatcherRepositoryImpl(DatabaseService()),
                            ),
                          ),
                        );
                      },
                    ),
                    _buildMenuCard(
                      icon: Icons.face_retouching_natural_rounded,
                      title: 'AR Try-On',
                      subtitle: 'Uji riasan bibir & pipi secara live.',
                      color: const Color(0xFFFBF4F1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ArTryOnPage()),
                        );
                      },
                    ),
                    _buildMenuCard(
                      icon: Icons.photo_size_select_large_rounded,
                      title: 'Uji Riasan 2D',
                      subtitle: 'Eksperimen riasan di foto statis.',
                      color: const Color(0xFFFBF4F1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PhotoTryOnPage()),
                        );
                      },
                    ),
                    _buildMenuCard(
                      icon: Icons.camera_enhance_outlined,
                      title: 'AI Makeup Detector',
                      subtitle: 'Pindai makeup dari foto & galeri.',
                      color: const Color(0xFFFBF4F1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MakeupDetectorPage()),
                        );
                      },
                    ),
                    _buildMenuCard(
                      icon: Icons.science_outlined,
                      title: 'Color Mixer',
                      subtitle: 'Simulator adukan kosmetik cair.',
                      color: const Color(0xFFFBF4F1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ColorMixerPage()),
                        );
                      },
                    ),
                    _buildMenuCard(
                      icon: Icons.storefront_outlined,
                      title: 'Virtual Pouch',
                      subtitle: 'Pantau PAO & kadaluwarsa.',
                      color: const Color(0xFFFBF4F1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MakeupPouchPage()),
                        );
                      },
                    ),
                    _buildMenuCard(
                      icon: Icons.document_scanner_outlined,
                      title: 'Skincare Scanner',
                      subtitle: 'Pindai kandungan aktif skincare.',
                      color: const Color(0xFFFBF4F1),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SkincareScannerPage()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    final isDark = ThemeManager.isDark;
    final primaryColor = ThemeManager.primaryColor;

    final cardGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFFBF953F), Color(0xFFAA771C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFE57E70), Color(0xFFE5A99E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final shadowColor = isDark
        ? const Color(0xFFBF953F)
        : const Color(0xFFE57E70);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ThemeManager.goldBorderColor.withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(isDark ? 0.25 : 0.38),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: shadowColor.withOpacity(isDark ? 0.18 : 0.28),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF4A3431),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: onPressed,
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPouchStatusCard() {
    final isDark = ThemeManager.isDark;
    final textColor = ThemeManager.textColor;
    final textMutedColor = ThemeManager.textMutedColor;
    final primaryColor = ThemeManager.primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ThemeManager.goldBorderColor.withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: ThemeManager.premiumGlowShadow,
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MakeupPouchPage()),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _expiredPouchItems > 0
                    ? const Color(0xFFE53935).withOpacity(0.1)
                    : primaryColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _expiredPouchItems > 0 ? Icons.error_outline_rounded : Icons.storefront_outlined,
                color: _expiredPouchItems > 0 ? const Color(0xFFE53935) : primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Virtual Pouch',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _totalPouchItems == 0
                        ? 'Belum ada produk di pouch-mu.'
                        : _expiredPouchItems > 0
                            ? '🚨 $_expiredPouchItems produk kedaluwarsa dari $_totalPouchItems total!'
                            : 'Semua $_totalPouchItems produk kosmetik aman & segar ✨',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _expiredPouchItems > 0 ? const Color(0xFFE53935) : textMutedColor,
                      fontWeight: _expiredPouchItems > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? const Color(0xFFBF953F) : const Color(0xFFC89E88)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = ThemeManager.isDark;
    final textColor = ThemeManager.textColor;
    final textMutedColor = ThemeManager.textMutedColor;
    final primaryColor = ThemeManager.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ThemeManager.goldBorderColor.withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: ThemeManager.premiumGlowShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: primaryColor, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: textMutedColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}