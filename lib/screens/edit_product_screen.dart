// lib/screens/edit_product_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product_model.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../services/utility_services.dart';

class EditProductScreen extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final Product? product;
  final bool isCopy;

  const EditProductScreen({
    super.key,
    required this.categories,
    this.product,
    this.isCopy = false,
  });

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  String? _selectedCategoryId;
  String? _selectedTaxId;
  int _selectedColor = 1;
  bool _onSale = true;

  List<Map<String, dynamic>> _taxSettings = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();
  final TextEditingController _purchasePriceController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTaxSettings();
    if (widget.product != null) {
      _nameController.text = widget.product!.itemName;
      _sellingPriceController.text = widget.product!.sellingPrice.toStringAsFixed(2);
      _purchasePriceController.text = widget.product!.purchasePrice?.toStringAsFixed(2) ?? '';
      _skuController.text = widget.product!.sku ?? '';
      _codeController.text = widget.product!.code.toString();
      _noteController.text = widget.product!.note ?? '';
      _selectedCategoryId = widget.product!.categoryId;
      _selectedTaxId = widget.product!.taxId;
      _selectedColor = widget.product!.color;
      _onSale = widget.product!.onSale;
    }
  }

  Future<void> _loadTaxSettings() async {
    try {
      final storedApiKey = await StorageService.getApiKey();
      if (storedApiKey == null || storedApiKey.isEmpty) {
        print('Error: API key not available.');
        // Consider showing an error message to the user
        return;
      }

      final taxSettings = await ApiService.fetchTaxSettings();
      if (mounted) {
        setState(() {
          _taxSettings = taxSettings;
        });
      }
    } catch (e) {
      print('Error loading tax settings: $e');
      // Consider showing an error message to the user
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sellingPriceController.dispose();
    _purchasePriceController.dispose();
    _skuController.dispose();
    _codeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final bool isCreating = (widget.product == null || widget.isCopy);
    final screenTitle = isCreating
        ? localizations.translate('createProduct')
        : localizations.translate('editProduct');

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: localizations.translate('saveProduct'),
            onPressed: _saveProduct,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                  localizations.translate('productName'), _nameController),
              const SizedBox(height: 16),
              _buildTextField(
                  localizations.translate('sellingPriceLabel'), // PŘIDAT DO LOKALIZACE
                  _sellingPriceController,
                  isNumber: true),
              const SizedBox(height: 16),
              _buildTextField(
                  localizations.translate('purchasePriceLabel'), // PŘIDAT DO LOKALIZACE
                  _purchasePriceController,
                  isNumber: true),
              const SizedBox(height: 16),
              _buildCategoryDropdown(localizations),
              const SizedBox(height: 16),
              _buildColorPickerRow(localizations),
              const SizedBox(height: 16),
              _buildOnSaleSwitch(localizations),
              const SizedBox(height: 16),
              _buildTextField(localizations.translate('sku'), _skuController),
              const SizedBox(height: 16),
              _buildTextField(
                  localizations.translate('productCode'), _codeController,
                  isNumber: true),
              const SizedBox(height: 16),
              _buildTaxDropdown(localizations),
              const SizedBox(height: 16),
              _buildTextField(localizations.translate('note'), _noteController,
                  isMultiline: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false, bool isMultiline = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: isMultiline ? null : 1,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: label,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.translate('category'),
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>( // Použito DropdownButtonFormField pro lepší vzhled a integraci
          value: _selectedCategoryId,
          isExpanded: true,
          hint: Text(localizations.translate('selectCategory')),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: widget.categories.map((category) {
            return DropdownMenuItem<String>(
              value: category['categoryId'],
              child: Text(category['name']),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildColorPickerRow(AppLocalizations localizations) {
    final colors = [
      Colors.green, Colors.lightBlue, Colors.blue, Colors.yellow,
      Colors.orange, Colors.purple, Colors.red, Colors.brown.shade300,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.translate('color'),
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(colors.length, (index) {
              final colorIndex = index + 1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = colorIndex;
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: colors[index],
                    shape: BoxShape.circle,
                    border: _selectedColor == colorIndex
                        ? Border.all(color: Colors.black, width: 3)
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxDropdown(AppLocalizations localizations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.translate('taxRate'),
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>( // Použito DropdownButtonFormField
          value: _selectedTaxId,
          isExpanded: true,
          hint: Text(localizations.translate('selectTaxRate')),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: _taxSettings.map((tax) {
            final percent = (tax['percent'] ?? 0) * 100;
            return DropdownMenuItem<String>(
              value: tax['taxId'],
              child: Text('${tax['name']} (${percent.toStringAsFixed(0)}%)'), // Upraveno pro zobrazení procent
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedTaxId = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildOnSaleSwitch(AppLocalizations localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(localizations.translate('onSale'),
            style: const TextStyle(fontSize: 16)),
        Switch(
          value: _onSale,
          onChanged: (value) {
            setState(() {
              _onSale = value;
            });
          },
        ),
      ],
    );
  }

  Future<void> _saveProduct() async {
    final localizations = AppLocalizations.of(context)!;
    if (_nameController.text.isEmpty ||
        _sellingPriceController.text.isEmpty ||
        _selectedCategoryId == null ||
        _selectedTaxId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('fillAllFields'))),
      );
      return;
    }

    final bool isCreating = (widget.product == null || widget.isCopy);
    final itemId = isCreating ? '' : (widget.product?.itemId ?? '');

    double? purchasePrice;
    if (_purchasePriceController.text.isNotEmpty) {
      purchasePrice = double.tryParse(_purchasePriceController.text.replaceAll(',', '.')); // Handle comma as decimal separator
      if (purchasePrice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate('invalidPurchasePriceFormat'))), // PŘIDAT DO LOKALIZACE
        );
        return;
      }
    }

    double? sellingPrice = double.tryParse(_sellingPriceController.text.replaceAll(',', '.'));
    if (sellingPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('invalidSellingPriceFormat'))), // PŘIDAT DO LOKALIZACE
      );
      return;
    }

    final newProduct = Product(
      itemId: itemId,
      itemName: _nameController.text,
      sellingPrice: sellingPrice,
      purchasePrice: purchasePrice,
      sku: _skuController.text,
      code: int.tryParse(_codeController.text) ?? 0,
      note: _noteController.text,
      categoryId: _selectedCategoryId!,
      categoryName: widget.categories
          .firstWhere((c) => c['categoryId'] == _selectedCategoryId, orElse: () => {'name': 'Unknown'})['name'],
      currency: 'CZK', // Mělo by být konfigurovatelné
      taxId: _selectedTaxId!,
      color: _selectedColor,
      onSale: _onSale,
    );

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    try {
      if (isCreating) {
        await productProvider.addProduct(newProduct);
      } else {
        await productProvider.editProduct(newProduct);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving product: $e')), // Obecná chybová hláška
        );
      }
    }
  }
}