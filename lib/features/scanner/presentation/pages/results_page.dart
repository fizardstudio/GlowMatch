import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/data/models/standard_shade.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/network/database_service.dart';

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
              const SizedBox(height: 28),

              // 3. Judul Bagian Rekomendasi Brand
              const Text(
                'Rekomendasi Produk Kosmetik Cocok',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // 4. Daftar Produk Hasil Pencocokan
              widget.commercialMatches.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.commercialMatches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final match = widget.commercialMatches[index];
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
}
