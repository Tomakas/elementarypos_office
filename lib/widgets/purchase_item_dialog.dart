// lib/widgets/purchase_item_dialog.dart
import 'package:flutter/material.dart';
import 'package:elementarypos_office/l10n/app_localizations.dart';
import 'package:elementarypos_office/models/ui_purchase_item_model.dart';
import 'package:uuid/uuid.dart'; // <-- PŘIDANÝ IMPORT

// Mock produkty prozatím, ideálně by se načítaly z provideru
const List<String> _mockProductsDialog = ['Produkt X', 'Produkt Y', 'Služba Z', 'Materiál 123'];


Future<UIPurchaseItem?> showPurchaseItemDialog({
  required BuildContext context,
  required AppLocalizations localizations,
  UIPurchaseItem? existingItem, // Pokud editujeme, předáme existující položku
}) async {
  final _formKeyDialog = GlobalKey<FormState>();
  // Pokud editujeme, použijeme existující data, jinak vytvoříme novou (dočasnou) položku pro formulář
  final UIPurchaseItem itemData = existingItem ?? UIPurchaseItem(id: Uuid().v4()); // Uuid by se musel importovat

  // Controllery pro dialog
  final TextEditingController productNameController = TextEditingController(text: itemData.productName);
  final TextEditingController quantityController = TextEditingController(text: itemData.quantity != 0 ? itemData.quantity.toString() : '');
  final TextEditingController unitPriceController = TextEditingController(text: itemData.unitPrice?.toStringAsFixed(2) ?? '');
  final TextEditingController totalItemPriceController = TextEditingController(text: itemData.totalItemPrice?.toStringAsFixed(2) ?? '');

  bool isUnitPriceFocused = false;
  bool isTotalPriceFocused = false;

  return showDialog<UIPurchaseItem>(
    context: context,
    barrierDismissible: false, // Uživatel musí explicitně zavřít nebo uložit
    builder: (BuildContext dialogContext) {
      return StatefulBuilder( // Aby se dialog mohl sám přebudovávat (pro dopočty)
          builder: (context, setStateDialog) {
            void _handlePriceCalculation() {
              itemData.quantity = double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 0;

              if (isUnitPriceFocused && unitPriceController.text.isNotEmpty) {
                itemData.unitPrice = double.tryParse(unitPriceController.text.replaceAll(',', '.'));
                itemData.totalItemPrice = null; // Reset pro dopočet
              } else if (isTotalPriceFocused && totalItemPriceController.text.isNotEmpty) {
                itemData.totalItemPrice = double.tryParse(totalItemPriceController.text.replaceAll(',', '.'));
                itemData.unitPrice = null; // Reset pro dopočet
              } else if (unitPriceController.text.isNotEmpty) { // fallback pokud nic není focusnuto ale unitPrice je vyplněn
                itemData.unitPrice = double.tryParse(unitPriceController.text.replaceAll(',', '.'));
                itemData.totalItemPrice = null;
              } else if (totalItemPriceController.text.isNotEmpty) { // fallback pro totalPrice
                itemData.totalItemPrice = double.tryParse(totalItemPriceController.text.replaceAll(',', '.'));
                itemData.unitPrice = null;
              }


              itemData.calculatePrices();

              if (!isUnitPriceFocused || unitPriceController.text.isEmpty) {
                totalItemPriceController.text = itemData.totalItemPrice?.toStringAsFixed(2) ?? '';
              }
              if (!isTotalPriceFocused || totalItemPriceController.text.isEmpty ) {
                unitPriceController.text = itemData.unitPrice?.toStringAsFixed(2) ?? '';
              }
            }

            return AlertDialog(
              title: Text(existingItem == null
                  ? localizations.translate('addProductItem')
                  : localizations.translate('editProductItem')), // Přidat "editProductItem" do lokalizace
              content: Form(
                key: _formKeyDialog,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Produkt
                      Text(localizations.translate('product'), style: TextStyle(fontWeight: FontWeight.bold)),
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: itemData.productName),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _mockProductsDialog.where((String option) {
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        fieldViewBuilder: (BuildContext context, TextEditingController fieldController,
                            FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                          // Synchronizace s productNameController, pokud je to potřeba mimo Autocomplete
                          // Pro tento dialog to nemusí být nutné, pokud se spoléháme na `itemData`
                          productNameController.text = fieldController.text; // Keep our controller in sync
                          return TextFormField(
                            controller: fieldController,
                            focusNode: fieldFocusNode,
                            decoration: InputDecoration(
                              hintText: localizations.translate('selectProduct'),
                              filled: true, fillColor: Colors.white, border: OutlineInputBorder(),
                            ),
                            validator: (value) => value == null || value.isEmpty ? localizations.translate('fieldRequiredError') : null,
                            onChanged: (value) {
                              itemData.productName = value; // Uložíme do itemData
                            },
                          );
                        },
                        onSelected: (String selection) {
                          itemData.productName = selection;
                          productNameController.text = selection; // Update if needed elsewhere
                        },
                      ),
                      const SizedBox(height: 12),

                      // Množství
                      Text(localizations.translate('quantity'), style: TextStyle(fontWeight: FontWeight.bold)),
                      TextFormField(
                        controller: quantityController,
                        decoration: InputDecoration(hintText: localizations.translate('enterQuantity'), filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return localizations.translate('fieldRequiredError');
                          final qty = double.tryParse(value.replaceAll(',', '.'));
                          if (qty == null || qty <= 0) return localizations.translate('invalidQuantityError');
                          return null;
                        },
                        onChanged: (value) {
                          _handlePriceCalculation();
                          setStateDialog((){}); // Trigger rebuild pro dopočet
                        },
                      ),
                      const SizedBox(height: 12),

                      // Jednotková cena
                      Text(localizations.translate('unitPrice'), style: TextStyle(fontWeight: FontWeight.bold)),
                      Focus(
                        onFocusChange: (hasFocus) => setStateDialog(() => isUnitPriceFocused = hasFocus),
                        child: TextFormField(
                          controller: unitPriceController,
                          decoration: InputDecoration(hintText: localizations.translate('enterUnitPrice'), filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            if(isUnitPriceFocused) { // Pouze pokud je pole aktivní, aby se zabránilo přepsání při dopočtu
                              _handlePriceCalculation();
                              setStateDialog((){});
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Celková cena položky
                      Text(localizations.translate('totalItemPrice'), style: TextStyle(fontWeight: FontWeight.bold)),
                      Focus(
                        onFocusChange: (hasFocus) => setStateDialog(() => isTotalPriceFocused = hasFocus),
                        child: TextFormField(
                          controller: totalItemPriceController,
                          decoration: InputDecoration(hintText: localizations.translate('enterTotalItemPrice'), filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            if(isTotalPriceFocused) { // Pouze pokud je pole aktivní
                              _handlePriceCalculation();
                              setStateDialog((){});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(localizations.translate('cancel')),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Vrátí null
                  },
                ),
                ElevatedButton(
                  child: Text(localizations.translate(existingItem == null ? 'add' : 'saveChanges')), // Přidat "saveChanges" do lokalizace
                  onPressed: () {
                    if (_formKeyDialog.currentState!.validate()) {
                      // Finální přiřazení a výpočet před uložením
                      itemData.productName = productNameController.text; // Pro Autocomplete
                      itemData.quantity = double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 0;
                      itemData.unitPrice = unitPriceController.text.isNotEmpty ? double.tryParse(unitPriceController.text.replaceAll(',', '.')) : null;
                      itemData.totalItemPrice = totalItemPriceController.text.isNotEmpty ? double.tryParse(totalItemPriceController.text.replaceAll(',', '.')) : null;

                      // Zajistíme, že ceny jsou konzistentní dle zadaných hodnot
                      if (itemData.unitPrice != null) {
                        itemData.totalItemPrice = null; // Priorita unitPrice, pokud je zadáno
                      } else if (itemData.totalItemPrice != null) {
                        itemData.unitPrice = null; // Priorita totalItemPrice, pokud je zadáno a unitPrice není
                      }
                      itemData.calculatePrices(); // Finální dopočet

                      Navigator.of(dialogContext).pop(itemData); // Vrátí vyplněnou/upravenou položku
                    }
                  },
                ),
              ],
            );
          }
      );
    },
  );
}

// Je potřeba importovat Uuid, pokud ho používáte zde:
// import 'package:uuid/uuid.dart';
// Tento import jsem přesunul do AddPurchaseScreen, kde se _uuid instance vytváří.
// Pro dialog můžeme ID generovat přímo, pokud existingItem je null.
// Nicméně, je lepší, když AddPurchaseScreen zodpovídá za ID.
// Upravíme dialog tak, aby ID bral z `existingItem` nebo ho neřešil, pokud `existingItem` je null.
// ID se vygeneruje v AddPurchaseScreen při vytváření nové instance UIPurchaseItem předaného do dialogu.
// Vlastně už to tak je: `final UIPurchaseItem itemData = existingItem ?? UIPurchaseItem(id: Uuid().v4());`
// Ještě lépe: `final UIPurchaseItem itemData = existingItem ?? UIPurchaseItem(id: Uuid().v4(), productName: '', quantity: 1.0);`
// Pokud `existingItem` je `null`, znamená to nová položka.
// Pokud `existingItem` není `null`, znamená to editace.