import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:glowmatch/core/theme/theme_manager.dart';
import 'package:isar/isar.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/data/models/standard_shade.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../../../core/utils/color_calculator.dart';
import '../../../../core/utils/widget_helper.dart';
import '../../../premium_subscription/data/models/app_settings.dart';

class ColorMixerPage extends StatefulWidget {
  const ColorMixerPage({super.key});

  @override
  State<ColorMixerPage> createState() => _ColorMixerPageState();
}

class _ColorMixerPageState extends State<ColorMixerPage> {
  bool get isDark => ThemeManager.isDark;
  Color get textColor => ThemeManager.textColor;
  Color get textMutedColor => ThemeManager.textMutedColor;
  Color get cardBgColor => ThemeManager.cardBgColor;
  Color get cardBorderColor => ThemeManager.cardBorderColor;
  Color get primaryColor => ThemeManager.primaryColor;
  final Isar _isar = DatabaseService().isar;
  List<StandardShade> _shades = [];
  bool _isLoading = true;
  bool _isPremium = false;

  // State pencampuran
  StandardShade? _targetShade;
  StandardShade? _cosmetic1;
  StandardShade? _cosmetic2;

  Color _customColor1 = const Color(0xFFF5ECDE); // Default: Fair Warm
  Color _customColor2 = const Color(0xFFA27557); // Default: Tan Warm
  bool _useCustom1 = false;
  bool _useCustom2 = false;

  double _ratio = 0.5; // 0.0 sampai 1.0

  final List<Map<String, String>> _customPalette = [
    {'name': 'Cream', 'hex': '#FFFDD0'},
    {'name': 'Fair Warm', 'hex': '#F5ECDE'},
    {'name': 'Fair Cool', 'hex': '#FDF5F2'},
    {'name': 'Light Warm', 'hex': '#E6C5AC'},
    {'name': 'Light Neutral', 'hex': '#EED0BD'},
    {'name': 'Medium Neutral', 'hex': '#D4A286'},
    {'name': 'Medium Warm', 'hex': '#CBA37D'},
    {'name': 'Tan Warm', 'hex': '#A27557'},
    {'name': 'Tan Cool', 'hex': '#B2856E'},
    {'name': 'Deep Neutral', 'hex': '#734B3B'},
    {'name': 'Deep Warm', 'hex': '#694432'},
    {'name': 'Espresso', 'hex': '#4A2C2A'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final settings = await _isar.appSettings.get(0);
      if (settings != null && settings.isPremium) {
        setState(() {
          _isPremium = true;
        });
      }

      final shades = await _isar.standardShades.where().findAll();
      setState(() {
        _shades = shades;
        _isLoading = false;
        if (_shades.isNotEmpty) {
          _targetShade = _shades.firstWhere(
            (s) => s.name.toLowerCase().contains('medium neutral'),
            orElse: () => _shades.first,
          );
          _cosmetic1 = _shades.firstWhere(
            (s) => s.name.toLowerCase().contains('fair warm'),
            orElse: () => _shades.first,
          );
          _cosmetic2 = _shades.firstWhere(
            (s) => s.name.toLowerCase().contains('tan warm'),
            orElse: () => _shades.first,
          );
        }
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _activatePremium() async {
    final settings = AppSettings()
      ..id = 0
      ..isPremium = true;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });

    setState(() {
      _isPremium = true;
    });

    WidgetHelper.updateExpiryWidget();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Selamat! Fitur Premium Berhasil Diaktifkan.'),
          backgroundColor: primaryColor,
        ),
      );
    }
  }

  Color _getColorForCosmetic1() {
    if (_useCustom1) return _customColor1;
    if (_cosmetic1 != null) {
      final hex = _cosmetic1!.hexCode.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    }
    return Colors.white;
  }

  Color _getColorForCosmetic2() {
    if (_useCustom2) return _customColor2;
    if (_cosmetic2 != null) {
      final hex = _cosmetic2!.hexCode.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    }
    return Colors.white;
  }

  Color _mixColors(Color c1, Color c2, double ratio) {
    final r1L = ColorCalculator.sRgbToLinear(c1.red.toDouble());
    final g1L = ColorCalculator.sRgbToLinear(c1.green.toDouble());
    final b1L = ColorCalculator.sRgbToLinear(c1.blue.toDouble());

    final r2L = ColorCalculator.sRgbToLinear(c2.red.toDouble());
    final g2L = ColorCalculator.sRgbToLinear(c2.green.toDouble());
    final b2L = ColorCalculator.sRgbToLinear(c2.blue.toDouble());

    final rMixedL = r1L * ratio + r2L * (1.0 - ratio);
    final gMixedL = g1L * ratio + g2L * (1.0 - ratio);
    final bMixedL = b1L * ratio + b2L * (1.0 - ratio);

    final rMixed = ColorCalculator.linearToSrgb(rMixedL).round();
    final gMixed = ColorCalculator.linearToSrgb(gMixedL).round();
    final bMixed = ColorCalculator.linearToSrgb(bMixedL).round();

    return Color.fromARGB(255, rMixed, gMixed, bMixed);
  }

  Map<String, dynamic> _calculateMatch(Color mixed, StandardShade target) {
    final mixedLab = ColorCalculator.rgbToLab(mixed.red, mixed.green, mixed.blue);
    final targetLab = LabColor(target.l, target.a, target.b);
    final deltaE = ColorCalculator.deltaE00(mixedLab, targetLab);

    int matchPercent = (100 - (deltaE * 7)).round().clamp(0, 100);
    String label = 'Kurang Cocok ❌';
    Color badgeColor = Colors.redAccent;

    if (deltaE <= 1.5) {
      label = 'Perfect Match! 🌟';
      badgeColor = const Color(0xFFC89E88); // Elegant champagne gold
      matchPercent = (100 - (deltaE * 2)).round().clamp(95, 100);
    } else if (deltaE <= 3.0) {
      label = 'Sangat Cocok ✨';
      badgeColor = primaryColor; // Rose Gold
      matchPercent = (100 - (deltaE * 4)).round().clamp(85, 94);
    } else if (deltaE <= 5.5) {
      label = 'Cukup Cocok 👍';
      badgeColor = Colors.orangeAccent;
      matchPercent = (100 - (deltaE * 6)).round().clamp(65, 84);
    }

    return {
      'percent': matchPercent,
      'label': label,
      'color': badgeColor,
      'deltaE': deltaE
    };
  }

  void _showColorPickerDialog(bool isCosmetic1) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side:  BorderSide(color: cardBorderColor),
          ),
          title: Text(
            isCosmetic1 ? 'Warna Kustom Kosmetik 1' : 'Warna Kustom Kosmetik 2',
            style:  TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _customPalette.length,
              itemBuilder: (context, index) {
                final item = _customPalette[index];
                final hex = item['hex']!.replaceAll('#', '');
                final color = Color(int.parse('FF$hex', radix: 16));
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isCosmetic1) {
                        _customColor1 = color;
                        _useCustom1 = true;
                      } else {
                        _customColor2 = color;
                        _useCustom2 = true;
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBorderColor, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        item['name']!.substring(0, 1),
                        style: TextStyle(
                          color: color.computeLuminance() > 0.5 ? textColor : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:  Text('Batal', style: TextStyle(color: textMutedColor)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return  Scaffold(
        drawer: AppNavigationDrawer(),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );
    }

    final color1 = _getColorForCosmetic1();
    final color2 = _getColorForCosmetic2();
    final mixedColor = _mixColors(color1, color2, _ratio);
    final matchResult = _targetShade != null ? _calculateMatch(mixedColor, _targetShade!) : null;

    return Scaffold(
      backgroundColor: cardBgColor,
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title:  Text(
          'Advanced Color Mixer 🧪',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: cardBgColor,
        elevation: 0,
        iconTheme:  IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lakukan simulasi percampuran warna dari 2 kosmetik cair dengan rasio tetesan berbeda secara akurat menggunakan sains warna Linear RGB.',
                style: TextStyle(color: textMutedColor.withOpacity(0.8), fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 20),

              Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target Skin Tone Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ThemeManager.goldBorderColor.withOpacity(0.55), width: 1.5),
                          boxShadow: ThemeManager.premiumGlowShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WARNA KULIT TARGET 🎯',
                                  style: TextStyle(color: Color(0xFFC89E88), fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Sebagai referensi pencocokan',
                                  style: TextStyle(color: textMutedColor, fontSize: 10),
                                ),
                              ],
                            ),
                            DropdownButton<StandardShade>(
                              value: _targetShade,
                              dropdownColor: cardBgColor,
                              underline: const SizedBox(),
                              style:  TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                              onChanged: (shade) {
                                setState(() {
                                  _targetShade = shade;
                                });
                              },
                              items: _shades.map((shade) {
                                return DropdownMenuItem<StandardShade>(
                                  value: shade,
                                  child: Row(
                                    children: [
                                      Container(
                                        height: 12,
                                        width: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(int.parse('FF${shade.hexCode.replaceAll('#', '')}', radix: 16)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(shade.name),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Panel Kosmetik 1 & 2
                      Row(
                        children: [
                          // Kosmetik 1
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: ThemeManager.goldBorderColor.withOpacity(0.55), width: 1.5),
                                boxShadow: ThemeManager.premiumGlowShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                       Text(
                                        'KOSMETIK 1 🧪',
                                        style: TextStyle(color: textMutedColor, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                      InkWell(
                                        onTap: () => _showColorPickerDialog(true),
                                        child:  Icon(Icons.palette_outlined, color: primaryColor, size: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Container(
                                      height: 50,
                                      width: 50,
                                      decoration: BoxDecoration(
                                        color: color1,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: cardBorderColor, width: 2),
                                        boxShadow: [
                                          BoxShadow(color: color1.withOpacity(0.2), blurRadius: 8),
                                        ],
                                      ),
                                      child: _useCustom1
                                          ? const Icon(Icons.color_lens, size: 18, color: Colors.white54)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButton<StandardShade>(
                                    value: _useCustom1 ? null : _cosmetic1,
                                    hint:  Text('Kustom', style: TextStyle(color: textMutedColor, fontSize: 11)),
                                    isExpanded: true,
                                    dropdownColor: cardBgColor,
                                    underline: const SizedBox(),
                                    style:  TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.bold),
                                    onChanged: (shade) {
                                      setState(() {
                                        _cosmetic1 = shade;
                                        _useCustom1 = false;
                                      });
                                    },
                                    items: _shades.map((shade) {
                                      return DropdownMenuItem<StandardShade>(
                                        value: shade,
                                        child: Text(shade.name, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Kosmetik 2
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: ThemeManager.goldBorderColor.withOpacity(0.55), width: 1.5),
                                boxShadow: ThemeManager.premiumGlowShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                       Text(
                                        'KOSMETIK 2 🧪',
                                        style: TextStyle(color: textMutedColor, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                      InkWell(
                                        onTap: () => _showColorPickerDialog(false),
                                        child:  Icon(Icons.palette_outlined, color: primaryColor, size: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: Container(
                                      height: 50,
                                      width: 50,
                                      decoration: BoxDecoration(
                                        color: color2,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: cardBorderColor, width: 2),
                                        boxShadow: [
                                          BoxShadow(color: color2.withOpacity(0.2), blurRadius: 8),
                                        ],
                                      ),
                                      child: _useCustom2
                                          ? const Icon(Icons.color_lens, size: 18, color: Colors.white54)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButton<StandardShade>(
                                    value: _useCustom2 ? null : _cosmetic2,
                                    hint:  Text('Kustom', style: TextStyle(color: textMutedColor, fontSize: 11)),
                                    isExpanded: true,
                                    dropdownColor: cardBgColor,
                                    underline: const SizedBox(),
                                    style:  TextStyle(color: textColor, fontSize: 11.5, fontWeight: FontWeight.bold),
                                    onChanged: (shade) {
                                      setState(() {
                                        _cosmetic2 = shade;
                                        _useCustom2 = false;
                                      });
                                    },
                                    items: _shades.map((shade) {
                                      return DropdownMenuItem<StandardShade>(
                                        value: shade,
                                        child: Text(shade.name, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Slider Rasio
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: ThemeManager.goldBorderColor.withOpacity(0.55), width: 1.5),
                          boxShadow: ThemeManager.premiumGlowShadow,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Kosmetik 1 (${(_ratio * 100).round()}%)',
                                  style:  TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Kosmetik 2 (${((1.0 - _ratio) * 100).round()}%)',
                                  style:  TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: primaryColor,
                                inactiveTrackColor: cardBorderColor,
                                thumbColor: primaryColor,
                                overlayColor: primaryColor.withOpacity(0.2),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: _ratio,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (val) {
                                  setState(() {
                                    _ratio = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Hasil Campuran Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: ThemeManager.goldBorderColor.withOpacity(0.55), width: 1.5),
                          boxShadow: ThemeManager.premiumGlowShadow,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'WARNA HASIL CAMPURAN (LINEAR SPACE) 🧪',
                              style: TextStyle(
                                color: Color(0xFFC89E88),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              height: 90,
                              width: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: mixedColor,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: mixedColor.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '#${mixedColor.value.toRadixString(16).substring(2).toUpperCase()}',
                              style:  TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              width: 80,
                              color: cardBorderColor,
                            ),
                            const SizedBox(height: 16),

                            if (matchResult != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (matchResult['color'] as Color).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  matchResult['label'] as String,
                                  style: TextStyle(
                                    color: matchResult['color'] as Color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Indeks Kecocokan: ${matchResult['percent']}%',
                                style:  TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'CIEDE2000 Jarak (Delta E00): ${(matchResult['deltaE'] as double).toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: textMutedColor.withOpacity(0.6),
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Paywall Overlay
                  if (!_isPremium)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: cardBgColor.withOpacity(0.85),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                 Icon(Icons.lock_outline_rounded, color: primaryColor, size: 48),
                                const SizedBox(height: 16),
                                 Text(
                                  'Advanced Color Mixer 👑',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                  child: Text(
                                    'Simulasikan percampuran 2 shade kosmetik secara akurat di ruang warna linear untuk mencocokkannya ke warna kulit targetmu.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: textMutedColor.withOpacity(0.8), fontSize: 11.5, height: 1.4),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    elevation: 0,
                                  ),
                                  onPressed: _activatePremium,
                                  child: const Text('Buka Fitur Premium', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
