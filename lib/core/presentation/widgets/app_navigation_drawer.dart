import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../features/scanner/presentation/pages/scanner_page.dart';
import '../../../../features/catalog/presentation/pages/shade_converter_page.dart';
import '../../../../features/catalog/data/repositories/shade_matcher_repository_impl.dart';
import '../../network/database_service.dart';
import '../../../../features/pouch/presentation/pages/makeup_pouch_page.dart';
import '../../../../features/premium_subscription/presentation/pages/ar_try_on_page.dart';
import '../../../../features/color_mixer/presentation/pages/color_mixer_page.dart';
import '../../../../features/premium_subscription/presentation/pages/photo_try_on_page.dart';
import '../../../../features/premium_subscription/presentation/pages/makeup_detector_page.dart';
import '../../../../features/home/presentation/pages/home_page.dart';
import '../../theme/theme_manager.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeManager.isDark;
    final primaryColor = ThemeManager.primaryColor;
    final textColor = ThemeManager.textColor;
    final textMutedColor = ThemeManager.textMutedColor;

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        children: [
          // Efek blur glassmorphism di latar belakang drawer adaptif
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withOpacity(0.92)
                      : const Color(0xFFFFF2EF).withOpacity(0.92),
                  border: Border(
                    right: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : const Color(0xFFF2ECE7),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Drawer Premium
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: isDark
                                  ? const LinearGradient(
                                      colors: [Color(0xFFBF953F), Color(0xFFAA771C)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFFE57E70), Color(0xFFC89E88)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.face_retouching_natural,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GlowMatch',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                'AI Skin Tone Analyst',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFFBF953F) : const Color(0xFFC89E88),
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, Colors.transparent],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Menu Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.dashboard_outlined,
                        title: 'Dashboard Home',
                        isActive: context.widget is HomePage,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          if (context.widget is! HomePage) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const HomePage()),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.camera_enhance_outlined,
                        title: 'AI Face Scanner',
                        isActive: context.widget is ScannerPage,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          if (context.widget is! ScannerPage) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const ScannerPage()),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.swap_horiz_rounded,
                        title: 'Shade Converter',
                        isActive: context.widget is ShadeConverterPage,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          if (context.widget is! ShadeConverterPage) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShadeConverterPage(
                                  repository: ShadeMatcherRepositoryImpl(DatabaseService()),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.storefront_outlined,
                        title: 'Virtual Makeup Pouch',
                        isActive: context.widget is MakeupPouchPage,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          if (context.widget is! MakeupPouchPage) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MakeupPouchPage(),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.science_outlined,
                        title: 'Advanced Color Mixer (Premium)',
                        isActive: context.widget is ColorMixerPage,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          if (context.widget is! ColorMixerPage) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ColorMixerPage(),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.face_retouching_natural_rounded,
                        title: 'AR Lip Try-On (Premium)',
                        isActive: context.widget is ArTryOnPage,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          if (context.widget is! ArTryOnPage) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ArTryOnPage(),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.photo_size_select_large_rounded,
                        title: 'Uji Riasan 2D (Foto)',
                        isActive: context.widget is PhotoTryOnPage,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          if (context.widget is! PhotoTryOnPage) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PhotoTryOnPage(),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.camera_enhance_outlined,
                        title: 'AI Makeup Detector (Premium)',
                        isActive: context.widget is MakeupDetectorPage,
                        onTap: () {
                          Navigator.pop(context); // Tutup drawer
                          if (context.widget is! MakeupDetectorPage) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MakeupDetectorPage(),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                // Footer Edisi Tema Dinamis
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'v1.2.0 • ${isDark ? "Midnight Steel" : "Ruby Peach"} Edition',
                      style: TextStyle(
                        fontSize: 10,
                        color: textMutedColor.withOpacity(0.55),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final primaryColor = ThemeManager.primaryColor;
    final textColor = ThemeManager.textColor;

    return Container(
      decoration: BoxDecoration(
        color: isActive ? primaryColor.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: primaryColor.withOpacity(0.25))
            : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? primaryColor : textColor.withOpacity(0.6),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? primaryColor : textColor.withOpacity(0.8),
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            letterSpacing: 0.5,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: onTap,
      ),
    );
  }
}
