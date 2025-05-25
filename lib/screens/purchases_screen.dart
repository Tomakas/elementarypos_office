// lib/screens/purchases_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:elementarypos_office/l10n/app_localizations.dart';
import 'package:elementarypos_office/providers/purchase_provider.dart';
import 'package:elementarypos_office/models/purchase_model.dart';
import 'package:elementarypos_office/services/utility_services.dart';
import 'package:elementarypos_office/screens/add_purchase_screen.dart';
import 'package:elementarypos_office/models/ui_purchase_item_model.dart';


class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  DateTimeRange? _selectedDateRange;
  String? _dateRangeText;

  String _currentSortCriteria = 'date';
  bool _currentSortAscending = false;

  String? _selectedSupplier;
  List<String> _availableSuppliers = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateDateRangeText();
      _loadInitialSuppliers();
    });
  }

  Future<void> _loadInitialSuppliers() async {
    if (!mounted) return;
    await _getUniqueSuppliers();
  }


  void _updateDateRangeText() {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context)!;
    if (_selectedDateRange != null) {
      final start = _selectedDateRange!.start;
      final end = _selectedDateRange!.end;
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        _dateRangeText = DateFormat('d.MM.yyyy').format(start);
      } else {
        _dateRangeText =
        '${DateFormat('d.MM.yyyy').format(start)} - ${DateFormat('d.MM.yyyy').format(end)}';
      }
    } else {
      _dateRangeText = localizations.translate('noDateFilter');
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _getUniqueSuppliers() async {
    if (!mounted) return;
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    final Set<String> suppliers = {};
    for (var purchase in purchaseProvider.purchases) {
      if (purchase.supplier != null && purchase.supplier!.isNotEmpty) {
        suppliers.add(purchase.supplier!);
      }
    }
    if (mounted && (_availableSuppliers.length != suppliers.length || !_availableSuppliers.every(suppliers.contains))) {
      setState(() {
        _availableSuppliers = suppliers.toList()..sort();
      });
    }
  }

  List<Purchase> _getFilteredAndSortedPurchases(List<Purchase> allPurchases) {
    List<Purchase> tempPurchases = List.from(allPurchases);

    if (_selectedDateRange != null) {
      tempPurchases = tempPurchases.where((purchase) {
        final purchaseDate = purchase.purchaseDate;
        final startDate = _selectedDateRange!.start;
        final endDate = _selectedDateRange!.end;
        final purchaseDateOnly = DateTime(purchaseDate.year, purchaseDate.month, purchaseDate.day);
        final rangeStartDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
        final rangeEndDateOnly = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

        return !purchaseDateOnly.isBefore(rangeStartDateOnly) && !purchaseDateOnly.isAfter(rangeEndDateOnly);
      }).toList();
    }

    if (_selectedSupplier != null && _selectedSupplier!.isNotEmpty) {
      tempPurchases = tempPurchases.where((purchase) => purchase.supplier == _selectedSupplier).toList();
    }

    tempPurchases.sort((a, b) {
      int comparison;
      if (_currentSortCriteria == 'date') {
        comparison = a.purchaseDate.compareTo(b.purchaseDate);
      } else if (_currentSortCriteria == 'price') {
        comparison = a.overallTotalPrice.compareTo(b.overallTotalPrice);
      } else {
        comparison = 0;
      }
      return _currentSortAscending ? comparison : -comparison;
    });
    return tempPurchases;
  }

  void _showDateRangePicker() async {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context)!;
    DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: localizations.translate('dateRangeTooltip'),
      cancelText: localizations.translate('cancel'),
      confirmText: localizations.translate('applyFilters'),
    );

    if (pickedRange != null) {
      if (mounted) {
        setState(() {
          _selectedDateRange = pickedRange;
          _updateDateRangeText();
        });
      }
    }
  }

  void _showSortDialog() {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.translate('sortPurchasesTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  title: Text(localizations.translate('sortPurchasesByDateDesc')),
                  trailing: (_currentSortCriteria == 'date' && !_currentSortAscending) ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    if(mounted) setState(() {
                      _currentSortCriteria = 'date';
                      _currentSortAscending = false;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('sortPurchasesByDateAsc')),
                  trailing: (_currentSortCriteria == 'date' && _currentSortAscending) ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    if(mounted) setState(() {
                      _currentSortCriteria = 'date';
                      _currentSortAscending = true;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('sortPurchasesByPriceDesc')),
                  trailing: (_currentSortCriteria == 'price' && !_currentSortAscending) ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    if(mounted) setState(() {
                      _currentSortCriteria = 'price';
                      _currentSortAscending = false;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('sortPurchasesByPriceAsc')),
                  trailing: (_currentSortCriteria == 'price' && _currentSortAscending) ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    if(mounted) setState(() {
                      _currentSortCriteria = 'price';
                      _currentSortAscending = true;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterDialog() {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context)!;
    String? tempSelectedSupplier = _selectedSupplier;

    showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
              builder: (context, setStateDialog) {
                return AlertDialog(
                  title: Text(localizations.translate('filterPurchasesTitle')),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(localizations.translate('filterBySupplierTitle'), style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                            hintStyle: TextStyle(color: Colors.grey[600]),
                          ),
                          value: tempSelectedSupplier,
                          hint: Text(localizations.translate('allSuppliers')),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(localizations.translate('allSuppliers')),
                            ),
                            ..._availableSuppliers.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                          ],
                          onChanged: (String? newValue) {
                            setStateDialog(() {
                              tempSelectedSupplier = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: Text(localizations.translate('cancel')),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                    ElevatedButton(
                      child: Text(localizations.translate('applyFilters')),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _selectedSupplier = tempSelectedSupplier;
                          });
                        }
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  ],
                );
              }
          );
        });
  }

  String _formatQuantityForDialog(double qty, AppLocalizations localizations) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    final formatter = NumberFormat("#,##0.###", localizations.locale.languageCode);
    return formatter.format(qty);
  }

  Future<void> _confirmDeletePurchase(
      BuildContext upperDialogContext,
      Purchase purchase,
      AppLocalizations localizations,
      PurchaseProvider purchaseProvider) async {
    final bool? confirmed = await showDialog<bool>(
      context: upperDialogContext,
      builder: (BuildContext confirmDialogContext) {
        return AlertDialog(
          title: Text(localizations.translate('confirmDelete')),
          content: Text(localizations.translate('confirmDeletePurchaseMessage')),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.translate('cancel')),
              onPressed: () => Navigator.of(confirmDialogContext).pop(false),
            ),
            TextButton(
              child: Text(localizations.translate('delete')),
              onPressed: () => Navigator.of(confirmDialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      try {
        Navigator.of(upperDialogContext).pop();
        await purchaseProvider.deletePurchase(purchase.id);
        await _getUniqueSuppliers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('purchaseDeletedSuccess'))),
          );
        }
      } catch (e) {
        print("Chyba při mazání nákupu: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('errorDeletingPurchase'))),
          );
        }
      }
    }
  }

  void _showPurchaseDetailDialog(
      BuildContext context,
      Purchase purchase,
      AppLocalizations localizations,
      PurchaseProvider purchaseProvider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        final String currencySymbol = localizations.translate('currency');

        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  purchase.supplier ?? localizations.translate('notAvailable'),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                const SizedBox(height: 12),

                Text(
                  '${localizations.translate('purchaseNumber')}: ${purchase.purchaseNumber?.isNotEmpty == true ? purchase.purchaseNumber : localizations.translate('notAvailable')}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                Text(
                  '${localizations.translate('purchaseDate')}: ${DateFormat('d. M. yy').format(purchase.purchaseDate)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                Text(
                  '${localizations.translate('totalPurchasePrice')}: ${Utility.formatCurrency(purchase.overallTotalPrice, currencySymbol: currencySymbol, trimZeroDecimals: true)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700], fontWeight: FontWeight.w500),
                ),

                if (purchase.notes != null && purchase.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${localizations.translate('notes')}: ${purchase.notes}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700], fontStyle: FontStyle.italic),
                    ),
                  ),
                const SizedBox(height: 18),

                if (purchase.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(localizations.translate('noItemsAddedYet'), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                  )
                else
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center, // Pro hlavičku také
                          children: [
                            Expanded(
                                flex: 4,
                                child: Text(
                                    localizations.translate('itemText'),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87
                                    )
                                )),
                            Expanded(
                                flex: 2,
                                child: Text(
                                    localizations.translate('quantity'),
                                    textAlign: TextAlign.end,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87
                                    )
                                )),
                            Expanded(
                                flex: 3,
                                child: Text(
                                    localizations.translate('totalItemPrice'),
                                    textAlign: TextAlign.end,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87
                                    )
                                )),
                          ],
                        ),
                      ),
                      const Divider(height: 1.0, thickness: 0.5, color: Colors.grey),

                      ...purchase.items.map((item) {
                        if (item.unitPrice == null && item.totalItemPrice != null && item.quantity > 0) {
                          item.unitPrice = item.totalItemPrice! / item.quantity;
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center, // Vertikální centrování ZDE
                            children: <Widget>[
                              Expanded(
                                flex: 4,
                                child: Text(item.productName, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _formatQuantityForDialog(item.quantity, localizations),
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  Utility.formatCurrency(item.totalItemPrice ?? 0, currencySymbol: currencySymbol, trimZeroDecimals: true),
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            TextButton(
              child: Text(localizations.translate('edit')),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddPurchaseScreen(purchaseToEdit: purchase),
                  ),
                );
                if (result == true || result == null) {
                  await _getUniqueSuppliers();
                }
              },
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  child: Text(localizations.translate('delete'), style: TextStyle(color: Colors.red[700])),
                  onPressed: () {
                    _confirmDeletePurchase(dialogContext, purchase, localizations, purchaseProvider);
                  },
                ),
                TextButton(
                  child: Text(localizations.translate('close')),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            )
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final purchaseProvider = context.watch<PurchaseProvider>();

    // Aktualizace seznamu dodavatelů, pokud se změní data v provideru
    // Použití WidgetsBinding.instance.addPostFrameCallback zajistí, že se setState nevolá během buildu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted) {
        _getUniqueSuppliers();
      }
    });

    final List<Purchase> filteredAndSortedPurchases = _getFilteredAndSortedPurchases(purchaseProvider.purchases);


    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('purchasesTitle'),
          style: const TextStyle(color: Colors.white, fontSize: 20.0),
        ),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            tooltip: localizations.translate('dateRangeTooltip'),
            onPressed: _showDateRangePicker,
          ),
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: localizations.translate('sortTooltip'),
            onPressed: _showSortDialog,
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_sharp, color: Colors.white),
            tooltip: localizations.translate('filterTooltip'),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            color: Colors.grey[200],
            child: Text(
              _dateRangeText ?? localizations.translate('noDateFilter'),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: purchaseProvider.isLoading && filteredAndSortedPurchases.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredAndSortedPurchases.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    localizations.translate('noPurchasesMatchFilter'),
                    style: const TextStyle(
                        fontSize: 17.0, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 70.0),
                itemCount: filteredAndSortedPurchases.length,
                itemBuilder: (listViewCtx, i) {
                  final purchase = filteredAndSortedPurchases[i];
                  return Card(
                    elevation: 2.0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    margin: const EdgeInsets.symmetric(
                        vertical: 5.0, horizontal: 5.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14.0),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blueGrey[50],
                        child: Icon(Icons.receipt_long_outlined, color: Colors.blueGrey[600], size: 26),
                      ),
                      title: Text(
                        '${purchase.supplier ?? localizations.translate('notAvailable')}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${localizations.translate('purchaseDate')}: ${DateFormat('dd.MM.yyyy').format(purchase.purchaseDate)}',
                              style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
                            ),
                            if(purchase.purchaseNumber?.isNotEmpty ?? false)
                              Text(
                                '${localizations.translate('purchaseNumber')}: ${purchase.purchaseNumber}',
                                style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              '${localizations.translate('itemsCount')}: ${purchase.items.length}',
                              style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      trailing: Text(
                        Utility.formatCurrency(
                            purchase.overallTotalPrice,
                            currencySymbol: localizations
                                .translate('currency'), trimZeroDecimals: true),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.green[800]),
                      ),
                      onTap: () {
                        _showPurchaseDetailDialog(context, purchase, localizations, purchaseProvider);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'purchasesScreenFAB',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPurchaseScreen()),
          );
          if (result == true || result == null) {
            await _getUniqueSuppliers();
          }
        },
        backgroundColor: Colors.grey[850],
        tooltip: localizations.translate('newPurchaseTitle'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}