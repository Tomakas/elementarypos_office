// lib/screens/add_purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:elementarypos_office/l10n/app_localizations.dart';
// Předpokládám, že model Product je potřeba pro kontext, i když zde přímo nepoužit v UI
// import 'package:elementarypos_office/models/product_model.dart';
import 'package:elementarypos_office/models/purchase_model.dart';
import 'package:elementarypos_office/models/ui_purchase_item_model.dart';
import 'package:elementarypos_office/providers/product_provider.dart';
import 'package:elementarypos_office/providers/purchase_provider.dart';
import 'package:elementarypos_office/widgets/purchase_item_dialog.dart';
import 'package:elementarypos_office/services/utility_services.dart';
import 'package:uuid/uuid.dart';

class AddPurchaseScreen extends StatefulWidget {
  final Purchase? purchaseToEdit;

  const AddPurchaseScreen({
    super.key,
    this.purchaseToEdit,
  });

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSupplier;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _purchaseNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<UIPurchaseItem> _purchaseItems = [];
  final Uuid _uuid = const Uuid();

  // Příklad dodavatelů, ideálně by se měli načítat dynamicky
  final List<String> _mockSuppliers = ['Dodavatel A', 'Dodavatel B', 'Velkoobchod C', 'Jiný dodavatel XYZ'];
  double _overallTotalPrice = 0.0;
  bool _shouldUpdateStoredPurchasePrice = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.purchaseToEdit != null) {
      _isEditing = true;
      final purchase = widget.purchaseToEdit!;
      _selectedSupplier = purchase.supplier;
      _selectedDate = purchase.purchaseDate;
      _purchaseNumberController.text = purchase.purchaseNumber ?? '';
      _notesController.text = purchase.notes ?? '';
      _purchaseItems = purchase.items.map((item) => UIPurchaseItem(
        id: item.id,
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalItemPrice: item.totalItemPrice,
      )).toList();
      // Pokud váš Purchase model bude mít _shouldUpdateStoredPurchasePrice
      // _shouldUpdateStoredPurchasePrice = purchase.shouldUpdateStoredPurchasePrice ?? true; // Příklad
      _calculateOverallTotal();
    } else {
      // _purchaseItems již je inicializován jako prázdný seznam
    }
  }

  @override
  void dispose() {
    _purchaseNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  void _calculateOverallTotal() {
    double total = 0;
    for (var item in _purchaseItems) {
      total += item.totalItemPrice ?? 0;
    }
    if (mounted) {
      setState(() {
        _overallTotalPrice = total;
      });
    }
  }

  void _addOrEditPurchaseItem([UIPurchaseItem? itemToEdit, int? index]) async {
    final localizations = AppLocalizations.of(context)!;
    // Zpracování nového typu výsledku
    final PurchaseItemDialogResult? result = await showPurchaseItemDialog(
      context: context,
      localizations: localizations,
      existingItem: itemToEdit,
    );

    if (result != null && mounted) { // Zkontrolujeme i mounted pro jistotu
      setState(() {
        if (result.action == PurchaseItemDialogAction.save && result.item != null) {
          if (index != null && itemToEdit != null) { // Editace
            _purchaseItems[index] = result.item!;
          } else { // Přidání nové položky
            _purchaseItems.add(result.item!);
          }
        } else if (result.action == PurchaseItemDialogAction.delete && itemToEdit != null) {
          // Použijeme itemToEdit.id pro smazání, pokud je ID spolehlivé,
          // nebo index, pokud byl předán a je stále platný.
          // Protože _removeItem již používá index, a ten je zde k dispozici:
          if (index != null) {
            _removeItem(index); // _removeItem již volá _calculateOverallTotal uvnitř
          } else {
            // Fallback pokud by index nebyl dostupný, ale máme itemToEdit.id
            // (Tento scénář by neměl nastat, pokud delete je jen pro existingItem)
            _purchaseItems.removeWhere((item) => item.id == itemToEdit.id);
          }
        }
        // Pro PurchaseItemDialogAction.cancel neděláme nic.

        // _calculateOverallTotal se volá v _removeItem, nebo ho zavoláme zde pro save
        if (result.action == PurchaseItemDialogAction.save) {
          _calculateOverallTotal();
        }
      });
    }
  }

  void _removeItem(int index) {
    if (mounted) {
      setState(() {
        if (index >= 0 && index < _purchaseItems.length) {
          _purchaseItems.removeAt(index);
          _calculateOverallTotal();
        }
      });
    }
  }

  void _savePurchase() async {
    final localizations = AppLocalizations.of(context)!;
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedSupplier == null || _selectedSupplier!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('selectSupplierError'))),
      );
      return;
    }
    if (_purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('addAtLeastOneItemError'))),
      );
      return;
    }

    for (var item in _purchaseItems) {
      if (item.productName.isEmpty || item.productId.isEmpty || item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate('itemValidationError'))),
        );
        return;
      }
      final qty = item.quantity;
      if (qty > 0 && (item.totalItemPrice == null || item.totalItemPrice! < 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.translate('priceMissingForItemError')}: ${item.productName}')),
        );
        return;
      }
    }

    final purchaseToSave = Purchase(
      id: _isEditing ? widget.purchaseToEdit!.id : _uuid.v4(),
      supplier: _selectedSupplier,
      purchaseDate: _selectedDate,
      purchaseNumber: _purchaseNumberController.text,
      notes: _notesController.text,
      items: List<UIPurchaseItem>.from(_purchaseItems.map((uiItem) => UIPurchaseItem(
          id: uiItem.id,
          productId: uiItem.productId,
          productName: uiItem.productName,
          quantity: uiItem.quantity,
          unitPrice: uiItem.unitPrice,
          totalItemPrice: uiItem.totalItemPrice
      ))),
      overallTotalPrice: _overallTotalPrice,
      // updateProductPurchasePrices: _shouldUpdateStoredPurchasePrice, // Odkomentujte, pokud má Purchase model tento atribut
    );
    try {
      if (_isEditing) {
        await purchaseProvider.updatePurchase(purchaseToSave);
      } else {
        await purchaseProvider.addPurchase(purchaseToSave);
      }

      if (_shouldUpdateStoredPurchasePrice) {
        for (var item in purchaseToSave.items) {
          if (item.unitPrice != null && item.productId.isNotEmpty) {
            await productProvider.updateStoredProductPurchasePrice(item.productId, item.unitPrice);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate(_isEditing ? 'purchaseUpdatedSuccessfully' : 'purchaseSavedSuccessfully'))),
        );
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      print("Chyba při ukládání/aktualizaci nákupu: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate('errorSavingPurchase'))),
        );
      }
    }
  }

  Widget _buildItemsTableHeader(AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey[350]!)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Text(localizations.translate('product'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(
            flex: 2,
            child: Text(localizations.translate('quantity'), textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          Expanded(
            flex: 3,
            child: Text(localizations.translate('totalItemPrice'), textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(UIPurchaseItem item, int index, AppLocalizations localizations) {
    if (item.unitPrice == null && item.totalItemPrice != null && item.quantity > 0) {
      item.unitPrice = item.totalItemPrice! / item.quantity;
    } else if (item.totalItemPrice == null && item.unitPrice != null && item.quantity > 0) {
      item.totalItemPrice = item.unitPrice! * item.quantity;
    }

    return InkWell(
      onTap: () => _addOrEditPurchaseItem(item, index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 5,
              child: Text(item.productName, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15)),
            ),
            Expanded(
              flex: 2,
              child: Text(_formatQuantityForDisplay(item.quantity), textAlign: TextAlign.end, style: TextStyle(fontSize: 15)),
            ),
            Expanded(
              flex: 3,
              child: Text(item.totalItemPrice != null ? Utility.formatCurrency(item.totalItemPrice!, currencySymbol: '', decimals: 2, trimZeroDecimals: true) : '-', textAlign: TextAlign.end, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            SizedBox(width: 40),
          ],
        ),
      ),
    );
  }
  String _formatQuantityForDisplay(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    final formatter = NumberFormat("#,##0.###", AppLocalizations.of(context)!.locale.languageCode);
    return formatter.format(qty);
  }


  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final appBarTitle = _isEditing
        ? localizations.translate('editPurchaseTitle')
        : localizations.translate('newPurchaseTitle');
    final String currencySymbol = localizations.translate('currency');

    // Vytvoření dynamického seznamu dodavatelů pro Dropdown
    List<String> currentDropdownSuppliers = List.from(_mockSuppliers);
    if (_isEditing && _selectedSupplier != null && _selectedSupplier!.isNotEmpty && !currentDropdownSuppliers.contains(_selectedSupplier)) {
      currentDropdownSuppliers.add(_selectedSupplier!);
      // currentDropdownSuppliers.sort(); // Volitelné seřazení
    }


    return Scaffold(
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(color: Colors.white, fontSize: 20.0),
        ),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: localizations.translate(_isEditing ? 'saveChanges' : 'savePurchase'),
            onPressed: _savePurchase,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Dodavatel
              Text(localizations.translate('supplier'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedSupplier,
                hint: Text(localizations.translate('selectSupplier')),
                items: currentDropdownSuppliers.map((String supplier) { // Použití currentDropdownSuppliers
                  return DropdownMenuItem<String>(
                    value: supplier,
                    child: Text(supplier),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSupplier = newValue;
                  });
                },
                validator: (value) => value == null || value.isEmpty ? localizations.translate('selectSupplierError') : null,
                decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16)),
              ),
              const SizedBox(height: 16),

              // Datum nákupu
              Text(localizations.translate('purchaseDate'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: const Icon(Icons.calendar_today),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16)
                  ),
                  child: Text(DateFormat('dd.MM.yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),

              // Položky nákupu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(localizations.translate('addProductItem')),
                    onPressed: () => _addOrEditPurchaseItem(),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_purchaseItems.isNotEmpty)
                _buildItemsTableHeader(localizations),
              _purchaseItems.isEmpty
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: Text(localizations.translate('noItemsAddedYet'))),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _purchaseItems.length,
                itemBuilder: (context, index) {
                  final item = _purchaseItems[index];
                  return _buildItemRow(item, index, localizations);
                },
              ),
              const SizedBox(height: 10),
              if (_purchaseItems.isNotEmpty)
                const Divider(),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${localizations.translate('totalPurchasePrice')}: ${Utility.formatCurrency(_overallTotalPrice, currencySymbol: currencySymbol, trimZeroDecimals: true)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),

              // Číslo nákupu/dokladu
              Text(localizations.translate('purchaseNumberOptional'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _purchaseNumberController,
                decoration: InputDecoration(
                  hintText: localizations.translate('enterPurchaseNumber'),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Poznámky
              Text(localizations.translate('notesOptional'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: localizations.translate('enterNotes'),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 16),

              // Přepínač pro aktualizaci nákupních cen
              SwitchListTile(
                title: Text(localizations.translate('updateProductPurchasePriceSwitch')),
                value: _shouldUpdateStoredPurchasePrice,
                onChanged: (bool value) {
                  setState(() {
                    _shouldUpdateStoredPurchasePrice = value;
                  });
                },
                activeColor: Theme.of(context).colorScheme.secondary,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),


              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(localizations.translate(_isEditing ? 'saveChanges' : 'savePurchase'), style: const TextStyle(fontSize: 16)),
                  onPressed: _savePurchase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}