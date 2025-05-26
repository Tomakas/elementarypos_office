// lib/screens/edit_product_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product_model.dart'; // Ujistěte se, že tento import existuje
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
  int _selectedColor = 1; // Výchozí barva (klíč 1)
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
      _selectedColor = widget.product!.color; // Načtení barvy z produktu
      _onSale = widget.product!.onSale;
    }
  }

  Future<void> _loadTaxSettings() async {
    try {
      final storedApiKey = await StorageService.getApiKey();
      if (storedApiKey == null || storedApiKey.isEmpty) {
        print('Error: API key not available.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.translate('apiKeyMissingError'))), // Přidat do lokalizace
          );
        }
        return;
      }

      final taxSettings = await ApiService.fetchTaxSettings();
      if (mounted) {
        setState(() {
          _taxSettings = taxSettings;
          // Pokud produkt existuje a jeho taxId není v načtených, nebo pokud se vytváří nový produkt a není vybráno žádné taxId,
          // můžeme zkusit nastavit výchozí (pokud existují nějaké daňové sazby)
          if (_taxSettings.isNotEmpty && (_selectedTaxId == null || _taxSettings.every((tax) => tax['taxId'] != _selectedTaxId))) {
            if (widget.product == null || widget.isCopy) { // Pro nový produkt nebo kopii
              _selectedTaxId = _taxSettings.first['taxId'];
            } else if (widget.product != null && !_taxSettings.any((tax) => tax['taxId'] == widget.product!.taxId)) {
              // Produkt má taxId, které není v seznamu (např. bylo smazáno), můžeme ho resetovat nebo nechat
              // Prozatím necháme, uživatel si musí vybrat nové, pokud chce změnit.
            }
          }
        });
      }
    } catch (e) {
      print('Error loading tax settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.translate('errorLoadingTaxSettings'))), // Přidat do lokalizace
        );
      }
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
                  localizations.translate('sellingPriceLabel'),
                  _sellingPriceController,
                  isNumber: true),
              const SizedBox(height: 16),
              _buildTextField(
                  localizations.translate('purchasePriceLabel'),
                  _purchasePriceController,
                  isNumber: true),
              const SizedBox(height: 16),
              _buildCategoryDropdown(localizations),
              const SizedBox(height: 16),
              _buildColorPickerRow(localizations), // Použije upravenou metodu
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
            hintText: label, // Můžete změnit na specifičtější placeholder
            filled: true,
            fillColor: Colors.white70,
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
        DropdownButtonFormField<String>(
          value: _selectedCategoryId,
          isExpanded: true,
          hint: Text(localizations.translate('selectCategory')),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white70,
          ),
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
          validator: (value) => value == null || value.isEmpty ? localizations.translate('fieldRequiredError') : null,
        ),
      ],
    );
  }

  Widget _buildColorPickerRow(AppLocalizations localizations) {
    // Použijeme productColors z product_model.dart
    final List<MapEntry<int, Color>> colorEntries = productColors.entries.toList();
    // Seřadíme podle klíče pro konzistentní pořadí
    colorEntries.sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.translate('color'),
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: colorEntries.map((entry) {
              final int colorKey = entry.key; // Klíč barvy (1-8)
              final Color colorValue = entry.value; // Hodnota barvy

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedColor = colorKey; // Uložíme klíč (1-8)
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: colorValue, // Použijeme barvu z mapy
                    shape: BoxShape.circle,
                    border: _selectedColor == colorKey
                        ? Border.all(color: Colors.black, width: 3)
                        : Border.all(color: Colors.grey.shade300, width: 1), // Tenký okraj pro neaktivní
                  ),
                  child: _selectedColor == colorKey
                      ? const Icon(Icons.check, color: Colors.white, size: 20) // Checkmark pro vybranou barvu
                      : null,
                ),
              );
            }).toList(),
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
        DropdownButtonFormField<String>(
          value: _selectedTaxId,
          isExpanded: true,
          hint: Text(localizations.translate('selectTaxRate')),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white70,
          ),
          items: _taxSettings.map((tax) {
            final percent = (tax['percent'] ?? 0) * 100;
            return DropdownMenuItem<String>(
              value: tax['taxId'],
              child: Text('${tax['name']} (${percent.toStringAsFixed(0)}%)'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedTaxId = value;
            });
          },
          validator: (value) => value == null || value.isEmpty ? localizations.translate('fieldRequiredError') : null,
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
          activeColor: Theme.of(context).primaryColor,
        ),
      ],
    );
  }

  Future<void> _saveProduct() async {
    final localizations = AppLocalizations.of(context)!;
    // Základní validace formuláře (pokud používáte GlobalKey<FormState>)
    // if (!_formKey.currentState!.validate()) { return; }

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
    // Při vytváření nového produktu (isCopy=true nebo product=null) itemId by měl být prázdný nebo generován API
    // Pokud kopírujeme, chceme vytvořit nový produkt, takže itemId by měl být nový.
    // API by mělo samo generovat itemId pro nový produkt. Pokud editujeme, používáme existující.
    final String itemId = (isCreating || widget.isCopy) ? '' : (widget.product?.itemId ?? '');


    double? purchasePrice;
    if (_purchasePriceController.text.isNotEmpty) {
      purchasePrice = double.tryParse(_purchasePriceController.text.replaceAll(',', '.'));
      if (purchasePrice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate('invalidPurchasePriceFormat'))),
        );
        return;
      }
    }

    double? sellingPrice = double.tryParse(_sellingPriceController.text.replaceAll(',', '.'));
    if (sellingPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('invalidSellingPriceFormat'))),
      );
      return;
    }

    int productCode;
    if (_codeController.text.isNotEmpty) {
      productCode = int.tryParse(_codeController.text) ?? 0;
    } else {
      productCode = 0; // Nebo jiná výchozí hodnota, pokud je kód nepovinný a může být 0
    }


    final newProduct = Product(
      itemId: itemId, // Pro nový produkt prázdný, API přidělí ID
      itemName: _nameController.text,
      sellingPrice: sellingPrice,
      purchasePrice: purchasePrice,
      sku: _skuController.text.isNotEmpty ? _skuController.text : null, // SKU může být null
      code: productCode,
      note: _noteController.text.isNotEmpty ? _noteController.text : null, // Poznámka může být null
      categoryId: _selectedCategoryId!,
      categoryName: widget.categories
          .firstWhere((c) => c['categoryId'] == _selectedCategoryId, orElse: () => {'name': 'Unknown'})['name'],
      currency: 'CZK', // Mělo by být konfigurovatelné nebo z nastavení
      taxId: _selectedTaxId!,
      color: _selectedColor,
      onSale: _onSale,
    );

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    try {
      if (isCreating || widget.isCopy) { // Pokud je isCopy, taky přidáváme nový produkt
        await productProvider.addProduct(newProduct);
      } else {
        await productProvider.editProduct(newProduct);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isCreating || widget.isCopy ? localizations.translate('productAddedSuccess') : localizations.translate('productEditedSuccess'))), // Přidat do lokalizace
        );
        Navigator.of(context).pop(true); // Signalizuje úspěch zpět na ProductListScreen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.translate("errorSavingProduct")}: $e')),
        );
      }
    }
  }
}