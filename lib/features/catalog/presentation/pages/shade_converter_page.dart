import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../../../core/theme/theme_manager.dart';
import '../../../../core/utils/color_calculator.dart';
import '../../domain/repositories/shade_matcher_repository.dart';
import '../../../../core/network/database_service.dart';
import '../../../../features/premium_subscription/data/models/app_settings.dart';

class ShadeConverterPage extends StatefulWidget {
  final ShadeMatcherRepository repository;

  const ShadeConverterPage({
    super.key,
    required this.repository,
  });

  @override
  State<ShadeConverterPage> createState() => _ShadeConverterPageState();
}

class _ShadeConverterPageState extends State<ShadeConverterPage> {
  bool _isLoading = true;
  bool _isPremium = false;
  List<ProductShade> _allShades = [];

  // Dropdown States
  String? _selectedSourceBrand;
  String? _selectedSourceProduct;
  ProductShade? _selectedSourceShade;
  String? _selectedTargetBrand;

  // Filtered Lists
  List<String> _sourceBrands = [];
  List<String> _sourceProducts = [];
  List<ProductShade> _sourceShades = [];
  List<String> _targetBrands = [];

  // Match Results
  List<Map<String, dynamic>> _matches = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final shades = await widget.repository.getAllProductShades();
      
      String? matchedBrand;
      String? matchedProduct;
      List<String> sourceProds = [];
      List<ProductShade> sourceSds = [];
      ProductShade? matchedShade;

      bool isPremium = false;
      try {
        final isar = DatabaseService().isar;
        final settings = await isar.appSettings.get(0);
        if (settings != null) {
          isPremium = settings.isPremium;
          if (settings.lastMatchedShadeName != null) {
            final lastShadeName = settings.lastMatchedShadeName!;
          ProductShade? found;
          try {
            found = shades.firstWhere(
              (s) => s.shadeName.toLowerCase().trim() == lastShadeName.toLowerCase().trim()
            );
          } catch (_) {
            try {
              found = shades.firstWhere(
                (s) => s.shadeName.toLowerCase().contains(lastShadeName.toLowerCase()) ||
                       lastShadeName.toLowerCase().contains(s.shadeName.toLowerCase())
              );
            } catch (_) {}
          }
          if (found != null) {
            matchedBrand = found.brand;
            sourceProds = shades
                .where((s) => s.brand == found!.brand)
                .map((s) => s.productName)
                .toSet()
                .toList()
              ..sort();
            matchedProduct = found.productName;
            sourceSds = shades
                .where((s) => s.brand == found!.brand && s.productName == found.productName)
                .toList();
            matchedShade = found;
            debugPrint("SHADE_CONVERTER: Auto-selected scanned shade: ${found.shadeName}");
          }
        }
      }
      } catch (e) {
        debugPrint("Error loading AppSettings in ShadeConverterPage: $e");
      }

      setState(() {
        _isPremium = isPremium;
        _allShades = shades;
        _sourceBrands = shades.map((s) => s.brand).toSet().toList()...sort();
        _targetBrands = shades.map((s) => s.brand).toSet().toList()...sort();
        
        if (matchedBrand != null) {
          _selectedSourceBrand = matchedBrand;
          _sourceProducts = sourceProds;
          _selectedSourceProduct = matchedProduct;
          _sourceShades = sourceSds;
          _selectedSourceShade = matchedShade;
        }

        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSourceBrandChanged(String? brand) {
    setState(() {
      _selectedSourceBrand = brand;
      _selectedSourceProduct = null;
      _selectedSourceShade = null;
      _matches.clear();

      if (brand != null) {
        _sourceProducts = _allShades
            .where((s) => s.brand == brand)
            .map((s) => s.productName)
            .toSet()
            .toList()
          ..sort();
      } else {
        _sourceProducts = [];
      }
      _sourceShades = [];
    });
  }

  void _onSourceProductChanged(String? product) {
    setState(() {
      _selectedSourceProduct = product;
      _selectedSourceShade = null;
      _matches.clear();

      if (product != null && _selectedSourceBrand != null) {
        _sourceShades = _allShades
            .where((s) => s.brand == _selectedSourceBrand && s.productName == product)
            .toList()
          ..sort((a, b) => a.shadeName.compareTo(b.shadeName));
      } else {
        _sourceShades = [];
      }
    });
  }

  void _onSourceShadeChanged(ProductShade? shade) {
    setState(() {
      _selectedSourceShade = shade;
      _calculateMatches();
    });
  }

  void _onTargetBrandChanged(String? brand) {
    setState(() {
      _selectedTargetBrand = brand;
      _calculateMatches();
    });
  }

  void _calculateMatches() {
    if (_selectedSourceShade == null) {
      setState(() {
        _matches = [];
      });
      return;
    }

    final sourceLab = LabColor(
      _selectedSourceShade!.l,
      _selectedSourceShade!.a,
      _selectedSourceShade!.b,
    );

    final List<Map<String, dynamic>> results = [];

    final candidates = _allShades.where((s) {
      if (s.id == _selectedSourceShade!.id) return false;
      if (s.category != _selectedSourceShade!.category) return false;

      if (_selectedTargetBrand != null && _selectedTargetBrand!.isNotEmpty) {
        return s.brand == _selectedTargetBrand;
      }
      
      return s.brand != _selectedSourceBrand;
    }).toList();

    for (final candidate in candidates) {
      final candidateLab = LabColor(candidate.l, candidate.a, candidate.b);
      final double deltaE = ColorCalculator.deltaE00(sourceLab, candidateLab);
      
      if (deltaE <= 8.0) {
        final double matchPercentage = ColorCalculator.calculateMatchPercentage(deltaE);
        results.add({
          'product': candidate,
          'deltaE': deltaE,
          'matchPercentage': matchPercentage,
        });
      }
    }

    results.sort((a, b) => (a['deltaE'] as double).compareTo(b['deltaE'] as double));

    setState(() {
      _matches = results;
    });
  }

  Color _getMatchPercentageColor(double percentage) {
    if (percentage >= 90) return const Color(0xFF4CAF50);
    if (percentage >= 75) return const Color(0xFFFF9800);
    return const Color(0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeManager.isDark;
    final textColor = ThemeManager.textColor;
    final textMutedColor = ThemeManager.textMutedColor;
    final primaryColor = ThemeManager.primaryColor;

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
            'Shade Converter',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form Card Input
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ThemeManager.cardBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ThemeManager.cardBorderColor.withOpacity(0.55),
                          width: 1.5,
                        ),
                        boxShadow: ThemeManager.premiumGlowShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Shade Anda Saat Ini',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          _buildDropdownLabel('Merek Asal'),
                          _buildDropdown<String>(
                            value: _selectedSourceBrand,
                            items: _sourceBrands,
                            hint: 'Pilih Merek Asal',
                            onChanged: _onSourceBrandChanged,
                          ),
                          const SizedBox(height: 16),
  
                          _buildDropdownLabel('Nama Produk'),
                          _buildDropdown<String>(
                            value: _selectedSourceProduct,
                            items: _sourceProducts,
                            hint: _selectedSourceBrand == null
                                ? 'Pilih Merek Asal Terlebih Dahulu'
                                : 'Pilih Produk',
                            onChanged: _selectedSourceBrand == null ? null : _onSourceProductChanged,
                          ),
                          const SizedBox(height: 16),
  
                          _buildDropdownLabel('Warna Shade Asal'),
                          DropdownButtonFormField<ProductShade>(
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            value: _selectedSourceShade,
                            decoration: _getDropdownDecoration(
                              _selectedSourceProduct == null
                                  ? 'Pilih Produk Terlebih Dahulu'
                                  : 'Pilih Shade',
                            ),
                            style: TextStyle(color: textColor, fontSize: 13),
                            items: _sourceShades.map((shade) {
                              return DropdownMenuItem<ProductShade>(
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
                                    Text(
                                      shade.shadeName,
                                      style: TextStyle(color: textColor),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: _selectedSourceProduct == null ? null : _onSourceShadeChanged,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
  
                    // Target Brand Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ThemeManager.cardBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ThemeManager.cardBorderColor.withOpacity(0.55),
                          width: 1.5,
                        ),
                        boxShadow: ThemeManager.premiumGlowShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cari Padanan di Merek Lain (Target)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFBF953F) : const Color(0xFFC89E88),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDropdownLabel('Merek Target (Opsional)'),
                          _buildDropdown<String>(
                            value: _selectedTargetBrand,
                            items: _targetBrands,
                            hint: 'Cari di Semua Merek Lain',
                            onChanged: _onTargetBrandChanged,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
  
                    // Results Section
                    if (_selectedSourceShade != null) ...[
                      Text(
                        'Rekomendasi Shade Padanan (CIEDE2000):',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_matches.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'Tidak ditemukan shade yang cocok dalam toleransi.',
                              style: TextStyle(color: textMutedColor, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _isPremium ? _matches.length : (_matches.length > 1 ? 2 : _matches.length),
                          itemBuilder: (context, index) {
                            if (!_isPremium && index == 1) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: ThemeManager.cardBgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: ThemeManager.primaryColor.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: ThemeManager.premiumGlowShadow,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.lock_rounded, color: ThemeManager.primaryColor, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_matches.length - 1}+ Shade Alternatif Terkunci',
                                          style: TextStyle(
                                            color: ThemeManager.textColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Upgrade ke Premium untuk membuka semua konversi shade alternatif terdekat.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: ThemeManager.textMutedColor,
                                        fontSize: 10.5,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: ThemeManager.primaryColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        onPressed: _showPremiumUnlockDialog,
                                        child: const Text(
                                          'Buka Semua Shade (Premium)',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final match = _matches[index];
                            final ProductShade product = match['product'] as ProductShade;
                            final double dE = match['deltaE'] as double;
                            final double pct = match['matchPercentage'] as double;
  
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: ThemeManager.cardBgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: ThemeManager.cardBorderColor.withOpacity(0.55),
                                  width: 1.5,
                                ),
                                boxShadow: ThemeManager.premiumGlowShadow,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    height: 38,
                                    width: 38,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(int.parse('FF${product.hexCode.replaceAll('#', '')}', radix: 16)),
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.brand,
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          product.productName,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          'Shade: ${product.shadeName}',
                                          style: TextStyle(
                                            color: textMutedColor,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Jarak Warna (Delta E): ${dE.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: textMutedColor.withOpacity(0.7),
                                            fontSize: 9.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getHighlightBgColor(pct),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${pct.toStringAsFixed(1)}% Cocok',
                                          style: TextStyle(
                                            color: _getMatchPercentageColor(pct),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (product.affiliateUrl.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Membuka toko online untuk ${product.shadeName}...'),
                                                backgroundColor: primaryColor,
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [primaryColor, isDark ? const Color(0xFFAA771C) : const Color(0xFFC89E88)],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Beli',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Color _getHighlightBgColor(double pct) {
    if (pct >= 90) return const Color(0xFF4CAF50).withOpacity(0.12);
    if (pct >= 75) return const Color(0xFFFF9800).withOpacity(0.12);
    return const Color(0xFFE53935).withOpacity(0.12);
  }

  Widget _buildDropdownLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: TextStyle(
          color: ThemeManager.textMutedColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String hint,
    required void Function(T?)? onChanged,
  }) {
    final isDark = ThemeManager.isDark;
    return DropdownButtonFormField<T>(
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      value: value,
      decoration: _getDropdownDecoration(hint),
      style: TextStyle(color: ThemeManager.textColor, fontSize: 13),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            item.toString(),
            style: TextStyle(color: ThemeManager.textColor),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _getDropdownDecoration(String hint) {
    final isDark = ThemeManager.isDark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: ThemeManager.textMutedColor.withOpacity(0.5), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFCF9F6),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFF2ECE7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ThemeManager.primaryColor),
      ),
    );
  }

  Future<void> _activatePremium() async {
    final isar = DatabaseService().isar;
    await isar.writeTxn(() async {
      final settings = await isar.appSettings.get(0) ?? (AppSettings()..id = 0..isPremium = false);
      settings.isPremium = true;
      await isar.appSettings.put(settings);
    });

    setState(() {
      _isPremium = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Selamat! Fitur Premium Berhasil Diaktifkan.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showPremiumUnlockDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = ThemeManager.isDark;
        final textColor = ThemeManager.textColor;
        final textMutedColor = ThemeManager.textMutedColor;
        final primaryColor = ThemeManager.primaryColor;
        final cardBgColor = ThemeManager.cardBgColor;
        final cardBorderColor = ThemeManager.cardBorderColor;
        return AlertDialog(
          backgroundColor: cardBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: cardBorderColor, width: 1.5),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, color: primaryColor, size: 48),
              const SizedBox(height: 12),
              Text(
                'Buka Fitur Premium',
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            'Nikmati fitur premium tanpa batasan harian, buka semua opsi shade alternatif terdekat, hilangkan watermark, dan akses AR Makeup Contour Guide!',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMutedColor, fontSize: 13, height: 1.5),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _activatePremium();
              },
              child: const Text('Aktifkan Premium Permanen', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
