import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../services/utility_services.dart'; // Důležité pro načtení API klíče ze StorageService

class EditProductScreen extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final Product? product;
  final bool isCopy; // Nový parametr

  const EditProductScreen({
    super.key,
    required this.categories,
    this.product,
    this.isCopy = false, // Defaultně false
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
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTaxSettings();

    // Rozlišení mezi edit, new a copy:
    if (widget.product != null) {
      // a) je to EDIT (widget.isCopy == false)
      // b) je to COPY (widget.isCopy == true)
      //
      // V obou případech vyplníme formulář daty z původního produktu
      _nameController.text = widget.product!.itemName;
      _priceController.text = widget.product!.price.toStringAsFixed(2);
      _skuController.text = widget.product!.sku ?? '';
      _codeController.text = widget.product!.code.toString();
      _noteController.text = widget.product!.note ?? '';
      _selectedCategoryId = widget.product!.categoryId;
      _selectedTaxId = widget.product!.taxId;
      _selectedColor = widget.product!.color;
      _onSale = widget.product!.onSale;

      // Pokud je to COPY, vynulujeme itemId,
      // aby API bralo tento produkt jako nový (a vygenerovalo nové itemId).
      if (widget.isCopy) {
        // Případně vynulování dalších polí, pokud by bylo žádoucí.
      }
    }
    // Pokud je product == null => je to nový produkt -> formulář je prázdný
  }

  Future<void> _loadTaxSettings() async {
    try {
      final storedApiKey = await StorageService.getApiKey();
      if (storedApiKey == null || storedApiKey.isEmpty) {
        print('Error: API klíč není k dispozici.');
        return;
      }

      final taxSettings = await ApiService.fetchTaxSettings(storedApiKey);
      setState(() {
        _taxSettings = taxSettings;
      });
    } catch (e) {
      print('Error loading tax settings: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _skuController.dispose();
    _codeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // Nastavíme nadpis obrazovky
    // 1) Pokud product == null => "Vytvoření produktu"
    // 2) Pokud product != null && isCopy => "Vytvoření produktu" (kopie)
    // 3) Jinak => "Upravit produkt"
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
              _buildTextField(localizations.translate('productName'), _nameController),
              const SizedBox(height: 16),
              _buildTextField(localizations.translate('price'), _priceController, isNumber: true),
              const SizedBox(height: 16),
              _buildCategoryDropdown(localizations),
              const SizedBox(height: 16),
              _buildColorPickerRow(localizations),
              const SizedBox(height: 16),
              _buildOnSaleSwitch(localizations),
              const SizedBox(height: 16),
              // SKU lze nyní zadávat jako běžný text (může obsahovat písmena, symboly atd.)
              _buildTextField(localizations.translate('sku'), _skuController),
              const SizedBox(height: 16),
              _buildTextField(localizations.translate('productCode'), _codeController, isNumber: true),
              const SizedBox(height: 16),
              _buildTaxDropdown(localizations),
              const SizedBox(height: 16),
              _buildTextField(localizations.translate('note'), _noteController, isMultiline: true),
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
        Text(localizations.translate('category'), style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: _selectedCategoryId,
          isExpanded: true,
          hint: Text(localizations.translate('selectCategory')),
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
      Colors.green,
      Colors.lightBlue,
      Colors.blue,
      Colors.yellow,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.brown.shade300,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.translate('color'), style: const TextStyle(fontSize: 16)),
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
        Text(localizations.translate('taxRate'), style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButton<String>(
          value: _selectedTaxId,
          isExpanded: true,
          hint: Text(localizations.translate('selectTaxRate')),
          items: _taxSettings.map((tax) {
            final percent = (tax['percent'] ?? 0) * 100;
            return DropdownMenuItem<String>(
              value: tax['taxId'],
              child: Text('${tax['name']} (${percent}%)'),
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
        Text(localizations.translate('onSale'), style: const TextStyle(fontSize: 16)),
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

    // Základní validace
    if (_nameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _selectedCategoryId == null ||
        _selectedTaxId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('fillAllFields'))),
      );
      return;
    }

    // Rozhodneme, zda se jedná o novou entitu nebo editaci
    final bool isCreating = (widget.product == null || widget.isCopy);

    // Pokud je to nová entita => itemId prázdný (aby se na serveru vytvořil nový)
    final itemId = isCreating ? '' : (widget.product?.itemId ?? '');
    final newProduct = Product(
      itemId: itemId,
      itemName: _nameController.text,
      price: double.parse(_priceController.text),
      sku: _skuController.text,   // SKU jako string
      code: int.tryParse(_codeController.text) ?? 0,
      note: _noteController.text,
      categoryId: _selectedCategoryId!,
      categoryName: widget.categories
          .firstWhere((c) => c['categoryId'] == _selectedCategoryId)['name'],
      currency: 'CZK',
      taxId: _selectedTaxId!,
      color: _selectedColor,
      onSale: _onSale,
    );

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    if (isCreating) {
      // Vytvoření nového produktu
      await productProvider.addProduct(newProduct);
    } else {
      // Editace stávajícího produktu
      await productProvider.editProduct(newProduct);
    }

    Navigator.of(context).pop(true); // Vrátíme se s hodnotou true => "došlo ke změně"
  }
}
