// lib/screens/add_purchase_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../models/ui_purchase_item_model.dart';
import '../models/purchase_model.dart';
import '../providers/purchase_provider.dart';
import '../widgets/purchase_item_dialog.dart';
import '../services/utility_services.dart';

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSupplier;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _purchaseNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<UIPurchaseItem> _purchaseItems = [];
  final Uuid _uuid = Uuid(); // Pro ID nákupu

  final List<String> _mockSuppliers = ['Dodavatel A', 'Dodavatel B', 'Velkoobchod C']; // Zatím ponecháme mock
  double _overallTotalPrice = 0.0;

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
      firstDate: DateTime(2000), // Můžete upravit podle potřeby
      lastDate: DateTime(2101),  // Můžete upravit podle potřeby
      // Můžete přidat lokalizaci pro date picker, pokud je to potřeba
      // locale: Locale(AppLocalizations.of(context)!.locale.languageCode),
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

  void _handleAddNewItem() async {
    final localizations = AppLocalizations.of(context)!;
    final newItem = await showPurchaseItemDialog(
      context: context,
      localizations: localizations,
    );

    if (newItem != null) {
      if (mounted) {
        setState(() {
          _purchaseItems.add(newItem);
          _calculateOverallTotal();
        });
      }
    }
  }

  void _handleEditItem(UIPurchaseItem itemToEdit, int index) async {
    final localizations = AppLocalizations.of(context)!;
    // Vytvoření kopie pro úpravu, aby se neupravoval původní objekt před potvrzením
    final UIPurchaseItem itemCopy = UIPurchaseItem(
        id: itemToEdit.id,
        productName: itemToEdit.productName,
        quantity: itemToEdit.quantity,
        unitPrice: itemToEdit.unitPrice,
        totalItemPrice: itemToEdit.totalItemPrice
    );

    final updatedItem = await showPurchaseItemDialog(
      context: context,
      localizations: localizations,
      existingItem: itemCopy,
    );

    if (updatedItem != null) {
      if (mounted) {
        setState(() {
          _purchaseItems[index] = updatedItem;
          _calculateOverallTotal();
        });
      }
    }
  }

  void _handleRemoveItem(String itemId) {
    if (mounted) {
      setState(() {
        _purchaseItems.removeWhere((item) => item.id == itemId);
        _calculateOverallTotal();
      });
    }
  }


  void _savePurchase() {
    final localizations = AppLocalizations.of(context)!;
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

    // Validace položek
    for (var item in _purchaseItems) {
      if (item.productName.isEmpty || item.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate('itemValidationError'))),
        );
        return;
      }
      if ((item.totalItemPrice == null || item.totalItemPrice! < 0) && item.quantity > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.translate('priceMissingForItemError')}: ${item.productName}')),
        );
        return;
      }
    }

    final newPurchase = Purchase(
      id: _uuid.v4(),
      supplier: _selectedSupplier,
      purchaseDate: _selectedDate,
      purchaseNumber: _purchaseNumberController.text,
      notes: _notesController.text,
      items: List<UIPurchaseItem>.from(_purchaseItems),
      overallTotalPrice: _overallTotalPrice,
    );

    Provider.of<PurchaseProvider>(context, listen: false).addPurchase(newPurchase).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('purchaseSavedSuccessfully'))),
      );
      Navigator.of(context).pop();
    }).catchError((error) {
      print("Chyba při ukládání nákupu přes providera: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('errorSavingPurchase'))),
      );
    });
  }

  Widget _buildItemsTableHeader(AppLocalizations localizations) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(localizations.translate('product'), style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(localizations.translate('quantity'), textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(localizations.translate('unitPrice'), textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(localizations.translate('totalItemPrice'), textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 48), // Prostor pro tlačítko na smazání
        ],
      ),
    );
  }

  Widget _buildItemRow(UIPurchaseItem item, int index, AppLocalizations localizations) {
    if (item.totalItemPrice != null && item.quantity > 0 && item.unitPrice == null) {
      item.calculatePrices();
    }

    return InkWell(
      onTap: () => _handleEditItem(item, index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: Text(item.productName, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(item.quantity.toString(), textAlign: TextAlign.end),
            ),
            Expanded(
              flex: 2,
              child: Text(item.unitPrice != null ? Utility.formatCurrency(item.unitPrice!, currencySymbol: '', decimals: 2) : '-', textAlign: TextAlign.end),
            ),
            Expanded(
              flex: 2,
              child: Text(item.totalItemPrice != null ? Utility.formatCurrency(item.totalItemPrice!, currencySymbol: '', decimals: 2) : '-', textAlign: TextAlign.end),
            ),
            SizedBox(
              width: 48,
              child: IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[700], size: 20),
                tooltip: localizations.translate('removeItem'),
                onPressed: () => _handleRemoveItem(item.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('newPurchaseTitle'),
          style: const TextStyle(color: Colors.white, fontSize: 20.0),
        ),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: localizations.translate('savePurchase'),
            onPressed: _savePurchase,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(localizations.translate('supplier'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: _selectedSupplier,
                hint: Text(localizations.translate('selectSupplier')),
                items: _mockSuppliers.map((String supplier) {
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

              Text(localizations.translate('purchaseDate'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              InkWell(
                onTap: () => _selectDate(context), // Zde je volání metody
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

              Text(localizations.translate('purchaseNumber'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextFormField(
                controller: _purchaseNumberController,
                decoration: InputDecoration(
                  hintText: localizations.translate('enterPurchaseNumber'),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(localizations.translate('purchaseItems'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 20),
                    label: Text(localizations.translate('addProductItem')),
                    onPressed: _handleAddNewItem,
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
                  '${localizations.translate('totalPurchasePrice')}: ${Utility.formatCurrency(_overallTotalPrice, currencySymbol: localizations.translate('currency'), decimals: 2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              Text(localizations.translate('notes'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(localizations.translate('savePurchase'), style: const TextStyle(fontSize: 16)),
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