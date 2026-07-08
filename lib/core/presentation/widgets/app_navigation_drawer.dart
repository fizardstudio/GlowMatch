import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../features/scanner/presentation/pages/scanner_page.dart';
import '../../../../features/catalog/presentation/pages/shade_converter_page.dart';
import '../../../../features/catalog/data/repositories/shade_matcher_repository_impl.dart';
import '../../network/database_service.dart';
import '../../../../features/pouch/presentation/pages/makeup_pouch_page.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        children: [
          // Efek blur glassmorphism di latar belakang drawer
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1A).withOpacity(0.85),
                  border: const Border(
                    right: BorderSide(
                      color: Color(0x20E5C185), // Soft gold border
                      width: 1,
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE5C185), Color(0xFFC29047)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE5C185).withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.face_retouching_natural,
                              color: Color(0xFF0F0F1A),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GlowMatch',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                'AI Skin Tone Analyst',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFE5C185),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 1,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0x80E5C185), Color(0x00E5C185)],
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
                    ],
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'v1.1.0 • Edisi Premium',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.3),
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
    return Container(
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE5C185).withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: const Color(0xFFE5C185).withOpacity(0.25))
            : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? const Color(0xFFE5C185) : Colors.white70,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xFFE5C185) : Colors.white.withOpacity(0.8),
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
