// lib/widgets/purchase_item_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Potřeba pro SchedulerPhase
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

// Enum pro typ zadávané ceny
enum PriceInputType { unit, total }

// Třída pro výsledek dialogu
class PurchaseItemDialogResult {
  final PurchaseItemDialogAction action;
  final UIPurchaseItem? item; // Relevantní pro 'save', může být i pro 'delete' k identifikaci

  PurchaseItemDialogResult(this.action, {this.item});
}


Future<PurchaseItemDialogResult?> showPurchaseItemDialog({
  required BuildContext context,
  required AppLocalizations localizations,
  UIPurchaseItem? existingItem,
}) async {
  return showDialog<PurchaseItemDialogResult>(
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
  final BuildContext dialogContext; // Context původního dialogu pro případné zobrazení dalších dialogů/snackbarů

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
  late TextEditingController _productNameController; // Používán Autocomplete fieldController, ale tento drží text
  late TextEditingController _quantityController;
  late TextEditingController _priceInputController;
  late FocusNode _priceInputFocusNode;

  PriceInputType _currentPriceInputType = PriceInputType.unit;

  bool _isLoadingProducts = false;
  List<Product> _availableProducts = [];
  late ProductProvider _productProvider;

  Product? _selectedProduct; // Aktuálně vybraný produkt z Autocomplete
  double? _currentSellingPrice; // Prodejní cena vybraného produktu
  double? _storedPurchasePrice; // Uložená nákupní cena vybraného produktu
  double? _calculatedMarginAmount; // Vypočtená marže v Kč
  double? _calculatedMarginPercentage; // Vypočtená marže v %

  bool _showPriceChangeInfo = false; // Zobrazit info o změně NC?
  double? _previousUnitPriceForInfo; // Předchozí NC pro zobrazení v infu
  double? _originalMarginAmountForInfo; // Původní marže v Kč pro info
  double? _originalMarginPercentageForInfo; // Původní marže v % pro info

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      _itemData = UIPurchaseItem( // Vytvoření kopie pro editaci
        id: widget.existingItem!.id,
        productId: widget.existingItem!.productId,
        productName: widget.existingItem!.productName,
        quantity: widget.existingItem!.quantity == 0 ? 1.0 : widget.existingItem!.quantity, // Množství by nemělo být 0 při editaci
        unitPrice: widget.existingItem!.unitPrice,
        totalItemPrice: widget.existingItem!.totalItemPrice,
      );
    } else {
      _itemData = UIPurchaseItem(id: const Uuid().v4(), productId: '', quantity: 1.0);
    }

    _productNameController = TextEditingController(text: _itemData.productName);
    _quantityController = TextEditingController(text: _formatQuantityForDisplay(_itemData.quantity));
    _priceInputController = TextEditingController();
    _priceInputFocusNode = FocusNode();
    _productProvider = Provider.of<ProductProvider>(context, listen: false);
    _availableProducts = _productProvider.products.toList(); // Získáme aktuálně dostupné produkty

    if (widget.existingItem != null && widget.existingItem!.productId.isNotEmpty) {
      _selectedProduct = _productProvider.getProductById(widget.existingItem!.productId);
      if (_selectedProduct != null) {
        _currentSellingPrice = _selectedProduct!.sellingPrice;
        _storedPurchasePrice = _productProvider.getStoredPurchasePrice(_selectedProduct!.itemId);
      }
    }
    // Načtení produktů a první synchronizace cen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProductsIfNeeded();
      _synchronizePricesAndRecalculateAll(isInitializing: true);
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _priceInputController.dispose();
    _priceInputFocusNode.dispose();
    super.dispose();
  }

  String _formatQuantityForDisplay(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    // Použijeme NumberFormat pro konzistentní formátování desetinných čísel dle lokalizace
    final formatter = NumberFormat("#,##0.###", widget.localizations.locale.languageCode);
    return formatter.format(qty);
  }

  String _formatPriceValueForDisplay(double? value) {
    if (value == null) return '';
    final formatter = NumberFormat("###0.##", widget.localizations.locale.languageCode);
    return formatter.format(value);
  }

  Future<void> _loadProductsIfNeeded() async {
    if (!mounted) return; // Kontrola, zda je widget stále aktivní
    if (_productProvider.products.isEmpty && !_isLoadingProducts) {
      setState(() => _isLoadingProducts = true);
      try {
        await _productProvider.fetchAllProductData(); // Načte všechny produktová data
        if (!mounted) return;
        _availableProducts = _productProvider.products.toList();
      } catch (e) {
        print("Chyba při načítání produktů v dialogu: $e");
        if (mounted && widget.dialogContext.mounted) {
          ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
            SnackBar(
                content:
                Text(widget.localizations.translate('errorLoadingData'))),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoadingProducts = false);
      }
    } else if (_productProvider.products.isNotEmpty && _availableProducts.isEmpty) {
      // Pokud produkty v provideru jsou, ale lokální seznam je prázdný (méně pravděpodobný scénář)
      if (!mounted) return;
      _availableProducts = _productProvider.products.toList();
      if (_isLoadingProducts && mounted) { // Pokud byl stav načítání, vypneme ho
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

    double newQuantity = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? _itemData.quantity;
    if (newQuantity <= 0 && !isInitializing && !modelPreFilled ) {
      newQuantity = 1.0;
      if (_quantityController.text != "1") { // Aktualizujeme pole jen pokud je to nutné
        final currentSelection = _quantityController.selection;
        _quantityController.text = _formatQuantityForDisplay(newQuantity);
        // Try to preserve cursor position or move to end
        _quantityController.selection = currentSelection.start <= _quantityController.text.length && currentSelection.end <= _quantityController.text.length
            ? currentSelection
            : TextSelection.fromPosition(TextPosition(offset: _quantityController.text.length));
      }
    }
    _itemData.quantity = newQuantity;

    double enteredPriceInField = double.tryParse(_priceInputController.text.replaceAll(',', '.')) ?? 0.0;

    if (priceFieldActive) {
      if (_currentPriceInputType == PriceInputType.unit) {
        _itemData.unitPrice = enteredPriceInField;
        if (_itemData.unitPrice != null) {
          _itemData.totalItemPrice = _itemData.quantity > 0 ? _itemData.unitPrice! * _itemData.quantity : 0;
        } else {
          _itemData.totalItemPrice = null;
        }
      } else { // _currentPriceInputType == PriceInputType.total
        _itemData.totalItemPrice = enteredPriceInField;
        if (_itemData.totalItemPrice != null && _itemData.quantity > 0) {
          _itemData.unitPrice = _itemData.totalItemPrice! / _itemData.quantity;
        } else if (_itemData.totalItemPrice == 0 && _itemData.quantity == 0) {
          _itemData.unitPrice = 0;
        } else {
          _itemData.unitPrice = null;
        }
      }
    }
    else if (quantityFieldActive || modelPreFilled || isInitializing || priceModeToggled) {
      if (_itemData.unitPrice != null) {
        _itemData.totalItemPrice = _itemData.quantity > 0 ? _itemData.unitPrice! * _itemData.quantity : 0;
      } else {
        if (_itemData.quantity == 0) {
          _itemData.totalItemPrice = 0;
        } else if (priceModeToggled && _currentPriceInputType == PriceInputType.unit && _itemData.unitPrice == null) {
          // Pokud se přepnulo na jednotkovou cenu, která je null, a nejedná se o aktivní psaní do cenového pole,
          // pak i celková cena by měla být null (nebo 0 pokud je množství 0).
          _itemData.totalItemPrice = null;
        }
        // Jinak _itemData.totalItemPrice zůstane (může být null nebo hodnota zadaná dříve v módu celkové ceny)
      }
    }

    String priceStringToDisplay;
    if (_currentPriceInputType == PriceInputType.unit) {
      priceStringToDisplay = _formatPriceValueForDisplay(_itemData.unitPrice);
    } else {
      priceStringToDisplay = _formatPriceValueForDisplay(_itemData.totalItemPrice);
    }

    if (isInitializing || modelPreFilled || priceModeToggled || quantityFieldActive || (_priceInputController.text != priceStringToDisplay && !_priceInputFocusNode.hasFocus) ) {
      final currentSelection = _priceInputController.selection;
      _priceInputController.text = priceStringToDisplay;
      if (_priceInputFocusNode.hasFocus && priceFieldActive) {
        _priceInputController.selection = currentSelection.start <= _priceInputController.text.length && currentSelection.end <= _priceInputController.text.length
            ? currentSelection
            : TextSelection.fromPosition(TextPosition(offset: _priceInputController.text.length));
      } else if (!priceFieldActive) {
        _priceInputController.selection = TextSelection.fromPosition(TextPosition(offset: _priceInputController.text.length));
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

    if(mounted) {
      setState(() {});
    }
  }

  void _onPriceTypeToggle(int index) {
    if (!mounted) return;
    PriceInputType newMode = PriceInputType.values[index];
    if (newMode == _currentPriceInputType) return;

    double currentPriceFromField = double.tryParse(_priceInputController.text.replaceAll(',', '.')) ?? 0.0;
    if (_currentPriceInputType == PriceInputType.unit) {
      _itemData.unitPrice = currentPriceFromField;
    } else {
      _itemData.totalItemPrice = currentPriceFromField;
    }

    setState(() {
      _currentPriceInputType = newMode;
    });
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
      context: widget.dialogContext,
      builder: (BuildContext confirmCtx) {
        return AlertDialog(
          title: Text(widget.localizations.translate('confirmDeleteItemTitle')),
          content: Text(widget.localizations.translate('confirmDeleteItemMessage')),
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
        0,
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
              _synchronizePricesAndRecalculateAll(priceFieldActive: _priceInputFocusNode.hasFocus, quantityFieldActive: !_priceInputFocusNode.hasFocus && _quantityController.text.isNotEmpty);

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
              Text(widget.localizations.translate('product'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (_isLoadingProducts)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_isLoadingProducts)
                Autocomplete<Product>(
                  initialValue: TextEditingValue(text: _productNameController.text), // Použijeme _productNameController
                  displayStringForOption: (Product option) => option.itemName,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      // Pokud chceme zobrazit nějaké návrhy i pro prázdné pole (např. po focusu)
                      // return _availableProducts.take(5); // Například prvních 5 nebo nejoblíbenější
                      return const Iterable<Product>.empty();
                    }
                    // Optimalizace: pro velmi krátké texty a velké seznamy můžeme omezit nebo změnit logiku
                    if (textEditingValue.text.length < 2 && _availableProducts.length > 20) {
                      return _availableProducts.where((Product option) =>
                          Utility.normalizeString(option.itemName.toLowerCase()).startsWith(Utility.normalizeString(textEditingValue.text.toLowerCase()))
                      ).take(10);
                    }
                    return _availableProducts.where((Product option) {
                      final normalizedOption = Utility.normalizeString(option.itemName.toLowerCase());
                      final normalizedQuery = Utility.normalizeString(textEditingValue.text.toLowerCase());
                      return normalizedOption.contains(normalizedQuery);
                    });
                  },
                  fieldViewBuilder: (BuildContext context,
                      TextEditingController fieldTextEditingController, // Tento je interní pro Autocomplete
                      FocusNode fieldFocusNode,
                      VoidCallback onFieldSubmitted) {

                    // Synchronizujeme náš _productNameController s interním controllerem Autocomplete
                    // Toto je potřeba, pokud chceme mít kontrolu nad textem i mimo Autocomplete,
                    // nebo pokud Autocomplete neaktualizuje initialValue dynamicky.
                    if (_productNameController.text != fieldTextEditingController.text) {
                      if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if(mounted) {
                            _productNameController.text = fieldTextEditingController.text;
                          }
                        });
                      } else {
                        // Pokud jsme v build fázi, naplánujeme aktualizaci po buildu
                        Future.microtask(() {
                          if(mounted) {
                            _productNameController.text = fieldTextEditingController.text;
                          }
                        });
                      }
                    }

                    return TextFormField(
                      controller: fieldTextEditingController, // Použijeme controller z fieldViewBuilder
                      focusNode: fieldFocusNode,
                      decoration: InputDecoration(
                        hintText: widget.localizations.translate('selectProduct'),
                        filled: true,
                        fillColor: Colors.white,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return widget.localizations.translate('fieldRequiredError');
                        }
                        // Pokud je text v poli, ale není vybrán žádný produkt (_itemData.productId je prázdný)
                        // a text neodpovídá žádnému produktu v seznamu, pak je to chyba.
                        if (_itemData.productId.isEmpty) {
                          final productExists = _availableProducts.any((p) => p.itemName.trim().toLowerCase() == value.trim().toLowerCase());
                          if (!productExists) return widget.localizations.translate('selectValidProductError');
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (!mounted) return;
                        // Při změně textu v poli (uživatel píše)
                        _productNameController.text = value; // Aktualizujeme náš controller
                        if (_selectedProduct?.itemName != value) { // Pokud text neodpovídá vybranému produktu
                          setState(() {
                            _itemData.productId = ''; // Resetujeme ID produktu
                            _selectedProduct = null;
                            _currentSellingPrice = null;
                            _storedPurchasePrice = null;
                          });
                          _synchronizePricesAndRecalculateAll();
                        }
                      },
                    );
                  },
                  onSelected: (Product selection) {
                    if (!mounted) return;
                    setState((){
                      _selectedProduct = selection;
                      _itemData.productName = selection.itemName;
                      _itemData.productId = selection.itemId;
                      _productNameController.text = selection.itemName;

                      _currentSellingPrice = selection.sellingPrice;
                      _storedPurchasePrice = _productProvider.getStoredPurchasePrice(selection.itemId);

                      double currentQtyInField = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0.0;
                      if(currentQtyInField <= 0) {
                        _itemData.quantity = 1.0;
                      } else {
                        _itemData.quantity = currentQtyInField;
                      }
                      // Aktualizujeme i text v poli pro množství
                      _quantityController.text = _formatQuantityForDisplay(_itemData.quantity);

                      _itemData.unitPrice = _storedPurchasePrice ?? selection.purchasePrice;
                      _itemData.totalItemPrice = null; // Necháme dopočítat
                    });
                    _synchronizePricesAndRecalculateAll(modelPreFilled: true);
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
                              maxWidth: fieldViewBuilderMaxWidth(optContext, widget.dialogContext) - 40
                          ),
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

              if (_calculatedMarginAmount != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    '${widget.localizations.translate('marginLabel')}: ${Utility.formatCurrency(_calculatedMarginAmount!, currencySymbol: currencySymbol, trimZeroDecimals: true)} (${_calculatedMarginPercentage != null ? '${_formatPriceValueForDisplay(_calculatedMarginPercentage)}%' : widget.localizations.translate('notAvailableAbbreviation')})',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: (_calculatedMarginAmount ?? 0) < 0 ? Colors.red[700] : Colors.green[700]),
                  ),
                ),

              Text(widget.localizations.translate('quantity'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                      ),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return widget.localizations.translate('fieldRequiredError');
                        }
                        final qty = double.tryParse(value.replaceAll(',', '.'));
                        if (qty == null || qty <= 0) {
                          return widget.localizations.translate('invalidQuantityError');
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (!mounted) return;
                        _synchronizePricesAndRecalculateAll(quantityFieldActive: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _decrementQuantity,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8)
                      ),
                      child: Icon(Icons.remove, size: 24, color: Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _incrementQuantity,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8)
                      ),
                      child: Icon(Icons.add, size: 24, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Text(priceInputLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                      ),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      validator: (value) {
                        final qty = double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 0;
                        if (qty > 0 && (value == null || value.isEmpty)) {
                          return widget.localizations.translate('fieldRequiredError');
                        }
                        if (value != null && value.isNotEmpty) {
                          final price = double.tryParse(value.replaceAll(',', '.'));
                          if (price == null || price < 0) {
                            return widget.localizations.translate('invalidPriceError');
                          }
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (!mounted) return;
                        _synchronizePricesAndRecalculateAll(priceFieldActive: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top:0.0),
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
                      constraints: const BoxConstraints(minHeight: 48.0, minWidth: 52.0),
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
                      if (_originalMarginAmountForInfo != null)
                        Text(
                          '${widget.localizations.translate('originalMarginLabel')}: ${Utility.formatCurrency(_originalMarginAmountForInfo!, currencySymbol: currencySymbol, trimZeroDecimals: true)} (${_originalMarginPercentageForInfo != null ? '${_formatPriceValueForDisplay(_originalMarginPercentageForInfo)}%' : widget.localizations.translate('notAvailableAbbreviation')})',
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
      actions: dialogActions,
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
    dialogWidth = MediaQuery.of(context).size.width * 0.9;
  }

  if (dialogWidth > 600) return 500;
  return dialogWidth * 0.9;
}