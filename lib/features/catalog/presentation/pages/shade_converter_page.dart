import 'package:flutter/material.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../../../core/utils/color_calculator.dart';
import '../../domain/repositories/shade_matcher_repository.dart';

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
      setState(() {
        _allShades = shades;
        _sourceBrands = shades.map((s) => s.brand).toSet().toList()..sort();
        _targetBrands = shades.map((s) => s.brand).toSet().toList()..sort();
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
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F6),
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text(
          'Shade Converter',
          style: TextStyle(
            color: Color(0xFF3E3635),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        backgroundColor: const Color(0xFFFCF9F6),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF3E3635)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5A99E)),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF2ECE7),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x055A4A45),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pilih Shade Anda Saat Ini',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE5A99E),
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
                          dropdownColor: Colors.white,
                          value: _selectedSourceShade,
                          decoration: _getDropdownDecoration(
                            _selectedSourceProduct == null
                                ? 'Pilih Produk Terlebih Dahulu'
                                : 'Pilih Shade',
                          ),
                          style: const TextStyle(color: Color(0xFF3E3635), fontSize: 13),
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
                                  Text(shade.shadeName),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF2ECE7),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x055A4A45),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cari Padanan di Merek Lain (Target)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC89E88),
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
                        color: const Color(0xFF3E3635).withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_matches.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF2ECE7)),
                        ),
                        child: const Center(
                          child: Text(
                            'Tidak ada padanan warna yang cukup dekat (Delta E > 8.0).',
                            style: TextStyle(color: Color(0xFF8E807E), fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _matches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final match = _matches[index];
                          final product = match['product'] as ProductShade;
                          final double pct = match['matchPercentage'] as double;
                          final double dE = match['deltaE'] as double;
                          final hexColor = Color(int.parse('FF${product.hexCode.replaceAll('#', '')}', radix: 16));

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFF2ECE7),
                                width: 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x045A4A45),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 48,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    color: hexColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFF2ECE7), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(color: hexColor.withOpacity(0.15), blurRadius: 8),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.brand,
                                        style: const TextStyle(
                                          color: Color(0xFFC89E88),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.5,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        product.productName,
                                        style: const TextStyle(
                                          color: Color(0xFF3E3635),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Shade: ${product.shadeName}',
                                        style: const TextStyle(
                                          color: Color(0xFF8E807E),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Jarak Warna (Delta E): ${dE.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: const Color(0xFF8E807E).withOpacity(0.6),
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
                                              backgroundColor: const Color(0xFFE5A99E),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFE5A99E), Color(0xFFC89E88)],
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
        style: const TextStyle(
          color: Color(0xFF8E807E),
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
    return DropdownButtonFormField<T>(
      dropdownColor: Colors.white,
      value: value,
      decoration: _getDropdownDecoration(hint),
      style: const TextStyle(color: Color(0xFF3E3635), fontSize: 13),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(item.toString()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _getDropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: const Color(0xFF8E807E).withOpacity(0.5), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFFCF9F6),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF2ECE7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5A99E)),
      ),
    );
  }
}
