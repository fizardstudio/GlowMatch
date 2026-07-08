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
        
        // Ekstrak merek unik untuk Merek Asal
        _sourceBrands = shades.map((s) => s.brand).toSet().toList()..sort();
        
        // Ekstrak merek unik untuk Merek Tujuan
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
        // Filter nama produk berdasarkan brand asal yang dipilih
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
        // Filter shade yang tersedia untuk produk asal tersebut
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

    // Filter kandidat shade tujuan
    final candidates = _allShades.where((s) {
      // Jangan bandingkan produk dengan dirinya sendiri
      if (s.id == _selectedSourceShade!.id) return false;
      
      // Filter kategori yang sejenis (contoh: Foundation hanya dicocokkan dengan Foundation)
      if (s.category != _selectedSourceShade!.category) return false;

      // Filter berdasarkan brand target jika dipilih
      if (_selectedTargetBrand != null && _selectedTargetBrand!.isNotEmpty) {
        return s.brand == _selectedTargetBrand;
      }
      
      // Jika merek target tidak dipilih, cari di semua brand LAIN
      return s.brand != _selectedSourceBrand;
    }).toList();

    for (final candidate in candidates) {
      final candidateLab = LabColor(candidate.l, candidate.a, candidate.b);
      final double deltaE = ColorCalculator.deltaE76(sourceLab, candidateLab);
      
      // Ambil yang kemiripannya cukup dekat secara visual (Delta E <= 8.0)
      if (deltaE <= 8.0) {
        final double matchPercentage = ColorCalculator.calculateMatchPercentage(deltaE);
        results.add({
          'product': candidate,
          'deltaE': deltaE,
          'matchPercentage': matchPercentage,
        });
      }
    }

    // Urutkan berdasarkan tingkat kecocokan tertinggi
    results.sort((a, b) => (a['deltaE'] as double).compareTo(b['deltaE'] as double));

    setState(() {
      _matches = results;
    });
  }

  Color _getMatchPercentageColor(double percentage) {
    if (percentage >= 90) return const Color(0xFF4CAF50); // Hijau
    if (percentage >= 75) return const Color(0xFFFF9800); // Oranye
    return const Color(0xFFE53935); // Merah
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text(
          'Shade Converter',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        backgroundColor: const Color(0xFF16162A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5C185)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Form Card input dengan style Glassmorphic
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16162A).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE5C185).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pilih Shade Anda Saat Ini',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE5C185),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Dropdown 1: Merek Asal
                        _buildDropdownLabel('Merek Asal'),
                        _buildDropdown<String>(
                          value: _selectedSourceBrand,
                          items: _sourceBrands,
                          hint: 'Pilih Merek Asal',
                          onChanged: _onSourceBrandChanged,
                        ),
                        const SizedBox(height: 16),

                        // Dropdown 2: Produk Asal
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

                        // Dropdown 3: Shade Asal
                        _buildDropdownLabel('Warna Shade Asal'),
                        DropdownButtonFormField<ProductShade>(
                          dropdownColor: const Color(0xFF16162A),
                          value: _selectedSourceShade,
                          decoration: _getDropdownDecoration(
                            _selectedSourceProduct == null
                                ? 'Pilih Produk Terlebih Dahulu'
                                : 'Pilih Shade',
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: _sourceShades.map((shade) {
                            return DropdownMenuItem<ProductShade>(
                              value: shade,
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Color(int.parse(shade.hexCode.replaceAll('#', '0xFF'))),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(shade.shadeName),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: _selectedSourceProduct == null ? null : _onSourceShadeChanged,
                        ),
                        const SizedBox(height: 20),
                        
                        Container(
                          height: 1,
                          color: const Color(0xFFE5C185).withOpacity(0.15),
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          'Pilih Merek Target Padanan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE5C185),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Dropdown 4: Merek Tujuan
                        _buildDropdownLabel('Merek Tujuan'),
                        DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF16162A),
                          value: _selectedTargetBrand,
                          decoration: _getDropdownDecoration('Semua Merek (Selain Asal)'),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Semua Merek (Selain Asal)'),
                            ),
                            ..._targetBrands.where((brand) => brand != _selectedSourceBrand).map((brand) {
                              return DropdownMenuItem<String>(
                                value: brand,
                                child: Text(brand),
                              );
                            }),
                          ],
                          onChanged: _selectedSourceShade == null ? null : _onTargetBrandChanged,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Hasil Rekomendasi
                  if (_selectedSourceShade != null) ...[
                    Text(
                      'Padanan Shade untuk ${_selectedSourceShade!.shadeName}:',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_matches.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16162A).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Tidak ada padanan shade yang cukup dekat terdeteksi di database.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _matches.length,
                        itemBuilder: (context, index) {
                          final match = _matches[index];
                          final ProductShade product = match['product'] as ProductShade;
                          final double pct = match['matchPercentage'] as double;
                          final colorVal = Color(int.parse(product.hexCode.replaceAll('#', '0xFF')));

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16162A),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5C185).withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Visual Warna
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: colorVal,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorVal.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Info Produk
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.brand.toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFFE5C185),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        product.productName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Shade: ${product.shadeName}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Skor Persentase & Tombol E-commerce
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getHighlightBgColor(pct),
                                        borderRadius: BorderRadius.circular(8),
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
                                              backgroundColor: const Color(0xFFE5C185),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFE5C185), Color(0xFFC29047)],
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Beli',
                                            style: TextStyle(
                                              color: Color(0xFF0F0F1A),
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
          color: Colors.white70,
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
      dropdownColor: const Color(0xFF16162A),
      value: value,
      decoration: _getDropdownDecoration(hint),
      style: const TextStyle(color: Colors.white, fontSize: 13),
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
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFF0F0F1A),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: const Color(0xFFE5C185).withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5C185)),
      ),
    );
  }
}
