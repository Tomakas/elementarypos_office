// lib/widgets/purchase_item_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elementarypos_office/l10n/app_localizations.dart';
import 'package:elementarypos_office/models/ui_purchase_item_model.dart';
import 'package:elementarypos_office/models/product_model.dart';
import 'package:elementarypos_office/providers/product_provider.dart';
import 'package:elementarypos_office/services/utility_services.dart';
import 'package:uuid/uuid.dart';

// Funkce, která zobrazí dialog
Future<UIPurchaseItem?> showPurchaseItemDialog({
  required BuildContext context,
  required AppLocalizations localizations,
  UIPurchaseItem? existingItem,
}) async {
  return showDialog<UIPurchaseItem>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      // Předáme dialogContext pro případné použití (např. SnackBar)
      return _PurchaseItemDialogWidget(
        localizations: localizations,
        existingItem: existingItem,
        dialogContext: dialogContext,
      );
    },
  );
}

// Samotný StatefulWidget pro obsah dialogu
class _PurchaseItemDialogWidget extends StatefulWidget {
  final AppLocalizations localizations;
  final UIPurchaseItem? existingItem;
  final BuildContext dialogContext; // Kontext z showDialog pro SnackBar apod.

  const _PurchaseItemDialogWidget({
    required this.localizations,
    this.existingItem,
    required this.dialogContext,
  });

  @override
  State<_PurchaseItemDialogWidget> createState() => _PurchaseItemDialogWidgetState();
}

class _PurchaseItemDialogWidgetState extends State<_PurchaseItemDialogWidget> {
  final _formKeyDialog = GlobalKey<FormState>();
  late UIPurchaseItem _itemData;

  late TextEditingController _productNameController;
  late TextEditingController _quantityController;
  late TextEditingController _totalItemPriceController;
  late FocusNode _totalItemPriceFocusNode;

  bool _isLoadingProducts = false;
  List<Product> _availableProducts = [];
  late ProductProvider _productProvider;

  @override
  void initState() {
    super.initState();
    _itemData = widget.existingItem ?? UIPurchaseItem(id: Uuid().v4());

    _productNameController = TextEditingController(text: _itemData.productName);
    _quantityController = TextEditingController(text: _itemData.quantity != 0 ? _itemData.quantity.toString() : '');
    _totalItemPriceController = TextEditingController(text: _itemData.totalItemPrice?.toStringAsFixed(2) ?? '');
    _totalItemPriceFocusNode = FocusNode();

    _productProvider = Provider.of<ProductProvider>(context, listen: false);
    _availableProducts = _productProvider.products.toList();

    // Načtení produktů, pokud je to nutné
    // addPostFrameCallback zajistí, že se to stane po prvním buildu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProductsIfNeeded();
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _totalItemPriceController.dispose();
    _totalItemPriceFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProductsIfNeeded() async {
    if (!mounted) return; // Klíčová kontrola

    if (_productProvider.products.isEmpty && !_isLoadingProducts) {
      setState(() {
        _isLoadingProducts = true;
      });
      try {
        await _productProvider.fetchProducts();
        if (!mounted) return; // Kontrola po await
        _availableProducts = _productProvider.products.toList();
      } catch (e) {
        print("Chyba při načítání produktů v dialogu: $e");
        if (mounted) { // Kontrola před zobrazením SnackBar
          ScaffoldMessenger.of(widget.dialogContext).showSnackBar( // Použití předaného dialogContext
            SnackBar(content: Text(widget.localizations.translate('errorLoadingData'))),
          );
        }
      } finally {
        if (mounted) { // Kontrola před finálním setState
          setState(() {
            _isLoadingProducts = false;
          });
        }
      }
    } else if (_productProvider.products.isNotEmpty && _availableProducts.isEmpty) {
      if (!mounted) return;
      _availableProducts = _productProvider.products.toList();
      // Není potřeba volat setState, pokud jen kopírujeme data a isLoadingProducts je false
      if (_isLoadingProducts) { // Pokud by náhodou bylo true
        setState(() { _isLoadingProducts = false; });
      }
    }
  }

  void _handlePriceCalculation() {
    _itemData.quantity = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0;
    _itemData.totalItemPrice = double.tryParse(_totalItemPriceController.text.replaceAll(',', '.')) ?? 0.0;

    if (_itemData.quantity > 0 && _itemData.totalItemPrice != null) {
      _itemData.unitPrice = _itemData.totalItemPrice! / _itemData.quantity;
    } else if (_itemData.totalItemPrice != null && _itemData.quantity == 0) {
      _itemData.unitPrice = 0;
    } else {
      _itemData.unitPrice = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Context zde je z _PurchaseItemDialogWidgetState, je platný
    return AlertDialog(
      title: Text(widget.existingItem == null
          ? widget.localizations.translate('addProductItem')
          : widget.localizations.translate('editProductItem')),
      content: Form(
        key: _formKeyDialog,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(widget.localizations.translate('product'), style: TextStyle(fontWeight: FontWeight.bold)),
              if (_isLoadingProducts)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_isLoadingProducts)
                Autocomplete<Product>(
                  initialValue: TextEditingValue(text: _itemData.productName),
                  displayStringForOption: (Product option) => option.itemName,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.length < 3) {
                      return const Iterable<Product>.empty();
                    }
                    return _availableProducts.where((Product option) {
                      final normalizedOption = Utility.normalizeString(option.itemName.toLowerCase());
                      final normalizedQuery = Utility.normalizeString(textEditingValue.text.toLowerCase());
                      return normalizedOption.contains(normalizedQuery);
                    });
                  },
                  fieldViewBuilder: (BuildContext context, TextEditingController fieldController,
                      FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                    // Synchronizujeme text _productNameController s fieldController, pokud se liší
                    // To je důležité, pokud Autocomplete widget změní text ve fieldController
                    if (_productNameController.text != fieldController.text) {
                      WidgetsBinding.instance.addPostFrameCallback((_) { // Aktualizace v dalším frame
                        if (mounted) {
                          _productNameController.text = fieldController.text;
                          _itemData.productName = fieldController.text;
                        }
                      });
                    }
                    return TextFormField(
                      controller: fieldController,
                      focusNode: fieldFocusNode,
                      decoration: InputDecoration(
                        hintText: widget.localizations.translate('selectProduct'),
                        filled: true, fillColor: Colors.white, border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty ? widget.localizations.translate('fieldRequiredError') : null,
                      onChanged: (value) {
                        if (!mounted) return;
                        _itemData.productName = value;
                        _productNameController.text = value; // Udržujeme náš controller synchronizovaný
                        setState(() {}); // Aby se optionsBuilder mohl aktualizovat
                      },
                    );
                  },
                  onSelected: (Product selection) {
                    if (!mounted) return;
                    setState(() {
                      _itemData.productName = selection.itemName;
                      _productNameController.text = selection.itemName;

                      _itemData.quantity = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1.0;
                      if (_quantityController.text.isEmpty && _itemData.quantity == 1.0) {
                        _quantityController.text = "1";
                      }

                      if (selection.purchasePrice != null && _itemData.quantity > 0) {
                        _itemData.totalItemPrice = selection.purchasePrice! * _itemData.quantity;
                        _totalItemPriceController.text = _itemData.totalItemPrice!.toStringAsFixed(2);
                        _handlePriceCalculation();
                      } else {
                        _itemData.totalItemPrice = null;
                        _totalItemPriceController.clear();
                        _handlePriceCalculation();
                      }
                    });
                  },
                  optionsViewBuilder: (BuildContext optContext, AutocompleteOnSelected<Product> onSelected, Iterable<Product> options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 350, maxWidth: fieldViewBuilderMaxWidth(optContext, widget.dialogContext) -40 ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext lvContext, int index) {
                              final Product option = options.elementAt(index);
                              return InkWell(
                                onTap: () {
                                  onSelected(option);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(option.itemName, style: Theme.of(lvContext).textTheme.bodyLarge ?? const TextStyle(color: Colors.black)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),

              Text(widget.localizations.translate('quantity'), style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(hintText: widget.localizations.translate('enterQuantity'), filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return widget.localizations.translate('fieldRequiredError');
                  final qty = double.tryParse(value.replaceAll(',', '.'));
                  if (qty == null || qty <= 0) return widget.localizations.translate('invalidQuantityError');
                  return null;
                },
                onChanged: (value) {
                  if (!mounted) return;
                  _handlePriceCalculation();
                  setState((){});
                },
              ),
              const SizedBox(height: 12),

              Text(widget.localizations.translate('totalItemPrice'), style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _totalItemPriceController,
                focusNode: _totalItemPriceFocusNode,
                decoration: InputDecoration(hintText: widget.localizations.translate('enterTotalItemPrice'), filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return widget.localizations.translate('fieldRequiredError');
                  final price = double.tryParse(value.replaceAll(',', '.'));
                  if (price == null || price < 0) return widget.localizations.translate('invalidPriceError');
                  return null;
                },
                onChanged: (value) {
                  if (!mounted) return;
                  _handlePriceCalculation();
                  setState((){});
                },
              ),
              if (_itemData.unitPrice != null && _itemData.quantity > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${widget.localizations.translate('unitPrice')}: ${Utility.formatCurrency(_itemData.unitPrice!, currencySymbol: widget.localizations.translate('currency'), decimals: 2)} ${widget.localizations.translate('perUnitAbbreviation')}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(widget.localizations.translate('cancel')),
          onPressed: () {
            Navigator.of(widget.dialogContext).pop(); // Použití předaného dialogContext
          },
        ),
        ElevatedButton(
          child: Text(widget.localizations.translate(widget.existingItem == null ? 'add' : 'saveChanges')),
          onPressed: () {
            if (_formKeyDialog.currentState!.validate()) {
              _handlePriceCalculation(); // Ujistíme se, že _itemData je aktuální

              if (_itemData.totalItemPrice == null && _itemData.quantity > 0) {
                ScaffoldMessenger.of(widget.dialogContext).showSnackBar( // Použití předaného dialogContext
                  SnackBar(content: Text(widget.localizations.translate('priceMissingForItemError'))),
                );
                return;
              }
              // Při ukládání se ujistíme, že _productNameController je synchronizován s _itemData.productName
              // Toto by mělo být již zajištěno v onSelected a onChanged Autocomplete,
              // ale pro jistotu můžeme explicitně přiřadit z _productNameController, pokud byl upraven přímo
              // (což by nemělo nastat, pokud fieldController z Autocomplete je hlavní).
              // _itemData.productName = _productNameController.text;

              Navigator.of(widget.dialogContext).pop(_itemData); // Použití předaného dialogContext
            }
          },
        ),
      ],
    );
  }
}

// Funkce fieldViewBuilderMaxWidth zůstává stejná
double fieldViewBuilderMaxWidth(BuildContext context, BuildContext dialogContext) {
  double dialogWidth = MediaQuery.of(dialogContext).size.width;
  final RenderBox? renderBox = dialogContext.findRenderObject() as RenderBox?;
  if (renderBox != null && renderBox.hasSize) {
    dialogWidth = renderBox.size.width;
  } else {
    dialogWidth = MediaQuery.of(context).size.width;
  }

  if (dialogWidth > 600) {
    return 500;
  }
  return dialogWidth * 0.9 - 40;
}

// Funkce _highlightOccurrences je prozatím odstraněna