import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:glowmatch/core/theme/theme_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import '../../../../core/data/models/standard_shade.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/utils/color_calculator.dart';
import '../../../premium_subscription/data/models/app_settings.dart';
import '../../../../core/utils/widget_helper.dart';
import '../../../premium_subscription/presentation/pages/photo_try_on_page.dart';

class ResultsPage extends StatefulWidget {
  final List<int> extractedRgb;
  final StandardShade matchedStandard;
  final List<Map<String, dynamic>> commercialMatches;
  final double faceContrast;
  final String? galleryFilePath;
  final String? faceShape;

  // Fields for Face 2 (Couple Mode)
  final List<int>? coupleExtractedRgb;
  final StandardShade? coupleMatchedStandard;
  final String? coupleFaceShape;
  final double? coupleFaceContrast;

  const ResultsPage({
    key,
    required this.extractedRgb,
    required this.matchedStandard,
    required this.commercialMatches,
    required this.faceContrast,
    this.galleryFilePath,
    this.faceShape,
    this.coupleExtractedRgb,
    this.coupleMatchedStandard,
    this.coupleFaceShape,
    this.coupleFaceContrast,
  });

  bool get isCoupleMode => coupleMatchedStandard != null && coupleExtractedRgb != null;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final GlobalKey _singleGlowCardKey = GlobalKey();
  final GlobalKey _coupleGlowCardKey = GlobalKey();
  bool _isSavingCard = false;

  Future<void> _saveOrShareGlowCard(GlobalKey key, bool isShare) async {
    if (_isSavingCard) return;
    setState(() {
      _isSavingCard = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 150));

      final RenderRepaintBoundary? boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception("Gagal mendapatkan area kartu.");
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List? pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) {
        throw Exception("Gagal membuat gambar kartu.");
      }

      const platform = MethodChannel("com.fizardstudio.glowmatch/widget");
      final String methodName = isShare ? "shareImage" : "saveImageToGallery";
      
      final bool success = await platform.invokeMethod<bool>(methodName, {
        "bytes": pngBytes,
        "filename": "glowmatch_card_${DateTime.now().millisecondsSinceEpoch}",
      }) ?? false;

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isShare 
                  ? 'GlowCard siap dibagikan! 📲' 
                  : 'GlowCard berhasil disimpan ke Galeri! 📸💖 (Folder: Pictures/GlowMatch)'),
              backgroundColor: ThemeManager.primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isShare ? 'Gagal membagikan GlowCard.' : 'Gagal menyimpan GlowCard ke Galeri.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error saving/sharing card: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingCard = false;
        });
      }
    }
  }
  bool get isDark => ThemeManager.isDark;
  Color get textColor => ThemeManager.textColor;
  Color get textMutedColor => ThemeManager.textMutedColor;
  Color get cardBgColor => ThemeManager.cardBgColor;
  Color get cardBorderColor => ThemeManager.cardBorderColor;
  Color get primaryColor => ThemeManager.primaryColor;
  String _selectedFilter = 'natural'; // 'natural', 'brightening', 'sunkissed'
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _saveLastMatchedShade();
  }

  Future<void> _saveLastMatchedShade() async {
    try {
      final isar = DatabaseService().isar;
      await isar.writeTxn(() async {
        final settings = await isar.appSettings.get(0) ?? (AppSettings()..id = 0..isPremium = false);
        settings.lastMatchedShadeName = widget.matchedStandard.name;
        settings.lastMatchedUndertone = widget.matchedStandard.undertone;
        final profile = ColorCalculator.getSeasonalColorProfile(
          widget.matchedStandard.l,
          widget.matchedStandard.a,
          widget.matchedStandard.b,
        );
        settings.lastMatchedSeasonalColor = profile['season'] as String;
        settings.lastMatchedSkinTone = widget.matchedStandard.skinTone;
        settings.lastMatchedFaceShape = widget.faceShape;
        settings.lastMatchedContrast = widget.faceContrast;
        settings.lastMatchedCommercialShadeIds = widget.commercialMatches
            .map((m) => (m['product'] as ProductShade).id)
            .toList();
        await isar.appSettings.put(settings);
      });
      debugPrint("SUCCESS_ISAR: Scanned shade results saved to AppSettings.");
    } catch (e) {
      debugPrint("ERROR_ISAR: Failed to save matched shade to AppSettings: $e");
    }
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

    // Update native widget data
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

  void _showPremiumUnlockDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cardBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child:  Icon(Icons.stars_rounded, color: primaryColor, size: 40),
              ),
              const SizedBox(height: 16),
               Text(
                'Buka Fitur Premium',
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
               ),
              const SizedBox(height: 8),
               Text(
                'Dapatkan analisis mendalam 12 Musim Warna (Seasonal Color) dan rekomendasi warna Hijab komersial tercocok dengan kulit Anda!',
                textAlign: TextAlign.center,
                style: TextStyle(color: textMutedColor, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: cardBgColor,
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
           SnackBar(
            content: Text('Terima kasih atas ulasan kecocokan Anda!'),
            backgroundColor: primaryColor,
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
    if (widget.isCoupleMode) {
      return _buildCoupleResults(context);
    }

    final skinColor = _getRgbColor(widget.extractedRgb);
    final targetLab = ColorCalculator.rgbToLab(
      widget.extractedRgb[0],
      widget.extractedRgb[1],
      widget.extractedRgb[2],
    );
    final filteredMatches = _getFilteredMatches(targetLab);

    return Container(
      decoration: BoxDecoration(
        gradient: ThemeManager.pageGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          title: Text(
            'Hasil Pemindaian',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
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
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorderColor, width: 1.5),
                  boxShadow: ThemeManager.premiumGlowShadow,
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
                        border: Border.all(color: textColor, width: 2),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.matchedStandard.name,
                            style:  TextStyle(
                              color: primaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildPillTag(widget.matchedStandard.skinTone, Colors.blueAccent),
                              _buildPillTag(
                                '${widget.matchedStandard.undertone} Undertone',
                                widget.matchedStandard.undertone.toLowerCase() == 'warm'
                                    ? Colors.orangeAccent
                                    : widget.matchedStandard.undertone.toLowerCase() == 'cool'
                                        ? Colors.pinkAccent
                                        : Colors.tealAccent,
                              ),
                              _buildPillTag(
                                widget.faceContrast < 25.0
                                    ? 'Low Contrast'
                                    : (widget.faceContrast >= 48.0 ? 'High Contrast' : 'Medium Contrast'),
                                Colors.purpleAccent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'HEX: #${widget.extractedRgb[0].toRadixString(16).padLeft(2, '0').toUpperCase()}'
                            '${widget.extractedRgb[1].toRadixString(16).padLeft(2, '0').toUpperCase()}'
                            '${widget.extractedRgb[2].toRadixString(16).padLeft(2, '0').toUpperCase()}',
                            style:  TextStyle(color: textMutedColor, fontSize: 13, fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () => _showGlowCardModal(context, targetLab),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: primaryColor.withOpacity(0.3)),
                              ),
                              child:  Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.qr_code_2_rounded, color: primaryColor, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Glow Card 📸',
                                    style: TextStyle(
                                      color: primaryColor,
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
              if (widget.galleryFilePath != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient:  LinearGradient(
                      colors: [primaryColor, Color(0xFFC89E88)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white),
                    label: const Text(
                      'Uji Coba Riasan 2D di Foto Ini 💄',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PhotoTryOnPage(
                            initialFilePath: widget.galleryFilePath,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // 2. Deskripsi Teori Warna Kulit
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorderColor, width: 1.2),
                  boxShadow: ThemeManager.premiumGlowShadow,
                ),
                child: Text(
                  _getUndertoneExplanation(widget.matchedStandard.undertone),
                  style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorderColor, width: 1.2),
                  boxShadow: ThemeManager.premiumGlowShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.contrast_rounded, color: Colors.purpleAccent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Tingkat Kontras Wajah: ${widget.faceContrast < 25.0 ? 'Rendah (Low)' : (widget.faceContrast >= 48.0 ? 'Tinggi (High)' : 'Sedang (Medium)')}',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.faceContrast < 25.0
                          ? 'Perbedaan warna antara kulit dan mata/rambut Anda lembut. Rekomendasi riasan terbaik adalah warna-warna nude atau soft pastel yang tidak terlalu mencolok.'
                          : (widget.faceContrast >= 48.0
                              ? 'Wajah Anda memiliki kontras yang kuat dan tajam. Anda sangat cocok menggunakan warna bibir yang berani (bold) seperti merah menyala atau berry gelap.'
                              : 'Tingkat kontras wajah Anda seimbang dan serbaguna. Anda bisa bereksperimen dengan bebas antara warna natural segar maupun warna-warna hangat.'),
                      style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2.2 Seasonal Color Palette & Hijab Recommendations (Fitur PREMIUM)
              _buildSeasonalColorSection(targetLab),
              const SizedBox(height: 20),

              // 2.3 Analisis Bentuk Wajah (Face Shape)
              _buildFaceShapeSection(),
              const SizedBox(height: 28),

              // Preferensi Hasil Riasan (Subjektif)
              Text(
                'Preferensi Tampilan Riasan',
                style: TextStyle(
                  color: textColor.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorderColor, width: 1.5),
                  boxShadow: ThemeManager.premiumGlowShadow,
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
                   Text(
                    'Rekomendasi Produk Cocok',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isPremium 
                        ? '${filteredMatches.length} Produk' 
                        : (filteredMatches.length > 2 ? '2 dari ${filteredMatches.length} Produk' : '${filteredMatches.length} Produk'),
                    style: TextStyle(
                      color: textMutedColor.withOpacity(0.5),
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
                      itemCount: _isPremium ? filteredMatches.length : (filteredMatches.length > 2 ? 3 : filteredMatches.length),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (!_isPremium && index == 2) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.3),
                                width: 1.5,
                              ),
                              boxShadow: ThemeManager.premiumGlowShadow,
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_rounded, color: primaryColor, size: 24),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${filteredMatches.length - 2}+ Opsi Produk Lainnya Terkunci',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Upgrade ke Premium sekarang untuk membuka rekomendasi brand kosmetik lokal & internasional lainnya.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: textMutedColor,
                                    fontSize: 11,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onPressed: _showPremiumUnlockDialog,
                                    child: const Text(
                                      'Buka Semua Rekomendasi (Premium)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final match = filteredMatches[index];
                        final ProductShade product = match['product'] as ProductShade;
                        final double matchPercentage = match['matchPercentage'] as double;
                        final double deltaE = match['deltaE'] as double;
                        final productShadeColor = _getHexColor(product.hexCode);

                        final totalFeedback = product.perfectCount + product.tooDarkCount + product.tooLightCount;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: index == 0
                                  ? primaryColor.withOpacity(0.4)
                                  : cardBorderColor.withOpacity(0.45),
                              width: 1.5,
                            ),
                            boxShadow: ThemeManager.premiumGlowShadow,
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
                                      border: Border.all(color: cardBorderColor.withOpacity(0.35)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.brand,
                                          style:  TextStyle(
                                            color: primaryColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          product.productName,
                                          style:  TextStyle(
                                            color: textColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Shade: ${product.shadeName}',
                                          style: TextStyle(
                                            color: textColor.withOpacity(0.8),
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
                                          color: primaryColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: primaryColor.withOpacity(0.4)),
                                        ),
                                        child: Text(
                                          '${matchPercentage.toStringAsFixed(0)}% Cocok',
                                          style:  TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Jarak: ${deltaE.toStringAsFixed(1)} ΔE',
                                        style: TextStyle(
                                          color: textMutedColor.withOpacity(0.5),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Umpan Balik / Community Validation Loop
                              Divider(color: cardBorderColor.withOpacity(0.15), height: 1),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Ulasan Statistik Komunitas
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ULASAN KECOCOKAN KOMUNITAS:',
                                        style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      totalFeedback == 0
                                          ?  Text(
                                              'Belum ada ulasan',
                                              style: TextStyle(color: textMutedColor, fontSize: 10, fontStyle: FontStyle.italic),
                                            )
                                          : Row(
                                              children: [
                                                const Icon(Icons.thumb_up_alt_rounded, color: Colors.greenAccent, size: 10),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${product.perfectCount}',
                                                  style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(Icons.dark_mode_rounded, color: Colors.amberAccent, size: 10),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${product.tooDarkCount}',
                                                  style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(Icons.light_mode_rounded, color: Colors.orangeAccent, size: 10),
                                                const SizedBox(width: 3),
                                                Text(
                                                  '${product.tooLightCount}',
                                                  style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
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
                                        backgroundColor: primaryColor.withOpacity(0.12),
                                        foregroundColor: primaryColor,
                                        side: BorderSide(color: primaryColor.withOpacity(0.3)),
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
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.sentiment_dissatisfied_outlined, color: textMutedColor.withOpacity(0.5), size: 48),
          SizedBox(height: 12),
          Text(
            'Tidak ada kosmetik yang sangat pas.',
            style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Coba pindai wajah lagi di bawah pencahayaan berbeda atau hapus filter kosmetik Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String value, IconData icon) {
    final bool isSelected = _selectedFilter == value;
    final bool isLocked = !_isPremium && value != 'natural';
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isLocked) {
            _showPremiumUnlockDialog();
            return;
          }
          setState(() {
            _selectedFilter = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor
                : cardBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : cardBorderColor,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLocked ? Icons.lock_outline_rounded : icon,
                color: isSelected ? Colors.white : (isLocked ? Colors.amber : textMutedColor),
                size: 18,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : textColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cardBorderColor.withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: ThemeManager.premiumGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_rounded, 
                color: _isPremium ? primaryColor : Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 8),
               Text(
                'Seasonal Color & Hijab (Premium)',
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!_isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:  Row(
                    children: [
                      Icon(Icons.lock_rounded, color: primaryColor, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Locked',
                        style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
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
                    Text(
                      'Tipe Musim Warna Anda: ?????',
                      style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analisis dinamis warna kulit Anda berdasarkan temperatur, saturasi, dan tingkat kecerahan untuk mencarikan kecocokan palet warna.',
                      style: TextStyle(color: textMutedColor.withOpacity(0.6), fontSize: 12, height: 1.4),
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
                    color: cardBgColor.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: cardBgColor,
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
              style:  TextStyle(
                color: primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Palet Warna Kosmetik Rekomendasi:',
              style: TextStyle(color: textMutedColor.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.bold),
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
                    border: Border.all(color: textMutedColor.withOpacity(0.4), width: 1),
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
            Divider(color: cardBorderColor.withOpacity(0.15)),
            const SizedBox(height: 12),
             Text(
              'Warna Hijab Terbaik untuk Kulit Anda:',
              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
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
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorderColor, width: 1.2),
                    boxShadow: ThemeManager.premiumGlowShadow,
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
                        style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11),
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

  Widget _buildFaceShapeSection() {
    final String detectedShape = widget.faceShape?.toLowerCase() ?? 'oval';
    
    // Konversi key ke Nama Terbaca
    String shapeName = 'Oval';
    String desc = 'Bentuk wajah proporsional dan seimbang.';
    String eyebrowGuide = 'Soft Arch (Lengkung Lembut) - Menjaga harmoni alami wajah.';
    String contourGuide = 'Standard Highlighting - Berikan highlight di dahi, batang hidung, dan dagu. Contour ringan di bawah tulang pipi.';
    String hijabGuide = 'Gaya Klasik - Cocok dengan hampir seluruh gaya lipatan hijab atau belahan rambut.';
    IconData shapeIcon = Icons.face_rounded;

    if (detectedShape == 'round') {
      shapeName = 'Bulat (Round)';
      desc = 'Bentuk wajah feminin dengan garis rahang melengkung lembut.';
      eyebrowGuide = 'High Arch (Menukik Tajam) - Menambah sudut ketegasan struktural pada wajah.';
      contourGuide = 'Slanted Shading - Contour miring di bawah tulang pipi mengarah ke sudut bibir untuk memberikan efek tirus.';
      hijabGuide = 'Sisi Pipi Tertutup - Tarik kain hijab agak ke depan pipi untuk mempersempit area lebar wajah.';
      shapeIcon = Icons.blur_circular_rounded;
    } else if (detectedShape == 'long') {
      shapeName = 'Lonjong (Long/Oblong)';
      desc = 'Panjang wajah lebih menonjol dibanding lebar pelipis dan rahang.';
      eyebrowGuide = 'Flat / Straight (Mendatar) - Membantu memotong panjang wajah secara visual.';
      contourGuide = 'Horizontal Shading - Contour horizontal di sepanjang tulang pipi luar, dahi atas, dan dagu bawah untuk memperpendek wajah.';
      hijabGuide = 'Ciput Tampak - Gunakan ciput/undercap yang menonjol untuk memotong jarak dahi secara visual.';
      shapeIcon = Icons.crop_portrait_rounded;
    } else if (detectedShape == 'square') {
      shapeName = 'Kotak (Square)';
      desc = 'Garis rahang tegas dan lebar dahi sejajar dengan lebar rahang.';
      eyebrowGuide = 'Curved / Rounded (Membulat) - Membantu melunakkan sudut rahang yang tegas.';
      contourGuide = 'Jawline Contouring - Fokus shading pada sudut rahang bawah dan pelipis untuk menghaluskan sudut tajam.';
      hijabGuide = 'Lipatan Longgar - Gaya hijab longgar/loose di area rahang untuk menyamarkan sudut tulang rahang lebar.';
      shapeIcon = Icons.crop_square_rounded;
    } else if (detectedShape == 'heart') {
      shapeName = 'Hati (Heart)';
      desc = 'Dahi lebar dengan rahang lembut yang menirus tajam ke dagu.';
      eyebrowGuide = 'Low Arch / Rounded - Menyeimbangkan dahi lebar dan dagu runcing.';
      contourGuide = 'Temples Contouring - Contour di pelipis dahi atas untuk mempersempit dahi, highlight pada dagu untuk efek volume.';
      hijabGuide = 'Volume Leher - Lipatan hijab ber-volume di bawah dagu/leher untuk mengimbangi dahi yang lebar.';
      shapeIcon = Icons.favorite_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cardBorderColor.withOpacity(0.55),
          width: 1.5,
        ),
        boxShadow: ThemeManager.premiumGlowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(shapeIcon, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Analisis Bentuk Wajah (Face Shape)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.faceShape == null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wajah kurang terdeteksi penuh. Menggunakan tipe wajah universal (Oval).',
                      style: TextStyle(color: Colors.amber, fontSize: 10, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            'Bentuk Wajah Terdeteksi: $shapeName',
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Divider(color: cardBorderColor.withOpacity(0.15)),
          const SizedBox(height: 12),
          
          // Rekomendasi Alis
          _buildRecRow(Icons.remove_red_eye_outlined, 'Bentuk Alis (Eyebrow Guide):', eyebrowGuide),
          const SizedBox(height: 14),
          
          // Rekomendasi Contouring
          _buildRecRow(Icons.brush_outlined, 'Teknik Shading (Contour & Highlight):', contourGuide),
          const SizedBox(height: 14),
          
          // Rekomendasi Hijab
          _buildRecRow(Icons.checkroom_rounded, 'Gaya Hijab & Rambut:', hijabGuide),
        ],
      ),
    );
  }

  Widget _buildRecRow(IconData icon, String title, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: primaryColor, size: 14),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: textMutedColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 3),
              Text(
                content,
                style: TextStyle(color: textColor, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
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
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Area Kartu (Rasio 9:16 vertikal penuh)
                    RepaintBoundary(
                      key: _singleGlowCardKey,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 600),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: const Color(0xFFBF953F), // Selalu emas berkilau
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFBF953F).withOpacity(0.45),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Latar belakang foto asli pengguna
                            widget.galleryFilePath != null && File(widget.galleryFilePath!).existsSync()
                                ? Image.file(
                                    File(widget.galleryFilePath!),
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2F)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                            // Overlay Gelap Gradien untuk Kontras Tulisan Emas
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.65),
                                    Colors.black.withOpacity(0.1),
                                    Colors.black.withOpacity(0.75),
                                  ],
                                ),
                              ),
                            ),
                            // Konten Informasi GlowCard
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Header Kartu melayang (Emas)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'GLOW CARD',
                                            style: TextStyle(
                                              color: Color(0xFFFCF6BA), // Emas
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          Text(
                                            'ANALISIS RONA KULIT AI',
                                            style: TextStyle(
                                              color: Color(0xFFFCF6BA),
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFBF953F).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome,
                                          color: Color(0xFFFCF6BA), // Emas
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  // Panel Kaca Info Utama (Glassmorphism sangat transparan)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: BackdropFilter(
                                      filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3), // Blur tipis agar transparan jernih
                                      child: Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F0F1A).withOpacity(0.02), // Sangat transparan (2%)
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: const Color(0xFFBF953F).withOpacity(0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                // Bulatan warna hasil deteksi
                                                Container(
                                                  height: 48,
                                                  width: 48,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Color.fromARGB(
                                                      255,
                                                      widget.extractedRgb[0],
                                                      widget.extractedRgb[1],
                                                      widget.extractedRgb[2],
                                                    ),
                                                    border: Border.all(
                                                      color: const Color(0xFFFCF6BA), // Emas
                                                      width: 2.5,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Color.fromARGB(
                                                          255,
                                                          widget.extractedRgb[0],
                                                          widget.extractedRgb[1],
                                                          widget.extractedRgb[2],
                                                        ).withOpacity(0.4),
                                                        blurRadius: 10,
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
                                                        widget.matchedStandard.name,
                                                        style: const TextStyle(
                                                          color: Color(0xFFFCF6BA), // Emas
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${widget.matchedStandard.undertone} Undertone • ${widget.matchedStandard.skinTone}',
                                                        style: const TextStyle(
                                                          color: Color(0xFFFCF6BA), // Emas
                                                          fontSize: 10.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 20, color: Color(0xFFBF953F)),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Musim Warna:',
                                                  style: TextStyle(
                                                    color: Color(0xFFFCF6BA), // Emas
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFBF953F).withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    season,
                                                    style: const TextStyle(
                                                      color: Color(0xFFFCF6BA), // Emas
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'Selebriti Kembar:',
                                                  style: TextStyle(
                                                    color: Color(0xFFFCF6BA), // Emas
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Text(
                                                  celebMatch,
                                                  style: const TextStyle(
                                                    color: Color(0xFFFCF6BA), // Emas
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Watermark di bagian paling bawah kartu (Emas)
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        color: Color(0xFFFCF6BA),
                                        size: 11,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Dibuat di GlowMatch AI Skin Scanner',
                                        style: TextStyle(
                                          color: Color(0xFFFCF6BA),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                    const SizedBox(height: 24),
                    // Tombol Aksi di Bawah Kartu
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.copy_all_rounded, size: 16),
                          label: const Text('Salin Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                              SnackBar(
                                content: const Text('Info profil berhasil disalin ke clipboard!'),
                                backgroundColor: primaryColor,
                              ),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Simpan Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _saveOrShareGlowCard(_singleGlowCardKey, false),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Bagikan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _saveOrShareGlowCard(_singleGlowCardKey, true),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.15),
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.all(10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.redAccent, width: 0.5),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '💡 Tips: Silakan screenshot kartu di atas untuk dibagikan!',
                      style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
            color: ThemeManager.scaffoldBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: cardBorderColor.withOpacity(0.4), width: 1.5),
            boxShadow: ThemeManager.premiumGlowShadow,
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
                    color: cardBorderColor.withOpacity(0.4),
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
                      color: primaryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child:  Icon(
                      Icons.discount_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                   Expanded(
                    child: Text(
                      'AI Makeup Dupe Finder 🏷️',
                      style: TextStyle(
                        color: textColor,
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
                  style: TextStyle(color: textMutedColor.withOpacity(0.85), fontSize: 11.5, height: 1.5),
                  children: [
                    const TextSpan(text: 'Padanan alternatif warna terdekat untuk:\n'),
                    TextSpan(
                      text: '${sourceProduct.brand} - ${sourceProduct.productName}',
                      style:  TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: ' (${sourceProduct.shadeName})',
                      style:  TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Divider(color: cardBorderColor.withOpacity(0.25), height: 28),

              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: dupes.isEmpty
                    ? _buildEmptyDupesState()
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: dupes.length,
                        separatorBuilder: (_, __) => Divider(
                              color: cardBorderColor.withOpacity(0.45),
                              height: 20,
                              thickness: 1.2,
                            ),
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
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 36,
                                  width: 36,
                                  decoration: BoxDecoration(
                                    color: dupeColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: cardBorderColor, width: 1.5),
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
                                        style:  TextStyle(
                                          color: primaryColor,
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
                                        style:  TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Shade: ${dupe.shadeName}',
                                            style: TextStyle(color: textMutedColor.withOpacity(0.85), fontSize: 11),
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
                                      style:  TextStyle(
                                        color: primaryColor,
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
                                          color: cardBgColor,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: cardBorderColor.withOpacity(0.5), width: 1.0),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.shopping_bag_outlined, color: textColor.withOpacity(0.8), size: 10),
                                            SizedBox(width: 4),
                                            Text(
                                              'Beli 🛒',
                                              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold),
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
                  style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 9.5),
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
          Icon(Icons.layers_clear_outlined, color: textMutedColor.withOpacity(0.35), size: 48),
          const SizedBox(height: 12),
          Text(
            'Tidak ditemukan dupe alternatif',
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Belum ada produk dari brand lain dengan toleransi warna mendekati.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCoupleResults(BuildContext context) {
    final rgb1 = widget.extractedRgb;
    final rgb2 = widget.coupleExtractedRgb!;
    final color1 = Color.fromARGB(255, rgb1[0], rgb1[1], rgb1[2]);
    final color2 = Color.fromARGB(255, rgb2[0], rgb2[1], rgb2[2]);
    final shade1 = widget.matchedStandard;
    final shade2 = widget.coupleMatchedStandard!;

    final undertone1 = shade1.undertone.toLowerCase();
    final undertone2 = shade2.undertone.toLowerCase();

    int compatibilityScore = 92;
    String compatibilityTitle = 'Perfect Balance ⚖️';
    String compatibilityDesc = 'Perpaduan yang sangat seimbang! Salah satu memiliki warna kulit netral fleksibel, melengkapi undertone pasangan/sahabat dengan sangat mulus.';
    List<Color> couplePalette = [
      const Color(0xFF008080), // Teal
      const Color(0xFFE0B0FF), // Mauve
      const Color(0xFFFFCC99), // Peach
      const Color(0xFF1F305E), // Navy
      const Color(0xFFF5F5DC), // Beige
    ];
    List<String> couplePaletteNames = ['Teal', 'Mauve', 'Peach', 'Navy', 'Beige'];

    if (undertone1 == undertone2) {
      compatibilityScore = 96;
      compatibilityTitle = 'Twin Soul 👯‍♀️';
      compatibilityDesc = 'Kalian berdua memiliki rona undertone yang sama! Sangat serasi dalam memilih palet kosmetik dan pakaian yang senada untuk hang out bersama.';
      if (undertone1 == 'warm') {
        couplePalette = [
          const Color(0xFFD4AF37), // Gold
          const Color(0xFFC85A17), // Terracotta
          const Color(0xFF808000), // Olive
          const Color(0xFFFFFDD0), // Cream
          const Color(0xFFFFDB58), // Mustard
        ];
        couplePaletteNames = ['Gold', 'Terracotta', 'Olive', 'Cream', 'Mustard'];
      } else if (undertone1 == 'cool') {
        couplePalette = [
          const Color(0xFF4169E1), // Royal Blue
          const Color(0xFF50C878), // Emerald
          const Color(0xFF8F00FF), // Violet
          const Color(0xFFA5F2F3), // Ice Blue
          const Color(0xFF808080), // Grey
        ];
        couplePaletteNames = ['Royal Blue', 'Emerald', 'Violet', 'Ice Blue', 'Grey'];
      }
    } else if ((undertone1 == 'warm' && undertone2 == 'cool') || (undertone1 == 'cool' && undertone2 == 'warm')) {
      compatibilityScore = 88;
      compatibilityTitle = 'Harmonious Contrast ☯️';
      compatibilityDesc = 'Rona undertone kalian saling melengkapi satu sama lain! Kombinasi yang unik antara kehangatan (Warm) dan kesegaran (Cool) membuat kalian saling menyempurnakan.';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: ThemeManager.pageGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          title: Text(
            'Couple & Bestie Matcher 👥',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorderColor, width: 1.5),
                  boxShadow: ThemeManager.premiumGlowShadow,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Kamu 👤',
                                style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color1,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color1.withOpacity(0.4),
                                      blurRadius: 12,
                                    ),
                                  ],
                                  border: Border.all(color: textColor, width: 2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                shade1.undertone,
                                style:  TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                shade1.name,
                                style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 120,
                          width: 1,
                          color: Colors.white10,
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Partner / Bestie 👥',
                                style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color2,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color2.withOpacity(0.4),
                                      blurRadius: 12,
                                    ),
                                  ],
                                  border: Border.all(color: textColor, width: 2),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                shade2.undertone,
                                style:  TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                shade2.name,
                                style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: cardBgColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        onPressed: () => _showCoupleGlowCardModal(context, shade1, shade2, color1, color2),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.share_rounded, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Generate Couple Glow Card 📸',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorderColor, width: 1.5),
                  boxShadow: ThemeManager.premiumGlowShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      'UNDERTONE COMPATIBILITY INDEX 🔬',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$compatibilityScore%',
                            style:  TextStyle(
                              color: primaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                compatibilityTitle,
                                style:  TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                compatibilityDesc,
                                style: TextStyle(color: textMutedColor.withOpacity(0.85), fontSize: 11.5, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorderColor, width: 1.5),
                  boxShadow: ThemeManager.premiumGlowShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      'HARMONIOUS COUPLE OUTFIT COLORS 👗👔',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Warna pakaian yang direkomendasikan saat kalian berfoto atau hangout bersama agar terlihat kompak dan saling bersinar:',
                      style: TextStyle(color: textMutedColor.withOpacity(0.85), fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(couplePalette.length, (index) {
                        final color = couplePalette[index];
                        final name = couplePaletteNames[index];
                        return Expanded(
                          child: Column(
                            children: [
                              Container(
                                height: 36,
                                width: 36,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cardBorderColor, width: 1.5),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 9.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cardBorderColor, width: 1.5),
                  boxShadow: ThemeManager.premiumGlowShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      'CELEBRITY COUPLE INSPIRATION 🌟',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getCoupleCelebrityInspiration(undertone1, undertone2),
                      style:  TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mereka adalah contoh selebriti dengan kecocokan rona warna kulit serupa dengan kalian berdua.',
                      style: TextStyle(color: textMutedColor.withOpacity(0.4), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
     ),
    );
  }

  String _getCoupleCelebrityInspiration(String u1, String u2) {
    if (u1 == 'warm' && u2 == 'warm') {
      return "Zendaya (Deep Autumn) & Lisa Blackpink (True Autumn)";
    } else if (u1 == 'cool' && u2 == 'cool') {
      return "Anne Hathaway (True Winter) & Elle Fanning (Light Summer)";
    } else if (u1 == 'neutral' && u2 == 'neutral') {
      return "Gigi Hadid (Soft Summer) & Jisoo Blackpink (Soft Autumn)";
    } else {
      return "Zendaya (Warm) & Gigi Hadid (Neutral/Cool)";
    }
  }

  void _showCoupleGlowCardModal(
    BuildContext context,
    StandardShade shade1,
    StandardShade shade2,
    Color color1,
    Color color2,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Couple Glow Card',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Area Kartu (Rasio 9:16 vertikal penuh)
                    RepaintBoundary(
                      key: _singleGlowCardKey,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 600),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: const Color(0xFFBF953F), // Selalu emas berkilau
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFBF953F).withOpacity(0.45),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Latar belakang foto asli pengguna (jepretan berdua)
                            widget.galleryFilePath != null && File(widget.galleryFilePath!).existsSync()
                                ? Image.file(
                                    File(widget.galleryFilePath!),
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2F)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                            // Overlay Gelap Gradien untuk Kontras Tulisan
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.65),
                                    Colors.black.withOpacity(0.1),
                                    Colors.black.withOpacity(0.75),
                                  ],
                                ),
                              ),
                            ),
                            // Konten Informasi Couple GlowCard
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Header Kartu melayang (Emas)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'GLOW CARD',
                                            style: TextStyle(
                                              color: Color(0xFFFCF6BA), // Emas
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          Text(
                                            'ANALISIS HARMONI COUPLE',
                                            style: TextStyle(
                                              color: Color(0xFFFCF6BA),
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFBF953F).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          'COUPLE MODE',
                                          style: TextStyle(
                                            color: Color(0xFFFCF6BA), // Emas
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  // Panel Kaca Info Utama (Glassmorphism sangat transparan)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: BackdropFilter(
                                      filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3), // Blur tipis agar transparan jernih
                                      child: Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F0F1A).withOpacity(0.02), // Sangat transparan (2%)
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: const Color(0xFFBF953F).withOpacity(0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Dual Skin Harmony ✨',
                                              style: TextStyle(
                                                color: Color(0xFFFCF6BA), // Emas
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                // Kolom Kiri - Kamu
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      Container(
                                                        height: 54,
                                                        width: 54,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: color1,
                                                          border: Border.all(
                                                            color: const Color(0xFFFCF6BA), // Emas
                                                            width: 2.0,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: color1.withOpacity(0.4),
                                                              blurRadius: 10,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      const Text(
                                                        'Kamu 👤',
                                                        style: TextStyle(
                                                          color: Color(0xFFFCF6BA), // Emas
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        shade1.undertone,
                                                        style: const TextStyle(
                                                          color: Color(0xFFFCF6BA), // Emas
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        '#${color1.value.toRadixString(16).substring(2).toUpperCase()}',
                                                        style: const TextStyle(
                                                          color: Color(0xFFFCF6BA), // Emas
                                                          fontSize: 9,
                                                          fontFamily: 'monospace',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                // Ikon Hati di Tengah
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFBF953F).withOpacity(0.2),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.favorite_rounded,
                                                    color: Color(0xFFFCF6BA), // Emas
                                                    size: 16,
                                                  ),
                                                ),
                                                // Kolom Kanan - Partner
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      Container(
                                                        height: 54,
                                                        width: 54,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: color2,
                                                          border: Border.all(
                                                            color: const Color(0xFFFCF6BA), // Emas
                                                            width: 2.0,
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: color2.withOpacity(0.4),
                                                              blurRadius: 10,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      const Text(
                                                        'Partner 👥',
                                                        style: TextStyle(
                                                          color: Color(0xFFFCF6BA), // Emas
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        shade2.undertone,
                                                        style: const TextStyle(
                                                          color: Color(0xFFFCF6BA), // Emas
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        '#${color2.value.toRadixString(16).substring(2).toUpperCase()}',
                                                        style: const TextStyle(
                                                          color: Color(0xFFFCF6BA), // Emas
                                                          fontSize: 9,
                                                          fontFamily: 'monospace',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 24, color: Color(0xFFBF953F)),
                                            const Text(
                                              'Kecocokan Harmoni: 96% ✨',
                                              style: TextStyle(
                                                color: Color(0xFFFCF6BA), // Emas
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Watermark (Emas)
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        color: Color(0xFFFCF6BA),
                                        size: 11,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Dibuat di GlowMatch Couple Scanner',
                                        style: TextStyle(
                                          color: Color(0xFFFCF6BA),
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                    const SizedBox(height: 24),
                    // Tombol Aksi di Bawah
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.copy_all_rounded, size: 16),
                          label: const Text('Salin Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            final text = 'GlowCard Couple Mode matched! Rona saya: ${shade1.name} (${shade1.undertone}) & Partner saya: ${shade2.name} (${shade2.undertone}). Cek warna kulitmu di GlowMatch!';
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Info profil disalin ke clipboard 📋'),
                                backgroundColor: primaryColor,
                              ),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Simpan Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _saveOrShareGlowCard(_coupleGlowCardKey, false),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 16),
                          label: const Text('Bagikan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () => _saveOrShareGlowCard(_coupleGlowCardKey, true),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.15),
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.all(10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.redAccent, width: 0.5),
                            ),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '📸 Screenshot layar ini untuk dibagikan ke IG/TikTok!',
                      style: TextStyle(color: textMutedColor.withOpacity(0.5), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

