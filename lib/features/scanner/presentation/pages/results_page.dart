import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
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
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => _showGlowCardModal(context, targetLab),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5A93B).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE5A93B).withOpacity(0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.qr_code_2_rounded, color: Color(0xFFE5A93B), size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Glow Card 📸',
                                    style: TextStyle(
                                      color: Color(0xFFE5A93B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

                              // Tombol belanja/beli affiliate & Cari Dupe
                              Row(
                                children: [
                                  Expanded(
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
                                          Icon(Icons.shopping_bag_outlined, size: 16),
                                          SizedBox(width: 6),
                                          Text('Beli Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE5A93B).withOpacity(0.12),
                                        foregroundColor: const Color(0xFFE5A93B),
                                        side: BorderSide(color: const Color(0xFFE5A93B).withOpacity(0.3)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        elevation: 0,
                                      ),
                                      onPressed: () => _findDupesForProduct(context, product),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.discount_outlined, size: 16),
                                          SizedBox(width: 6),
                                          Text('Cari Dupe 🏷️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
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

  String _getCelebrityMatch(String season) {
    switch (season) {
      case "Light Spring":
        return "Lisa (Blackpink), Amanda Seyfried";
      case "True Spring":
        return "Emma Stone, Scarlett Johansson";
      case "Clear Winter":
        return "Courteney Cox, Megan Fox";
      case "Light Summer":
        return "Elle Fanning, Margot Robbie";
      case "Soft Summer":
        return "Gigi Hadid, Bella Hadid";
      case "Deep Autumn":
        return "Zendaya, Meghan Markle";
      case "Deep Winter":
        return "Selena Gomez, Kim Kardashian";
      case "Soft Autumn":
        return "Drew Barrymore, Jisoo (Blackpink)";
      case "True Autumn":
        return "Jennifer Lopez, Jessica Alba";
      case "True Winter":
        return "Anne Hathaway, Lupita Nyong'o";
      case "True Summer":
        return "Emily Blunt, Kate Middleton";
      default:
        return "Zendaya, Lisa (Blackpink)";
    }
  }

  void _showGlowCardModal(BuildContext context, LabColor targetLab) {
    final profile = ColorCalculator.getSeasonalColorProfile(targetLab.l, targetLab.a, targetLab.b);
    final String season = profile['season'] as String;
    final List<String> paletteColors = List<String>.from(profile['paletteColors'] as List);
    final String celebMatch = _getCelebrityMatch(season);

    final skinHex = '#'
        '${widget.extractedRgb[0].toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${widget.extractedRgb[1].toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${widget.extractedRgb[2].toRadixString(16).padLeft(2, '0').toUpperCase()}';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Glow Card',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Area Kartu yang akan di-screenshot oleh user (Rasio ~9:16)
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 360),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1E1E38),
                            Color(0xFF0F0F1A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: const Color(0xFFE5A93B).withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE5A93B).withOpacity(0.1),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header Kartu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'GLOW CARD',
                                    style: TextStyle(
                                      color: Color(0xFFE5A93B),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    'Kecocokan Warna Kulit Persona',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Color(0xFFE5A93B),
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Lingkaran Swatch Warna Kulit Pengguna
                          Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.fromARGB(255, widget.extractedRgb[0], widget.extractedRgb[1], widget.extractedRgb[2]),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Color.fromARGB(255, widget.extractedRgb[0], widget.extractedRgb[1], widget.extractedRgb[2]).withOpacity(0.6),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.matchedStandard.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            skinHex,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontFamily: 'monospace',
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Baris Badge Karakteristik Warna
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildCardBadge(widget.matchedStandard.skinTone, Colors.blueAccent),
                              const SizedBox(width: 8),
                              _buildCardBadge('${widget.matchedStandard.undertone} Undertone', const Color(0xFFE5A93B)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildCardBadge('Musim Warna: $season', Colors.tealAccent),
                          const SizedBox(height: 24),

                          // Grid Palet Rekomendasi
                          const Text(
                            'Palet Kosmetik Musiman Terbaik',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: paletteColors.map((hex) {
                              final color = _getHexColor(hex);
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 5),
                                height: 26,
                                width: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  border: Border.all(color: Colors.white30, width: 1),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),

                          // Selebriti Kembar
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Selebriti Kembaran Warna Kulit:',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  celebMatch,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Footer Promosi
                          Text(
                            'Dibuat Gratis di GlowMatch App',
                            style: TextStyle(
                              color: const Color(0xFFE5A93B).withOpacity(0.6),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Kontrol Aksi di Bawah Kartu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.copy_all_rounded, size: 18),
                          label: const Text('Salin Info Kartu 📋', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                              text: '✨ GlowMatch Skin Profile ✨\n'
                                  'Warna Kulit: ${widget.matchedStandard.name} ($skinHex)\n'
                                  'Undertone: ${widget.matchedStandard.undertone}\n'
                                  'Musim Warna: $season\n'
                                  'Seleb Match: $celebMatch\n'
                                  'Cari tahu kecocokan warna kulitmu gratis di aplikasi GlowMatch!',
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Info profil berhasil disalin ke clipboard!'),
                                backgroundColor: Color(0xFFE5C185),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.15),
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Colors.redAccent, width: 0.5),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '💡 Tips: Silakan screenshot kartu di atas untuk dibagikan!',
                      style: TextStyle(color: Colors.white30, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: child,
        );
      },
    );
  }

  Widget _buildCardBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _findDupesForProduct(BuildContext context, ProductShade sourceProduct) async {
    // 1. Validasi status langganan premium
    if (!_isPremium) {
      _showPremiumUnlockDialog();
      return;
    }

    // 2. Ambil semua shade dalam kategori produk yang sama
    final isar = DatabaseService().isar;
    final allShades = await isar.productShades
        .filter()
        .categoryEqualTo(sourceProduct.category)
        .findAll();

    // 3. Hitung jarak persepsi warna Delta E00 luring
    final List<Map<String, dynamic>> dupes = [];
    final sourceLab = LabColor(sourceProduct.l, sourceProduct.a, sourceProduct.b);

    for (var shade in allShades) {
      // Lewati jika mereknya sama (bukan alternatif/dupe lintas merek)
      if (shade.brand.toLowerCase() == sourceProduct.brand.toLowerCase()) continue;

      final shadeLab = LabColor(shade.l, shade.a, shade.b);
      final deltaE = ColorCalculator.deltaE00(sourceLab, shadeLab);

      // Batasi hanya untuk kemiripan warna tinggi (Delta E <= 5.5)
      if (deltaE <= 5.5) {
        final double matchPercentage = (100.0 - (deltaE * 8)).clamp(50.0, 99.9);
        dupes.add({
          'product': shade,
          'deltaE': deltaE,
          'matchPercentage': matchPercentage,
        });
      }
    }

    // Urutkan berdasarkan Delta E terkecil (paling mirip warnanya)
    dupes.sort((a, b) => (a['deltaE'] as double).compareTo(b['deltaE'] as double));

    if (mounted) {
      _showDupesBottomSheet(context, sourceProduct, dupes);
    }
  }

  void _showDupesBottomSheet(
    BuildContext context,
    ProductShade sourceProduct,
    List<Map<String, dynamic>> dupes,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE5A93B).withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5A93B).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.discount_rounded,
                      color: Color(0xFFE5A93B),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'AI Makeup Dupe Finder 🏷️',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11.5, height: 1.5),
                  children: [
                    const TextSpan(text: 'Padanan alternatif warna terdekat untuk:\n'),
                    TextSpan(
                      text: '${sourceProduct.brand} - ${sourceProduct.productName}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ' (${sourceProduct.shadeName})',
                      style: const TextStyle(color: Color(0xFFE5A93B), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 28),

              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: dupes.isEmpty
                    ? _buildEmptyDupesState()
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: dupes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = dupes[index];
                          final ProductShade dupe = item['product'] as ProductShade;
                          final double deltaE = item['deltaE'] as double;
                          final double matchPercentage = item['matchPercentage'] as double;
                          final Color dupeColor = _getHexColor(dupe.hexCode);

                          String similarityLabel = 'Cukup Mirip';
                          Color badgeColor = Colors.orangeAccent;
                          if (deltaE <= 1.8) {
                            similarityLabel = 'Kemiripan Sempurna';
                            badgeColor = const Color(0xFF00E676);
                          } else if (deltaE <= 3.5) {
                            similarityLabel = 'Sangat Mirip';
                            badgeColor = Colors.tealAccent;
                          }

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 36,
                                  width: 36,
                                  decoration: BoxDecoration(
                                    color: dupeColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: dupeColor.withOpacity(0.4),
                                        blurRadius: 8,
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
                                        dupe.brand,
                                        style: const TextStyle(
                                          color: Color(0xFFE5A93B),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dupe.productName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Shade: ${dupe.shadeName}',
                                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              similarityLabel,
                                              style: TextStyle(color: badgeColor, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${matchPercentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Color(0xFFE5A93B),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _launchUrl(context, dupe.affiliateUrl),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.shopping_bag_outlined, color: Colors.white70, size: 10),
                                            SizedBox(width: 4),
                                            Text(
                                              'Beli 🛒',
                                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '💡 Keakuratan warna dihitung luring berdasarkan data CIEDE2000.',
                  style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyDupesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_clear_outlined, color: Colors.white.withOpacity(0.15), size: 48),
          const SizedBox(height: 12),
          Text(
            'Tidak ditemukan dupe alternatif',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Belum ada produk dari brand lain dengan toleransi warna mendekati.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
