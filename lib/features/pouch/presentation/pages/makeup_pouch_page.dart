import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../data/models/pouch_item.dart';

class MakeupPouchPage extends StatefulWidget {
  const MakeupPouchPage({super.key});

  @override
  State<MakeupPouchPage> createState() => _MakeupPouchPageState();
}

class _MakeupPouchPageState extends State<MakeupPouchPage> {
  final Isar _isar = DatabaseService().isar;
  List<PouchItem> _pouchItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPouchItems();
  }

  Future<void> _loadPouchItems() async {
    try {
      final items = await _isar.pouchItems.where().findAll();
      setState(() {
        _pouchItems = items;
        _isLoading = false;
      });

      // Tampilkan peringatan dalam aplikasi setelah build frame pertama
      // jika ada produk yang kedaluwarsa
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkExpiredProducts();
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkExpiredProducts() {
    final now = DateTime.now();
    final expiredCount = _pouchItems.where((item) {
      final expirationDate = item.openedDate.add(Duration(days: item.paoMonths * 30));
      return now.isAfter(expirationDate);
    }).length;

    if (expiredCount > 0) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16162A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.redAccent.withOpacity(0.4), width: 1),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                SizedBox(width: 12),
                Text(
                  'Perhatian Medis!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              'Terdeteksi $expiredCount produk kosmetik di Pouch Anda telah melewati masa kedaluwarsa PAO (Period After Opening).\n\nPenggunaan kosmetik kedaluwarsa dapat memicu iritasi kulit, jerawat, atau reaksi alergi. Disarankan untuk segera menggantinya.',
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Mengerti',
                  style: TextStyle(color: Color(0xFFE5C185), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _deleteItem(PouchItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16162A),
        title: const Text('Hapus Produk', style: TextStyle(color: Colors.white)),
        content: Text('Apakah Anda yakin ingin menghapus ${item.productName} dari pouch Anda?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _isar.writeTxn(() async {
        await _isar.pouchItems.delete(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.productName} berhasil dihapus.'),
          backgroundColor: const Color(0xFFE5C185),
        ),
      );
      _loadPouchItems();
    }
  }

  void _showAddProductDialog() async {
    // Muat daftar produk komersial yang tersedia di database
    final allCommercial = await _isar.productShades.where().findAll();
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16162A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _AddPouchItemSheet(
          availableProducts: allCommercial,
          onSave: (brand, name, shade, hex, category, opened, pao) async {
            final newItem = PouchItem()
              ..brand = brand
              ..productName = name
              ..shadeName = shade
              ..hexCode = hex
              ..category = category
              ..openedDate = opened
              ..paoMonths = pao;

            await _isar.writeTxn(() async {
              await _isar.pouchItems.put(newItem);
            });

            _loadPouchItems();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text(
          'Virtual Makeup Pouch',
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
          : _pouchItems.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pouchItems.length,
                  itemBuilder: (context, index) {
                    final item = _pouchItems[index];
                    
                    // Hitung Masa Kadaluwarsa PAO
                    final expirationDate = item.openedDate.add(Duration(days: item.paoMonths * 30));
                    final daysLeft = expirationDate.difference(now).inDays;
                    final totalDays = item.paoMonths * 30;
                    final double progress = (daysLeft / totalDays).clamp(0.0, 1.0);

                    final bool isExpired = daysLeft <= 0;
                    final String statusText;
                    final Color statusColor;

                    if (isExpired) {
                      statusText = 'Kedaluwarsa!';
                      statusColor = Colors.redAccent;
                    } else if (daysLeft <= 30) {
                      statusText = 'Sisa $daysLeft hari!';
                      statusColor = const Color(0xFFFF9800); // Amber
                    } else {
                      final monthsLeft = (daysLeft / 30).round();
                      statusText = 'Sisa $monthsLeft bulan';
                      statusColor = const Color(0xFF4CAF50); // Hijau
                    }

                    final colorVal = Color(int.parse(item.hexCode.replaceAll('#', '0xFF')));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16162A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isExpired
                              ? Colors.redAccent.withOpacity(0.2)
                              : const Color(0xFFE5C185).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              // Lingkaran warna shade
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: colorVal,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorVal.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              
                              // Detail Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.brand.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFFE5C185),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Shade: ${item.shadeName} (${item.category})',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Status Umur Simpan
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _deleteItem(item),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Tanggal Buka & PAO info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Dibuka: ${_formatDate(item.openedDate)}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'Batas PAO: ${item.paoMonths} Bulan',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Visual Expiration Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: isExpired ? 0.0 : progress,
                              backgroundColor: Colors.white.withOpacity(0.05),
                              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE5C185),
        foregroundColor: const Color(0xFF0F0F1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: _showAddProductDialog,
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF16162A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5C185).withOpacity(0.15), width: 1.5),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: Color(0xFFE5C185),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pouch Kosmetik Anda Kosong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Simpan produk kosmetik yang Anda gunakan ke dalam pouch untuk memantau masa kedaluwarsa PAO-nya secara luring.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _AddPouchItemSheet extends StatefulWidget {
  final List<ProductShade> availableProducts;
  final Function(
    String brand,
    String name,
    String shade,
    String hex,
    String category,
    DateTime opened,
    int pao,
  ) onSave;

  const _AddPouchItemSheet({
    required this.availableProducts,
    required this.onSave,
  });

  @override
  State<_AddPouchItemSheet> createState() => _AddPouchItemSheetState();
}

class _AddPouchItemSheetState extends State<_AddPouchItemSheet> {
  // Pilihan form
  String? _selectedBrand;
  String? _selectedProduct;
  ProductShade? _selectedShade;
  DateTime _selectedDate = DateTime.now();
  int _selectedPao = 12; // Default 12 bulan

  List<String> _brands = [];
  List<String> _products = [];
  List<ProductShade> _shades = [];

  final List<int> _paoPresets = [3, 6, 12, 18, 24, 36];

  @override
  void initState() {
    super.initState();
    _brands = widget.availableProducts.map((p) => p.brand).toSet().toList()..sort();
  }

  void _onBrandChanged(String? brand) {
    setState(() {
      _selectedBrand = brand;
      _selectedProduct = null;
      _selectedShade = null;
      if (brand != null) {
        _products = widget.availableProducts
            .where((p) => p.brand == brand)
            .map((p) => p.productName)
            .toSet()
            .toList()
          ..sort();
      } else {
        _products = [];
      }
      _shades = [];
    });
  }

  void _onProductChanged(String? product) {
    setState(() {
      _selectedProduct = product;
      _selectedShade = null;
      if (product != null && _selectedBrand != null) {
        _shades = widget.availableProducts
            .where((p) => p.brand == _selectedBrand && p.productName == product)
            .toList()
          ..sort((a, b) => a.shadeName.compareTo(b.shadeName));
      } else {
        _shades = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambah Kosmetik Baru',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE5C185),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dropdown 1: Merek
          _buildLabel('Merek Kosmetik'),
          _buildDropdown<String>(
            value: _selectedBrand,
            items: _brands,
            hint: 'Pilih Merek',
            onChanged: _onBrandChanged,
          ),
          const SizedBox(height: 16),

          // Dropdown 2: Nama Produk
          _buildLabel('Nama Produk'),
          _buildDropdown<String>(
            value: _selectedProduct,
            items: _products,
            hint: _selectedBrand == null ? 'Pilih Merek Dahulu' : 'Pilih Produk',
            onChanged: _selectedBrand == null ? null : _onProductChanged,
          ),
          const SizedBox(height: 16),

          // Dropdown 3: Shade
          _buildLabel('Shade Warna'),
          DropdownButtonFormField<ProductShade>(
            dropdownColor: const Color(0xFF16162A),
            value: _selectedShade,
            decoration: _getDropdownDecoration(
              _selectedProduct == null ? 'Pilih Produk Dahulu' : 'Pilih Shade',
            ),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: _shades.map((shade) {
              return DropdownMenuItem<ProductShade>(
                value: shade,
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color(int.parse(shade.hexCode.replaceAll('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(shade.shadeName),
                  ],
                ),
              );
            }).toList(),
            onChanged: _selectedProduct == null
                ? null
                : (val) {
                    setState(() {
                      _selectedShade = val;
                    });
                  },
          ),
          const SizedBox(height: 16),

          // Date Picker: Tanggal Dibuka
          _buildLabel('Tanggal Mulai Dibuka'),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFFE5C185),
                        onPrimary: Color(0xFF0F0F1A),
                        surface: Color(0xFF16162A),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5C185).withOpacity(0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const Icon(Icons.calendar_today_rounded, color: Color(0xFFE5C185), size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Dropdown 5: PAO Months
          _buildLabel('Masa Kedaluwarsa PAO (Bulan)'),
          DropdownButtonFormField<int>(
            dropdownColor: const Color(0xFF16162A),
            value: _selectedPao,
            decoration: _getDropdownDecoration('Pilih PAO'),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: _paoPresets.map((m) {
              return DropdownMenuItem<int>(
                value: m,
                child: Text('$m Bulan (${m}M)'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedPao = val;
                });
              }
            },
          ),
          const SizedBox(height: 28),

          // Tombol Simpan
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5C185),
              foregroundColor: const Color(0xFF0F0F1A),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            onPressed: (_selectedBrand == null ||
                    _selectedProduct == null ||
                    _selectedShade == null)
                ? null
                : () {
                    widget.onSave(
                      _selectedBrand!,
                      _selectedProduct!,
                      _selectedShade!.shadeName,
                      _selectedShade!.hexCode,
                      _selectedShade!.category,
                      _selectedDate,
                      _selectedPao,
                    );
                    Navigator.pop(context);
                  },
            child: const Text(
              'Simpan ke Pouch',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
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
