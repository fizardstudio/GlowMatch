import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../../../../core/network/database_service.dart';
import '../../../../core/data/models/product_shade.dart';
import '../../../../core/presentation/widgets/app_navigation_drawer.dart';
import '../../../../core/utils/widget_helper.dart';
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
      // Pemicu in-app dialog kedaluwarsa setelah data pouch dimuat
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
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                SizedBox(width: 12),
                Text(
                  'Perhatian Medis!',
                  style: TextStyle(color: Color(0xFF3E3635), fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              'Terdeteksi $expiredCount produk kosmetik di Pouch Anda telah melewati masa kedaluwarsa PAO (Period After Opening).\n\nPenggunaan kosmetik kedaluwarsa dapat memicu iritasi kulit, jerawat, atau reaksi alergi. Disarankan untuk segera menggantinya.',
              style: const TextStyle(color: Color(0xFF8E807E), fontSize: 13, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Mengerti',
                  style: TextStyle(color: Color(0xFFE5A99E), fontWeight: FontWeight.bold),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF2ECE7)),
        ),
        title: const Text('Hapus Produk', style: TextStyle(color: Color(0xFF3E3635))),
        content: Text('Apakah Anda yakin ingin menghapus ${item.productName} dari pouch Anda?', style: const TextStyle(color: Color(0xFF8E807E))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF8E807E))),
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
      
      // Sinkronisasi widget layar utama dinamis
      WidgetHelper.updateExpiryWidget();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.productName} berhasil dihapus.'),
          backgroundColor: const Color(0xFFE5A99E),
        ),
      );
      _loadPouchItems();
    }
  }

  void _showAddProductDialog() async {
    final allCommercial = await _isar.productShades.where().findAll();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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

            // Sinkronisasi widget layar utama dinamis
            WidgetHelper.updateExpiryWidget();

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
      backgroundColor: const Color(0xFFFCF9F6),
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text(
          'Virtual Makeup Pouch',
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
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Judul Pengantar
                  const Text(
                    'Pouch kosmetik luring Anda. Pantau masa kedaluwarsa PAO (Period After Opening) agar kulit tetap sehat.',
                    style: TextStyle(color: Color(0xFF8E807E), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  // Daftar Produk Kosmetik
                  Expanded(
                    child: _pouchItems.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            itemCount: _pouchItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _pouchItems[index];
                              final expirationDate = item.openedDate.add(Duration(days: item.paoMonths * 30));
                              final daysRemaining = expirationDate.difference(now).inDays;
                              final isExpired = now.isAfter(expirationDate);

                              // Hitung presentase progres sisa hari pakai
                              final totalPaoDays = item.paoMonths * 30;
                              final double progress = isExpired
                                  ? 0.0
                                  : (daysRemaining / totalPaoDays).clamp(0.0, 1.0);

                              final hexColor = Color(int.parse('FF${item.hexCode.replaceAll('#', '')}', radix: 16));

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isExpired
                                        ? Colors.redAccent.withOpacity(0.2)
                                        : const Color(0xFFF2ECE7),
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x045A4A45),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          // Swatch Bulat Warna Kosmetik
                                          Container(
                                            height: 36,
                                            width: 36,
                                            decoration: BoxDecoration(
                                              color: hexColor,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: const Color(0xFFF2ECE7), width: 1.5),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.brand.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Color(0xFFC89E88),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                Text(
                                                  item.productName,
                                                  style: const TextStyle(
                                                    color: Color(0xFF3E3635),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'Shade: ${item.shadeName} (${item.category})',
                                                  style: const TextStyle(
                                                    color: Color(0xFF8E807E),
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Tombol Hapus
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                            onPressed: () => _deleteItem(item),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Progress Bar sisa PAO
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: SizedBox(
                                          height: 8,
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            backgroundColor: const Color(0xFFF2ECE7),
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isExpired
                                                  ? Colors.redAccent
                                                  : daysRemaining < 30
                                                      ? Colors.orangeAccent
                                                      : const Color(0xFFE5A99E),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Label Tanggal Expiry
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Dibuka: ${item.openedDate.day}/${item.openedDate.month}/${item.openedDate.year}',
                                            style: const TextStyle(color: Color(0xFF8E807E), fontSize: 10.5),
                                          ),
                                          Text(
                                            isExpired
                                                ? '🚨 KEDALUWARSA!'
                                                : '$daysRemaining hari tersisa (${item.paoMonths}M PAO)',
                                            style: TextStyle(
                                              color: isExpired
                                                  ? Colors.redAccent
                                                  : daysRemaining < 30
                                                      ? Colors.orangeAccent
                                                      : const Color(0xFFC89E88),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Tombol Tambah Produk Baru
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A99E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Tambah Kosmetik ke Pouch',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _showAddProductDialog,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF2ECE7)),
            ),
            child: const Icon(Icons.storefront_outlined, size: 52, color: Color(0xFFE5A99E)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pouch Anda Masih Kosong',
            style: TextStyle(color: Color(0xFF3E3635), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mulai catat kosmetik Anda untuk memantau masa kedaluwarsa PAO luring.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8E807E), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Bottom Sheet Form Tambah Kosmetik
class _AddPouchItemSheet extends StatefulWidget {
  final List<ProductShade> availableProducts;
  final Function(String, String, String, String, String, DateTime, int) onSave;

  const _AddPouchItemSheet({
    required this.availableProducts,
    required this.onSave,
  });

  @override
  State<_AddPouchItemSheet> createState() => _AddPouchItemSheetState();
}

class _AddPouchItemSheetState extends State<_AddPouchItemSheet> {
  String? _selectedBrand;
  String? _selectedProduct;
  ProductShade? _selectedShade;
  DateTime _selectedDate = DateTime.now();
  int _selectedPao = 12; // Default 12 Bulan PAO

  List<String> _brands = [];
  List<String> _products = [];
  List<ProductShade> _shades = [];

  final List<int> _paoOptions = [3, 6, 9, 12, 18, 24, 36];

  @override
  void initState() {
    super.initState();
    // Ekstrak merek unik dari database komersial
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
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Form
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tambah Kosmetik Baru',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE5A99E),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF8E807E)),
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
            dropdownColor: Colors.white,
            value: _selectedShade,
            decoration: _getDropdownDecoration(
              _selectedProduct == null ? 'Pilih Produk Dahulu' : 'Pilih Shade',
            ),
            style: const TextStyle(color: Color(0xFF3E3635), fontSize: 13),
            items: _shades.map((shade) {
              return DropdownMenuItem<ProductShade>(
                value: shade,
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color(int.parse('FF${shade.hexCode.replaceAll('#', '')}', radix: 16)),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF2ECE7)),
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
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFFE5A99E),
                        onPrimary: Colors.white,
                        surface: Colors.white,
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
                color: const Color(0xFFFCF9F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF2ECE7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(color: Color(0xFF3E3635), fontSize: 13),
                  ),
                  const Icon(Icons.calendar_today_rounded, color: Color(0xFFE5A99E), size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Dropdown 5: PAO Months
          _buildLabel('Masa Kedaluwarsa PAO (Bulan)'),
          DropdownButtonFormField<int>(
            dropdownColor: Colors.white,
            value: _selectedPao,
            decoration: _getDropdownDecoration('Pilih PAO'),
            style: const TextStyle(color: Color(0xFF3E3635), fontSize: 13),
            items: _paoOptions.map((pao) {
              return DropdownMenuItem<int>(
                value: pao,
                child: Text('$pao Bulan PAO'),
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
          const SizedBox(height: 24),

          // Tombol Simpan
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A99E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: (_selectedBrand == null || _selectedProduct == null || _selectedShade == null)
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
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) {
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
