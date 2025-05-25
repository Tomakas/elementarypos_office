// lib/widgets/purchase_item_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elementarypos_office/l10n/app_localizations.dart';
import 'package:elementarypos_office/models/ui_purchase_item_model.dart';
import 'package:elementarypos_office/models/product_model.dart';
import 'package:elementarypos_office/providers/product_provider.dart';
import 'package:elementarypos_office/services/utility_services.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

// Enum pro akce dialogu
enum PurchaseItemDialogAction { save, delete, cancel }

enum PriceInputType { unit, total } // <<== PŘIDÁNO ZDE

// Třída pro výsledek dialogu
class PurchaseItemDialogResult {
  final PurchaseItemDialogAction action;
  final UIPurchaseItem? item; // Relevantní pro 'save', může být i pro 'delete' k identifikaci

  PurchaseItemDialogResult(this.action, {this.item});
}


Future<PurchaseItemDialogResult?> showPurchaseItemDialog({ // Změna návratového typu
  required BuildContext context,
  required AppLocalizations localizations,
  UIPurchaseItem? existingItem,
}) async {
  return showDialog<PurchaseItemDialogResult>( // Změna návratového typu
    context: context,
    barrierDismissible: false, // Uživatel musí explicitně zvolit akci
    builder: (BuildContext dialogContext) {
      return _PurchaseItemDialogWidget(
        localizations: localizations,
        existingItem: existingItem,
        dialogContext: dialogContext,
      );
    },
  );
}

class _PurchaseItemDialogWidget extends StatefulWidget {
  final AppLocalizations localizations;
  final UIPurchaseItem? existingItem;
  final BuildContext dialogContext;

  const _PurchaseItemDialogWidget({
    required this.localizations,
    this.existingItem,
    required this.dialogContext,
  });

  @override
  State<_PurchaseItemDialogWidget> createState() =>
      _PurchaseItemDialogWidgetState();
}

class _PurchaseItemDialogWidgetState extends State<_PurchaseItemDialogWidget> {
  final _formKeyDialog = GlobalKey<FormState>();
  late UIPurchaseItem _itemData;
  late TextEditingController _productNameController;
  late TextEditingController _quantityController;
  late TextEditingController _priceInputController;
  late FocusNode _priceInputFocusNode;

  PriceInputType _currentPriceInputType = PriceInputType.unit;

  bool _isLoadingProducts = false;
  List<Product> _availableProducts = [];
  late ProductProvider _productProvider;

  Product? _selectedProduct;
  double? _currentSellingPrice;
  double? _storedPurchasePrice;
  double? _calculatedMarginAmount;
  double? _calculatedMarginPercentage;

  bool _showPriceChangeInfo = false;
  double? _previousUnitPriceForInfo;
  double? _originalMarginAmountForInfo;
  double? _originalMarginPercentageForInfo;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _itemData = UIPurchaseItem( // Vytvoření kopie pro editaci
        id: widget.existingItem!.id,
        productId: widget.existingItem!.productId,
        productName: widget.existingItem!.productName,
        quantity: widget.existingItem!.quantity == 0 ? 1.0 : widget.existingItem!.quantity,
        unitPrice: widget.existingItem!.unitPrice,
        totalItemPrice: widget.existingItem!.totalItemPrice,
      );
    } else {
      _itemData = UIPurchaseItem(id: Uuid().v4(), productId: '', quantity: 1.0);
    }

    _productNameController = TextEditingController(text: _itemData.productName);
    _quantityController = TextEditingController(text: _formatQuantityForDisplay(_itemData.quantity));
    _priceInputController = TextEditingController();
    _priceInputFocusNode = FocusNode();

    _productProvider = Provider.of<ProductProvider>(context, listen: false);
    _availableProducts = _productProvider.products.toList();

    if (widget.existingItem != null && widget.existingItem!.productId.isNotEmpty) {
      _selectedProduct = _productProvider.getProductById(widget.existingItem!.productId);
      if (_selectedProduct != null) {
        _currentSellingPrice = _selectedProduct!.sellingPrice;
        _storedPurchasePrice = _productProvider.getStoredPurchasePrice(_selectedProduct!.itemId);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProductsIfNeeded();
      _synchronizePricesAndRecalculateAll(isInitializing: true);
    });
  }

  String _formatQuantityForDisplay(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    final formatter = NumberFormat("#,##0.###", widget.localizations.locale.languageCode);
    return formatter.format(qty);
  }

  String _formatPriceValueForDisplay(double? value) {
    if (value == null) return '';
    final formatter = NumberFormat("###0.##", widget.localizations.locale.languageCode);
    return formatter.format(value);
  }


  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _priceInputController.dispose();
    _priceInputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProductsIfNeeded() async {
    if (!mounted) return;
    if (_productProvider.products.isEmpty && !_isLoadingProducts) {
      setState(() => _isLoadingProducts = true);
      try {
        await _productProvider.fetchAllProductData();
        if (!mounted) return;
        _availableProducts = _productProvider.products.toList();
      } catch (e) {
        print("Chyba při načítání produktů v dialogu: $e");
        if (mounted) {
          ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
            SnackBar(
                content:
                Text(widget.localizations.translate('errorLoadingData'))),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoadingProducts = false);
      }
    } else if (_productProvider.products.isNotEmpty &&
        _availableProducts.isEmpty) {
      if (!mounted) return;
      _availableProducts = _productProvider.products.toList();
      if (_isLoadingProducts && mounted) {
        setState(() => _isLoadingProducts = false);
      }
    }
  }

  void _synchronizePricesAndRecalculateAll({
    bool priceFieldActive = false,
    bool quantityFieldActive = false,
    bool priceModeToggled = false,
    bool modelPreFilled = false,
    bool isInitializing = false
  }) {
    if (!mounted) return;

    double currentQuantityFromController = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? _itemData.quantity;
    if(currentQuantityFromController <= 0 && !isInitializing) currentQuantityFromController = 1.0;
    _itemData.quantity = currentQuantityFromController;

    double enteredPriceInField = double.tryParse(_priceInputController.text.replaceAll(',', '.')) ?? 0.0;

    if (priceFieldActive) {
      if (_currentPriceInputType == PriceInputType.unit) {
        _itemData.unitPrice = enteredPriceInField;
      } else {
        _itemData.totalItemPrice = enteredPriceInField;
      }
    }

    // Přepočet druhé ceny na základě aktuálního módu a hodnot v _itemData
    if (_currentPriceInputType == PriceInputType.unit) {
      if (_itemData.unitPrice != null && _itemData.quantity > 0) {
        _itemData.totalItemPrice = _itemData.unitPrice! * _itemData.quantity;
      } else if (_itemData.unitPrice != null) {
        _itemData.totalItemPrice = _itemData.unitPrice;
      } else {
        _itemData.totalItemPrice = null;
      }
    } else { // PriceInputType.total
      if (_itemData.totalItemPrice != null && _itemData.quantity > 0) {
        _itemData.unitPrice = _itemData.totalItemPrice! / _itemData.quantity;
      } else if (_itemData.totalItemPrice != null) {
        _itemData.unitPrice = _itemData.totalItemPrice;
      } else {
        _itemData.unitPrice = null;
      }
    }

    if (isInitializing || priceModeToggled || modelPreFilled || quantityFieldActive || priceFieldActive /* Vždy chceme formátovat po změně */) {
      String priceStringToDisplay;
      if (_currentPriceInputType == PriceInputType.unit) {
        priceStringToDisplay = _formatPriceValueForDisplay(_itemData.unitPrice);
      } else {
        priceStringToDisplay = _formatPriceValueForDisplay(_itemData.totalItemPrice);
      }
      if (_priceInputController.text != priceStringToDisplay) {
        // Uložíme pozici kurzoru
        final currentSelection = _priceInputController.selection;
        _priceInputController.text = priceStringToDisplay;
        // Obnovíme pozici kurzoru, pokud je to možné a relevantní
        if(currentSelection.start <= _priceInputController.text.length && currentSelection.end <= _priceInputController.text.length) {
          _priceInputController.selection = currentSelection;
        } else {
          _priceInputController.selection = TextSelection.fromPosition(TextPosition(offset: _priceInputController.text.length));
        }
      }
    }

    if (_currentSellingPrice != null && _itemData.unitPrice != null) {
      _calculatedMarginAmount = _currentSellingPrice! - _itemData.unitPrice!;
      _calculatedMarginPercentage = (_currentSellingPrice! > 0)
          ? (_calculatedMarginAmount! / _currentSellingPrice!) * 100
          : null;
      if(_currentSellingPrice! <=0) _calculatedMarginPercentage = null;
    } else {
      _calculatedMarginAmount = null;
      _calculatedMarginPercentage = null;
    }

    _showPriceChangeInfo = false;
    _originalMarginAmountForInfo = null;
    _originalMarginPercentageForInfo = null;

    if (_storedPurchasePrice != null &&
        _itemData.unitPrice != null &&
        (_itemData.unitPrice! - _storedPurchasePrice!).abs() > 0.001) {
      _showPriceChangeInfo = true;
      _previousUnitPriceForInfo = _storedPurchasePrice;

      if (_currentSellingPrice != null) {
        _originalMarginAmountForInfo = _currentSellingPrice! - _storedPurchasePrice!;
        _originalMarginPercentageForInfo = (_currentSellingPrice! > 0)
            ? (_originalMarginAmountForInfo! / _currentSellingPrice!) * 100
            : null;
        if(_currentSellingPrice! <=0) _originalMarginPercentageForInfo = null;
      }
    }
    if(mounted) setState(() {});
  }

  void _onPriceTypeToggle(int index) {
    if (!mounted) return;
    PriceInputType newMode = PriceInputType.values[index];
    if (newMode == _currentPriceInputType) return;

    setState(() { // Pouze pro změnu _currentPriceInputType
      _currentPriceInputType = newMode;
    });
    // Po změně módu zavoláme synchronizaci, která aktualizuje text controlleru a přepočítá ceny
    _synchronizePricesAndRecalculateAll(priceModeToggled: true);
  }

  void _incrementQuantity() {
    double currentQty = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? _itemData.quantity;
    if (currentQty < 0) currentQty = 0;
    currentQty += 1.0;
    _quantityController.text = _formatQuantityForDisplay(currentQty);
    _synchronizePricesAndRecalculateAll(quantityFieldActive: true);
    _formKeyDialog.currentState?.validate();
  }

  void _decrementQuantity() {
    double currentQty = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? _itemData.quantity;
    if (currentQty - 1.0 >= 1.0) {
      currentQty -= 1.0;
    } else {
      currentQty = 1.0;
    }
    _quantityController.text = _formatQuantityForDisplay(currentQty);
    _synchronizePricesAndRecalculateAll(quantityFieldActive: true);
    _formKeyDialog.currentState?.validate();
  }

  Future<void> _onDeletePressed() async {
    final confirmed = await showDialog<bool>(
      context: widget.dialogContext, // Použijeme context dialogu, nad kterým se zobrazí potvrzení
      builder: (BuildContext confirmCtx) {
        return AlertDialog(
          title: Text(widget.localizations.translate('confirmDeleteItemTitle')), // Nový klíč
          content: Text(widget.localizations.translate('confirmDeleteItemMessage')), // Nový klíč
          actions: <Widget>[
            TextButton(
              child: Text(widget.localizations.translate('cancel')),
              onPressed: () => Navigator.of(confirmCtx).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(widget.localizations.translate('delete')),
              onPressed: () => Navigator.of(confirmCtx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Zavřeme hlavní dialog (PurchaseItemDialog) a vrátíme akci smazání
      Navigator.of(widget.dialogContext).pop(PurchaseItemDialogResult(PurchaseItemDialogAction.delete, item: widget.existingItem));
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceInputLabel = _currentPriceInputType == PriceInputType.unit
        ? widget.localizations.translate('unitPrice')
        : widget.localizations.translate('totalItemPrice');

    final String currencySymbol = widget.localizations.translate('currency');

    List<Widget> dialogActions = [
      TextButton(
        child: Text(widget.localizations.translate('cancel')),
        onPressed: () {
          Navigator.of(widget.dialogContext).pop(PurchaseItemDialogResult(PurchaseItemDialogAction.cancel));
        },
      ),
    ];

    if (widget.existingItem != null) {
      dialogActions.insert(
        0, // Přidáme na začátek (nebo kamkoliv chcete)
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
          onPressed: _onDeletePressed,
          child: Text(widget.localizations.translate('delete')),
        ),
      );
    }

    dialogActions.add(
        ElevatedButton(
          child: Text(widget.localizations.translate(
              widget.existingItem == null ? 'add' : 'saveChanges')),
          onPressed: () {
            if (_formKeyDialog.currentState!.validate()) {
              _synchronizePricesAndRecalculateAll(priceFieldActive: true, quantityFieldActive: true); // Finální synchronizace

              if ((_itemData.productId.isEmpty && _selectedProduct == null)) {
                ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
                  SnackBar(content: Text(widget.localizations.translate('selectProductError'))),
                );
                return;
              }

              final qty = _itemData.quantity;
              if (qty <= 0) {
                ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
                  SnackBar(content: Text(widget.localizations.translate('invalidQuantityError'))),
                );
                return;
              }
              if ((_itemData.unitPrice == null || _itemData.totalItemPrice == null) || (_itemData.unitPrice! < 0 || _itemData.totalItemPrice! < 0)) {
                ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
                  SnackBar(content: Text(widget.localizations.translate('priceMissingForItemError'))),
                );
                return;
              }
              Navigator.of(widget.dialogContext).pop(PurchaseItemDialogResult(PurchaseItemDialogAction.save, item: _itemData));
            }
          },
        )
    );


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
              // ... (UI pro produkt, marži, množství, cenu - zůstává stejné jako v předchozí odpovědi)
              Text(widget.localizations.translate('product'),
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                    if (textEditingValue.text.length < 2) {
                      return const Iterable<Product>.empty();
                    }
                    return _availableProducts.where((Product option) {
                      final normalizedOption = Utility.normalizeString(option.itemName.toLowerCase());
                      final normalizedQuery = Utility.normalizeString(textEditingValue.text.toLowerCase());
                      return normalizedOption.contains(normalizedQuery);
                    });
                  },
                  fieldViewBuilder: (BuildContext context,
                      TextEditingController fieldController,
                      FocusNode fieldFocusNode,
                      VoidCallback onFieldSubmitted) {
                    if (_productNameController.text != fieldController.text) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _productNameController.text = fieldController.text;
                        }
                      });
                    }
                    return TextFormField(
                      controller: fieldController,
                      focusNode: fieldFocusNode,
                      decoration: InputDecoration(
                        hintText: widget.localizations.translate('selectProduct'),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return widget.localizations.translate('fieldRequiredError');
                        if (_itemData.productId.isEmpty && _selectedProduct == null)
                          return widget.localizations.translate('selectValidProductError');
                        return null;
                      },
                      onChanged: (value) {
                        if (!mounted) return;
                        if (_selectedProduct?.itemName != value) {
                          _itemData.productId = '';
                          _selectedProduct = null;
                          _currentSellingPrice = null;
                          _storedPurchasePrice = null;
                          _synchronizePricesAndRecalculateAll();
                        }
                        _productNameController.text = value;
                      },
                    );
                  },
                  onSelected: (Product selection) {
                    if (!mounted) return;

                    _selectedProduct = selection;
                    _itemData.productName = selection.itemName;
                    _itemData.productId = selection.itemId;
                    _productNameController.text = selection.itemName;

                    _currentSellingPrice = selection.sellingPrice;
                    _storedPurchasePrice = _productProvider.getStoredPurchasePrice(selection.itemId);

                    double currentQtyInField = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0.0;
                    if(currentQtyInField <= 0) {
                      _itemData.quantity = 1.0;
                      // _quantityController.text = "1"; // Nastaví se v _synchronizePricesAndRecalculateAll
                    } else {
                      _itemData.quantity = currentQtyInField;
                      // _quantityController.text = _formatQuantityForDisplay(currentQtyInField);
                    }

                    double? unitPriceForPreFill = _storedPurchasePrice ?? selection.purchasePrice;

                    if (unitPriceForPreFill != null) {
                      _itemData.unitPrice = unitPriceForPreFill;
                      if (_itemData.quantity > 0) {
                        _itemData.totalItemPrice = unitPriceForPreFill * _itemData.quantity;
                      } else {
                        _itemData.totalItemPrice = unitPriceForPreFill;
                      }
                    } else {
                      _itemData.unitPrice = null;
                      _itemData.totalItemPrice = null;
                    }

                    _synchronizePricesAndRecalculateAll(modelPreFilled: true, quantityFieldActive: true);
                  },
                  optionsViewBuilder: (BuildContext optContext,
                      AutocompleteOnSelected<Product> onSelected,
                      Iterable<Product> options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxHeight: 200,
                              maxWidth: fieldViewBuilderMaxWidth(optContext, widget.dialogContext) - 40),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext lvContext, int index) {
                              final Product option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal:16.0, vertical: 12.0),
                                  child: Text(option.itemName,
                                      style: Theme.of(lvContext).textTheme.titleSmall ??
                                          const TextStyle(color: Colors.black)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),

              if (_currentSellingPrice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    '${widget.localizations.translate('sellingPriceLabelDialog')}: ${Utility.formatCurrency(_currentSellingPrice!, currencySymbol: currencySymbol, trimZeroDecimals: true)}',
                    style: TextStyle(fontSize: 14, color: Colors.blueGrey[700], fontWeight: FontWeight.w500),
                  ),
                ),

              if (_calculatedMarginAmount != null && _calculatedMarginPercentage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    '${widget.localizations.translate('marginLabel')}: ${Utility.formatCurrency(_calculatedMarginAmount!, currencySymbol: currencySymbol, trimZeroDecimals: true)} (${_formatPriceValueForDisplay(_calculatedMarginPercentage)}%)',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _calculatedMarginAmount! < 0 ? Colors.red[700] : Colors.green[700]),
                  ),
                ),

              Text(widget.localizations.translate('quantity'),
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                      ),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return widget.localizations.translate('fieldRequiredError');
                        final qty = double.tryParse(value.replaceAll(',', '.'));
                        if (qty == null || qty <= 0)
                          return widget.localizations.translate('invalidQuantityError');
                        return null;
                      },
                      onChanged: (value) {
                        if (!mounted) return;
                        _synchronizePricesAndRecalculateAll(quantityFieldActive: true);
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  InkWell(
                    onTap: _decrementQuantity,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8)
                      ),
                      child: Icon(Icons.remove, size: 24, color: Colors.grey[800]),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  SizedBox(width: 6),
                  InkWell(
                    onTap: _incrementQuantity,
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8)
                      ),
                      child: Icon(Icons.add, size: 24, color: Colors.grey[800]),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(priceInputLabel, style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _priceInputController,
                      focusNode: _priceInputFocusNode,
                      decoration: InputDecoration(
                          hintText: widget.localizations.translate('enterPriceHint'),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                      ),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      validator: (value) {
                        final qty = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0;
                        if (qty > 0 && (value == null || value.isEmpty))
                          return widget.localizations.translate('fieldRequiredError');
                        if (value != null && value.isNotEmpty) {
                          final price = double.tryParse(value.replaceAll(',', '.'));
                          if (price == null || price < 0)
                            return widget.localizations.translate('invalidPriceError');
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (!mounted) return;
                        _synchronizePricesAndRecalculateAll(priceFieldActive: true);
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 0.0),
                    child: ToggleButtons(
                      isSelected: [
                        _currentPriceInputType == PriceInputType.unit,
                        _currentPriceInputType == PriceInputType.total,
                      ],
                      onPressed: _onPriceTypeToggle,
                      borderRadius: BorderRadius.circular(8.0),
                      selectedBorderColor: Theme.of(context).primaryColorDark,
                      selectedColor: Colors.white,
                      fillColor: Theme.of(context).primaryColor,
                      color: Theme.of(context).primaryColorDark,
                      constraints: BoxConstraints(minHeight: 48.0, minWidth: 52.0),
                      children: <Widget>[
                        Tooltip(
                            message: widget.localizations.translate('pricePerUnitTooltip'),
                            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child:Text(widget.localizations.translate('unitAbbreviation')))
                        ),
                        Tooltip(
                            message: widget.localizations.translate('totalPriceTooltip'),
                            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0), child:Text(widget.localizations.translate('totalAbbreviation')))
                        ),
                      ],
                    ),
                  )
                ],
              ),

              if (_currentPriceInputType == PriceInputType.total && _itemData.unitPrice != null && _itemData.quantity > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    '${widget.localizations.translate('unitPrice')}: ${_formatPriceValueForDisplay(_itemData.unitPrice)} $currencySymbol ${widget.localizations.translate('perUnitAbbreviation')}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ),
              if (_currentPriceInputType == PriceInputType.unit && _itemData.totalItemPrice != null && _itemData.quantity > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text(
                    '${widget.localizations.translate('totalItemPrice')}: ${_formatPriceValueForDisplay(_itemData.totalItemPrice)} $currencySymbol',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ),

              if (_showPriceChangeInfo && _previousUnitPriceForInfo != null)
                Container(
                  margin: const EdgeInsets.only(top:10.0, bottom: 4.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange.shade300),
                      borderRadius: BorderRadius.circular(4.0)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.localizations.translate('purchasePriceChangeAlertTitle'), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800])),
                      Text('${widget.localizations.translate('originalPurchasePriceLabel')}: ${Utility.formatCurrency(_previousUnitPriceForInfo!, currencySymbol: currencySymbol, trimZeroDecimals: true)}', style: TextStyle(color: Colors.orange[700])),
                      if (_originalMarginAmountForInfo != null && _originalMarginPercentageForInfo != null)
                        Text(
                          '${widget.localizations.translate('originalMarginLabel')}: ${Utility.formatCurrency(_originalMarginAmountForInfo!, currencySymbol: currencySymbol, trimZeroDecimals: true)} (${_formatPriceValueForDisplay(_originalMarginPercentageForInfo)}%)',
                          style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      actions: dialogActions, // Použití dynamicky sestavených akcí
    );
  }
}

double fieldViewBuilderMaxWidth(
    BuildContext context, BuildContext dialogContext) {
  double dialogWidth = MediaQuery.of(dialogContext).size.width;
  final RenderBox? renderBox = dialogContext.findRenderObject() as RenderBox?;
  if (renderBox != null && renderBox.hasSize) {
    dialogWidth = renderBox.size.width;
  } else {
    dialogWidth = MediaQuery.of(context).size.width;
  }

  if (dialogWidth > 600) return 500;
  return dialogWidth * 0.85;
}