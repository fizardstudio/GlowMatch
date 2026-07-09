import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/data/models/standard_shade.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/utils/color_calculator.dart';
import '../../../premium_subscription/data/models/app_settings.dart';

class ResultsPage extends StatefulWidget {
  final List<int> extractedRgb;
  final StandardShade matchedStandard;
  final List<Map<String, dynamic>> commercialMatches;

  const ResultsPage({
    super.key,
    required this.extractedRgb,
    required this.matchedStandard,
    required this.commercialMatches,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  String _selectedFilter = 'natural'; // 'natural', 'brightening', 'sunkissed'
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final isar = DatabaseService().isar;
    final settings = await isar.appSettings.get(0);
    if (settings != null && settings.isPremium) {
      setState(() {
        _isPremium = true;
      });
    }
  }

  Future<void> _activatePremium() async {
    final isar = DatabaseService().isar;
    final settings = AppSettings()
      ..id = 0
      ..isPremium = true;

    await isar.writeTxn(() async {
      await isar.appSettings.put(settings);
    });

    setState(() {
      _isPremium = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selamat! Fitur Premium Berhasil Diaktifkan.'),
          backgroundColor: Color(0xFFE5C185),
        ),
      );
    }
  }

  void _showPremiumUnlockDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF16162A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5A93B).withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A93B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: Color(0xFFE5A93B), size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Buka Fitur Premium',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
               ),
              const SizedBox(height: 8),
              const Text(
                'Dapatkan analisis mendalam 12 Musim Warna (Seasonal Color) dan rekomendasi warna Hijab komersial tercocok dengan kulit Anda!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5A93B),
                  foregroundColor: const Color(0xFF0F0F1A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await _activatePremium();
                },
                child: const Text('Aktifkan Premium Permanen', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti Saja', style: TextStyle(color: Colors.white30)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menyaring dan mengurutkan rekomendasi kosmetik berdasarkan preferensi riasan subjektif pengguna.
  List<Map<String, dynamic>> _getFilteredMatches(LabColor targetLab) {
    List<Map<String, dynamic>> filtered = [];

    if (_selectedFilter == 'natural') {
      // Natural: Mengambil shade yang paling mendekati secara objektif (Delta E <= 5.0)
      for (final match in widget.commercialMatches) {
        final double deltaE = match['deltaE'] as double;
        if (deltaE <= 5.0) {
          filtered.add(match);
        }
      }
      // Urutkan berdasarkan Delta E terkecil
      filtered.sort((a, b) => (a['deltaE'] as double).compareTo(b['deltaE'] as double));
    } else if (_selectedFilter == 'brightening') {
      // Brightening: Menyaring shade yang lebih cerah (L* produk > L* kulit) dengan rentang +0.5 sampai +4.5 L*
      for (final match in widget.commercialMatches) {
        final ProductShade product = match['product'] as ProductShade;
        final double diffL = product.l - targetLab.l;
        if (diffL >= 0.5 && diffL <= 4.5) {
          filtered.add(match);
        }
      }
      
      // Jika kosong, ambil semua produk dan urutkan dari yang paling terang (L* terbesar)
      if (filtered.isEmpty) {
        filtered = List.from(widget.commercialMatches);
        filtered.sort((a, b) {
          final productA = a['product'] as ProductShade;
          final productB = b['product'] as ProductShade;
          return productB.l.compareTo(productA.l);
        });
      } else {
        // Urutkan berdasarkan kedekatan dengan target kenaikan optimal +2.0 L*
        filtered.sort((a, b) {
          final productA = a['product'] as ProductShade;
          final productB = b['product'] as ProductShade;
          final devA = ((productA.l - targetLab.l) - 2.0).abs();
          final devB = ((productB.l - targetLab.l) - 2.0).abs();
          return devA.compareTo(devB);
        });
      }
    } else if (_selectedFilter == 'sunkissed') {
      // Sun-Kissed / Tanned: Menyaring shade yang sedikit lebih gelap (L* produk < L* kulit) dengan rentang -0.5 sampai -4.5 L*
      for (final match in widget.commercialMatches) {
        final ProductShade product = match['product'] as ProductShade;
        final double diffL = targetLab.l - product.l;
        if (diffL >= 0.5 && diffL <= 4.5) {
          filtered.add(match);
        }
      }

      // Jika kosong, ambil semua produk dan urutkan dari yang paling gelap (L* terkecil)
      if (filtered.isEmpty) {
        filtered = List.from(widget.commercialMatches);
        filtered.sort((a, b) {
          final productA = a['product'] as ProductShade;
          final productB = b['product'] as ProductShade;
          return productA.l.compareTo(productB.l);
        });
      } else {
        // Urutkan berdasarkan kedekatan dengan target penurunan optimal -2.0 L*
        filtered.sort((a, b) {
          final productA = a['product'] as ProductShade;
          final productB = b['product'] as ProductShade;
          final devA = ((targetLab.l - productA.l) - 2.0).abs();
          final devB = ((targetLab.l - productB.l) - 2.0).abs();
          return devA.compareTo(devB);
        });
      }
    }

    return filtered;
  }

  /// Mengonversi warna RGB menjadi kelas Color Flutter.
  Color _getRgbColor(List<int> rgb) {
    return Color.fromARGB(255, rgb[0], rgb[1], rgb[2]);
  }

  /// Mengonversi string HEX menjadi kelas Color Flutter.
  Color _getHexColor(String hex) {
    final cleanHex = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleanHex', radix: 16));
  }

  /// Fungsi untuk membuka link affiliate e-commerce menggunakan url_launcher.
  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Tidak dapat membuka link';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka link belanja: $urlString'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Logika luring umpan balik kecocokan komunitas
  Future<void> _submitFeedback(ProductShade product, String type) async {
    final isar = DatabaseService().isar;
    try {
      await isar.writeTxn(() async {
        final dbProduct = await isar.productShades.get(product.id);
        if (dbProduct != null) {
          if (type == 'PERFECT') {
            dbProduct.perfectCount++;
          } else if (type == 'TOO_DARK') {
            dbProduct.tooDarkCount++;
          } else if (type == 'TOO_LIGHT') {
            dbProduct.tooLightCount++;
          }
          await isar.productShades.put(dbProduct);
          
          // Sinkronisasi data lokal agar langsung ter-render di UI
          setState(() {
            product.perfectCount = dbProduct.perfectCount;
            product.tooDarkCount = dbProduct.tooDarkCount;
            product.tooLightCount = dbProduct.tooLightCount;
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terima kasih atas ulasan kecocokan Anda!'),
            backgroundColor: Color(0xFFE5C185),
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (_) {}
  }

  /// Mengambil deskripsi penjelasan berdasarkan hasil undertone
  String _getUndertoneExplanation(String undertone) {
    switch (undertone.toLowerCase()) {
      case 'warm':
        return 'Warm Undertone memiliki rona kuning, emas, atau peach. Kosmetik dengan dasar warna hangat/keemasan sangat cocok untuk Anda guna menghindari wajah terlihat pucat/abu-abu.';
      case 'cool':
        return 'Cool Undertone memiliki rona kemerahan atau merah muda (pinkish). Kosmetik dengan dasar warna dingin/merah muda akan menyatu alami dengan kulit Anda.';
      case 'neutral':
      default:
        return 'Neutral Undertone memiliki kombinasi rona hangat dan dingin. Anda beruntung karena fleksibel menggunakan kosmetik dengan rona warna hangat maupun dingin!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final skinColor = _getRgbColor(widget.extractedRgb);
    final targetLab = ColorCalculator.rgbToLab(
      widget.extractedRgb[0],
      widget.extractedRgb[1],
      widget.extractedRgb[2],
    );
    final filteredMatches = _getFilteredMatches(targetLab);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A), // Dark premium color
      appBar: AppBar(
        title: const Text(
          'Hasil Pemindaian',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16162A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Swatch Warna Kulit & Detail Teoretis
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF16162A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    // Swatch warna kulit bercahaya (glowing circle)
                    Container(
                      height: 90,
                      width: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: skinColor,
                        boxShadow: [
                          BoxShadow(
                            color: skinColor.withOpacity(0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.matchedStandard.name,
                            style: const TextStyle(
                              color: Color(0xFFE5A93B),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildPillTag(widget.matchedStandard.skinTone, Colors.blueAccent),
                              const SizedBox(width: 8),
                              _buildPillTag(
                                '${widget.matchedStandard.undertone} Undertone',
                                widget.matchedStandard.undertone.toLowerCase() == 'warm'
                                    ? Colors.orangeAccent
                                    : widget.matchedStandard.undertone.toLowerCase() == 'cool'
                                        ? Colors.pinkAccent
                                        : Colors.tealAccent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'HEX: #${widget.extractedRgb[0].toRadixString(16).padLeft(2, '0').toUpperCase()}'
                            '${widget.extractedRgb[1].toRadixString(16).padLeft(2, '0').toUpperCase()}'
                            '${widget.extractedRgb[2].toRadixString(16).padLeft(2, '0').toUpperCase()}',
                            style: const TextStyle(color: Colors.white60, fontSize: 13, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Deskripsi Teori Warna Kulit
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E38).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getUndertoneExplanation(widget.matchedStandard.undertone),
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 20),

              // 2.2 Seasonal Color Palette & Hijab Recommendations (Fitur PREMIUM)
              _buildSeasonalColorSection(targetLab),
              const SizedBox(height: 28),

              // Preferensi Hasil Riasan (Subjektif)
              const Text(
                'Preferensi Tampilan Riasan',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF16162A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    _buildFilterButton('Natural Match', 'natural', Icons.face_retouching_natural_rounded),
                    _buildFilterButton('Brightening', 'brightening', Icons.auto_awesome_rounded),
                    _buildFilterButton('Sun-Kissed', 'sunkissed', Icons.wb_sunny_outlined),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 3. Judul Bagian Rekomendasi Brand
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Rekomendasi Produk Cocok',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${filteredMatches.length} Produk',
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Daftar Produk Hasil Pencocokan
              filteredMatches.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredMatches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final match = filteredMatches[index];
                        final ProductShade product = match['product'] as ProductShade;
                        final double matchPercentage = match['matchPercentage'] as double;
                        final double deltaE = match['deltaE'] as double;
                        final productShadeColor = _getHexColor(product.hexCode);

                        final totalFeedback = product.perfectCount + product.tooDarkCount + product.tooLightCount;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16162A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: index == 0
                                  ? const Color(0xFFE5A93B).withOpacity(0.3)
                                  : Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Swatch kecil warna shade kosmetik
                                  Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: productShadeColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
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
                                            color: Color(0xFFE5A93B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          product.productName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Shade: ${product.shadeName}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Persentase kecocokan berwarna emas
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE5A93B).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFE5A93B).withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          '${matchPercentage.toStringAsFixed(0)}% Cocok',
                                          style: const TextStyle(
                                            color: Color(0xFFE5A93B),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Jarak: ${deltaE.toStringAsFixed(1)} ΔE',
                                        style: const TextStyle(
                                          color: Colors.white30,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Umpan Balik / Community Validation Loop
                              const Divider(color: Colors.white10, height: 1),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Ulasan Statistik Komunitas
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ULASAN KECOCOKAN KOMUNITAS:',
                                        style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      totalFeedback == 0
                                          ? const Text(
                                              'Belum ada ulasan',
                                              style: TextStyle(color: Colors.white54, fontSize: 10, fontStyle: FontStyle.italic),
                                            )
                                          : Row(
                                              children: [
                                                const Icon(Icons.thumb_up_alt_rounded, color: Colors.greenAccent, size: 10),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${product.perfectCount}',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(Icons.dark_mode_rounded, color: Colors.amberAccent, size: 10),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${product.tooDarkCount}',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(Icons.light_mode_rounded, color: Colors.orangeAccent, size: 10),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${product.tooLightCount}',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                    ],
                                  ),
                                  // Tombol Beri Ulasan
                                  Row(
                                    children: [
                                      _buildVoteButton(
                                        icon: Icons.thumb_up_alt_outlined,
                                        color: Colors.greenAccent,
                                        tooltip: 'Pas / Cocok',
                                        onPressed: () => _submitFeedback(product, 'PERFECT'),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildVoteButton(
                                        icon: Icons.dark_mode_outlined,
                                        color: Colors.amberAccent,
                                        tooltip: 'Kegelapan',
                                        onPressed: () => _submitFeedback(product, 'TOO_DARK'),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildVoteButton(
                                        icon: Icons.light_mode_outlined,
                                        color: Colors.orangeAccent,
                                        tooltip: 'Keterangan',
                                        onPressed: () => _submitFeedback(product, 'TOO_LIGHT'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Tombol belanja/beli affiliate
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E1E38),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _launchUrl(context, product.affiliateUrl),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.shopping_bag_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Beli di Shopee/Tokopedia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.2), width: 0.8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 12),
        color: color,
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildPillTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.sentiment_dissatisfied_outlined, color: Colors.white30, size: 48),
          SizedBox(height: 12),
          Text(
            'Tidak ada kosmetik yang sangat pas.',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Coba pindai wajah lagi di bawah pencahayaan berbeda atau hapus filter kosmetik Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white30, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String value, IconData icon) {
    final bool isSelected = _selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE5A93B).withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFE5A93B).withOpacity(0.4)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFFE5A93B) : Colors.white38,
                size: 18,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonalColorSection(LabColor targetLab) {
    final profile = ColorCalculator.getSeasonalColorProfile(targetLab.l, targetLab.a, targetLab.b);
    final String season = profile['season'] as String;
    final String description = profile['description'] as String;
    final List<String> paletteColors = List<String>.from(profile['paletteColors'] as List);
    final List<String> hijabColors = List<String>.from(profile['hijabColors'] as List);
    final List<String> hijabColorNames = List<String>.from(profile['hijabColorNames'] as List);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isPremium 
              ? const Color(0xFFE5A93B).withOpacity(0.2) 
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_rounded, 
                color: _isPremium ? const Color(0xFFE5A93B) : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Seasonal Color & Hijab (Premium)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!_isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A93B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, color: Color(0xFFE5A93B), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Locked',
                        style: TextStyle(color: Color(0xFFE5A93B), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_isPremium) ...[
            // Tampilan Teaser Terkunci
            Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tipe Musim Warna Anda: ?????',
                      style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Analisis dinamis warna kulit Anda berdasarkan temperatur, saturasi, dan tingkat kecerahan untuk mencarikan kecocokan palet warna.',
                      style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(5, (index) => Container(
                        margin: const EdgeInsets.only(right: 8),
                        height: 24,
                        width: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white12,
                        ),
                      )),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF16162A).withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5A93B),
                              foregroundColor: const Color(0xFF0F0F1A),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.stars_rounded, size: 16),
                            label: const Text('Buka Sekarang 👑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: _showPremiumUnlockDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Tampilan Premium Terbuka
            Text(
              'Tipe Musim Warna Anda: $season',
              style: const TextStyle(
                color: Color(0xFFE5A93B),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'Palet Warna Kosmetik Rekomendasi:',
              style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: paletteColors.map((hex) {
                final color = _getHexColor(hex);
                return Container(
                  margin: const EdgeInsets.only(right: 10),
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            const Text(
              'Warna Hijab Terbaik untuk Kulit Anda:',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(hijabColors.length, (idx) {
                final hex = hijabColors[idx];
                final name = hijabColorNames[idx];
                final color = _getHexColor(hex);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 12,
                        width: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
