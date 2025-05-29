// lib/screens/receipt_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/receipt_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/utility_services.dart';

// Třída ItemSummary zůstává stejná
class ItemSummary {
  String name;
  double quantity;
  double totalPrice;
  ItemSummary({required this.name, this.quantity = 0.0, this.totalPrice = 0.0});
  void add(double quantity, double price) {
    this.quantity += quantity;
    totalPrice += price;
  }
}

class ReceiptListScreen extends StatefulWidget {
  final bool isSelected;
  const ReceiptListScreen({super.key, this.isSelected = false});

  @override
  _ReceiptListScreenState createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  String? dateRangeText;
  bool showCash = true;
  bool showCard = true;
  bool showBank = true;
  bool showOther = true;
  bool showWithDiscount = false;
  bool _initialDataLoaded = false;
  List<dynamic> _displayedReceipts = [];

  static const Color _cashColor = Color(0xFFFFF9C4);
  static const Color _cardColor = Color(0xFFE3F2FD);
  static const Color _bankColor = Color(0xFFC8E6C9);
  static const Color _otherColor = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    print("ReceiptListScreen: initState, isSelected: ${widget.isSelected}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadDataForScreen();
    });
  }

  @override
  void didUpdateWidget(covariant ReceiptListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("ReceiptListScreen: didUpdateWidget, isSelected: ${widget.isSelected}, oldWidget.isSelected: ${oldWidget.isSelected}, _initialDataLoaded: $_initialDataLoaded");
    if (widget.isSelected && (!oldWidget.isSelected || !_initialDataLoaded)) {
      print("ReceiptListScreen: Obrazovka se stala aktivní nebo data vyžadují obnovu.");
      _loadDataForScreen(forceLoad: true);
    } else if (!widget.isSelected) {
      _initialDataLoaded = false;
      print("ReceiptListScreen: Obrazovka již není aktivní.");
    }
  }

  Future<void> _loadDataForScreen({bool forceLoad = false}) async {
    if (!mounted) return;
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return;

    if (receiptProvider.currentDateRange == null) {
      final now = DateTime.now();
      // ***** ZMĚNA ZDE: Výchozí datumový rozsah nastaven na AKTUÁLNÍ DEN *****
      final defaultStart = DateTime(now.year, now.month, now.day);
      final defaultEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      // ***** KONEC ZMĚNY *****
      receiptProvider.updateDateRange(DateTimeRange(start: defaultStart, end: defaultEnd));
      print("ReceiptListScreen: currentDateRange v provideru byl null, nastaven na výchozí (aktuální den).");
    }

    _updateDateRangeText(receiptProvider);

    if (widget.isSelected || forceLoad) {
      print("ReceiptListScreen: Podmínka pro fetch splněna. Volám provider.fetchReceipts.");

      if (receiptProvider.currentDateRange == null) {
        print("ReceiptListScreen: KRITICKÁ CHYBA - currentDateRange je stale null před voláním fetchReceipts i po inicializaci.");
        if (mounted) setState(() => _displayedReceipts = []);
        return;
      }

      try {
        List<dynamic> newReceipts = await receiptProvider.fetchReceipts(
          dateRange: receiptProvider.currentDateRange!,
          showCash: showCash,
          showCard: showCard,
          showBank: showBank,
          showOther: showOther,
          showWithDiscount: showWithDiscount,
        );
        if (mounted) {
          setState(() {
            _displayedReceipts = newReceipts;
          });
          if(widget.isSelected) {
            _initialDataLoaded = true;
          }
          print("ReceiptListScreen: Data načtena, _displayedReceipts aktualizován (${_displayedReceipts.length} položek). _initialDataLoaded: $_initialDataLoaded");
        }
      } catch (e) {
        print("ReceiptListScreen: Chyba při načítání dat v _loadDataForScreen: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localizations.translate('errorFetchingReceipts')))
          );
        }
      }
    }
  }

  void _updateDateRangeText(ReceiptProvider receiptProvider) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null || !mounted) return;

    if (receiptProvider.currentDateRange != null) {
      final start = receiptProvider.currentDateRange!.start;
      final end = receiptProvider.currentDateRange!.end;
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        dateRangeText = DateFormat('d.MM.yyyy').format(start);
      } else {
        dateRangeText =
        '${DateFormat('d.MM.yyyy').format(start)} - ${DateFormat('d.MM.yyyy').format(end)}';
      }
    } else {
      dateRangeText = localizations.translate('noDateFilter');
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _sortDisplayedReceipts(String criteria, bool ascending) {
    if (!mounted) return;
    List<dynamic> sortedList = List.from(_displayedReceipts);
    sortedList.sort((a, b) {
      dynamic valueA;
      dynamic valueB;
      if (criteria == 'price') {
        valueA = (a['total'] as num?)?.toDouble() ?? 0.0;
        valueB = (b['total'] as num?)?.toDouble() ?? 0.0;
      } else if (criteria == 'time') {
        try {
          valueA = DateTime.parse(a['dateTime'] as String);
          valueB = DateTime.parse(b['dateTime'] as String);
        } catch (e) { return 0;}
      } else {
        return 0;
      }
      return ascending ? Comparable.compare(valueA, valueB) : Comparable.compare(valueB, valueA);
    });
    setState(() {
      _displayedReceipts = sortedList;
    });
  }

  static String _getPaymentInfo(AppLocalizations localizations, String paymentType, double total) {
    String paymentText;
    switch (paymentType) {
      case 'CARD': paymentText = localizations.translate('cardPaymentType'); break;
      case 'CASH': paymentText = localizations.translate('cashPaymentType'); break;
      case 'BANK': paymentText = localizations.translate('bankPaymentType'); break;
      case 'CRYPTO': default: paymentText = localizations.translate('otherPaymentType'); break;
    }
    String currencySymbol = localizations.translate('currency');
    return '$paymentText: ${Utility.formatCurrency(total, currencySymbol: currencySymbol.isNotEmpty ? currencySymbol : null)}';
  }

  Color _getPaymentColor(String paymentType) {
    switch (paymentType) {
      case 'CASH': return _cashColor;
      case 'CARD': return _cardColor;
      case 'BANK': return _bankColor;
      case 'CRYPTO': default: return _otherColor;
    }
  }

  void _showDateRangePickerfilter(BuildContext context) async {
    if (!mounted) return;
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return;

    DateTimeRange? initialRange = receiptProvider.currentDateRange;
    final now = DateTime.now();
    if (initialRange == null) { // Výchozí hodnota pro picker, pokud není nic v provideru
      initialRange = DateTimeRange(start: DateTime(now.year, now.month, now.day), end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999));
    }

    DateTimeRange? selectedDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialRange,
      locale: Localizations.localeOf(context),
      helpText: localizations.translate('dateRangeTooltip'),
      cancelText: localizations.translate('cancel'),
      confirmText: localizations.translate('applyFilters'),
    );
    if (selectedDateRange != null) {
      receiptProvider.updateDateRange(selectedDateRange);
      _loadDataForScreen(forceLoad: true);
    }
  }

  void _showSortDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null || !mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.translate('sortReceipts')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: Text(localizations.translate('priceAscending')), onTap: () { _sortDisplayedReceipts('price', true); Navigator.of(context).pop(); }),
                ListTile(title: Text(localizations.translate('priceDescending')), onTap: () { _sortDisplayedReceipts('price', false); Navigator.of(context).pop(); }),
                ListTile(title: Text(localizations.translate('timeAscending')), onTap: () { _sortDisplayedReceipts('time', true); Navigator.of(context).pop(); }),
                ListTile(title: Text(localizations.translate('timeDescending')), onTap: () { _sortDisplayedReceipts('time', false); Navigator.of(context).pop(); }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null || !mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool tempShowCash = showCash;
        bool tempShowCard = showCard;
        bool tempShowBank = showBank;
        bool tempShowOther = showOther;
        bool tempShowWithDiscount = showWithDiscount;

        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text(localizations.translate('receiptFiltersTitle')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(title: Text(localizations.translate('cashFilter')), value: tempShowCash, onChanged: (value) => setStateDialog(() => tempShowCash = value)),
                  SwitchListTile(title: Text(localizations.translate('cardFilter')), value: tempShowCard, onChanged: (value) => setStateDialog(() => tempShowCard = value)),
                  SwitchListTile(title: Text(localizations.translate('bankFilter')), value: tempShowBank, onChanged: (value) => setStateDialog(() => tempShowBank = value)),
                  SwitchListTile(title: Text(localizations.translate('otherFilter')), value: tempShowOther, onChanged: (value) => setStateDialog(() => tempShowOther = value)),
                  SwitchListTile(title: Text(localizations.translate('discountFilter')), value: tempShowWithDiscount, onChanged: (value) => setStateDialog(() => tempShowWithDiscount = value)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations.translate('cancel'))),
              ElevatedButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      showCash = tempShowCash;
                      showCard = tempShowCard;
                      showBank = tempShowBank;
                      showOther = tempShowOther;
                      showWithDiscount = tempShowWithDiscount;
                    });
                  }
                  _loadDataForScreen(forceLoad: true);
                  Navigator.of(context).pop();
                },
                child: Text(localizations.translate('applyFilters')),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showItemsSummaryDialog() {
    final localizations = AppLocalizations.of(context);
    if (localizations == null || !mounted) return;

    if (_displayedReceipts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('noReceiptsToSummarize'))),
      );
      return;
    }
    Map<String, ItemSummary> itemsSummary = {};
    for (var receipt in _displayedReceipts) {
      if (receipt['items'] != null && receipt['items'] is List) {
        for (var item in (receipt['items'] as List)) {
          String itemName = item['text'] as String? ?? localizations.translate('unknownItem');
          double itemQuantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
          double lineItemTotalPrice;
          if (item['priceToPay'] != null) {
            lineItemTotalPrice = (item['priceToPay'] as num).toDouble();
          } else {
            double singleUnitPrice = (item['itemPrice'] as num?)?.toDouble() ?? 0.0;
            lineItemTotalPrice = singleUnitPrice * itemQuantity;
          }
          itemsSummary.putIfAbsent(itemName, () => ItemSummary(name: itemName))
              .add(itemQuantity, lineItemTotalPrice);
        }
      }
    }
    var sortedItems = itemsSummary.values.toList();
    sortedItems.removeWhere((item) => item.quantity == 0 && item.totalPrice == 0);
    sortedItems.sort((a, b) => b.totalPrice.compareTo(a.totalPrice));
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(localizations.translate('itemSummaryDialogTitle')),
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: ListBody(
                children: sortedItems.isEmpty
                    ? [Center(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(localizations.translate('noItemsToSummarizeInDialog')),
                ))]
                    : sortedItems.map((item) {
                  String trimmedName = item.name.length > 25 ? '${item.name.substring(0, 25)}...' : item.name;
                  String formattedQuantity;
                  if (item.quantity == item.quantity.truncateToDouble()) {
                    formattedQuantity = item.quantity.toInt().toString();
                  } else {
                    formattedQuantity = NumberFormat("0.##", localizations.locale.languageCode).format(item.quantity);
                  }
                  String currencySymbol = localizations.translate('currency');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text("$formattedQuantity x $trimmedName", style: const TextStyle(color: Colors.black, fontSize: 14))),
                        Text("${item.totalPrice.toStringAsFixed(2)} ${currencySymbol.isNotEmpty ? currencySymbol : ''}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.grey[850]),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(localizations.translate('close')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return Scaffold(body: Center(child: CircularProgressIndicator()));

    final receiptProvider = context.watch<ReceiptProvider>(); // Sledujeme pro isLoading

    // Zobrazíme celoobrazovkový loader POUZE pokud:
    // 1. Provider načítá (receiptProvider.isLoading)
    // 2. Tato obrazovka je aktivní (widget.isSelected)
    // 3. A ZÁROVEŇ nemáme žádná data k zobrazení v naší lokální cache (_displayedReceipts je prázdný)
    final bool showFullScreenLoader = receiptProvider.isLoading && widget.isSelected && _displayedReceipts.isEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(localizations.translate('salesTitle'), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.functions, color: Colors.white), tooltip: localizations.translate('itemSummaryTooltip'), onPressed: _showItemsSummaryDialog),
          IconButton(icon: const Icon(Icons.date_range, color: Colors.white), tooltip: localizations.translate('dateRangeTooltip'), onPressed: () => _showDateRangePickerfilter(context)),
          IconButton(icon: const Icon(Icons.sort, color: Colors.white), tooltip: localizations.translate('sortReceipts'), onPressed: () => _showSortDialog(context)),
          IconButton(icon: const Icon(Icons.filter_alt_sharp, color: Colors.white), tooltip: localizations.translate('filterTooltip'), onPressed: () => _showFilterDialog(context)),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            color: Colors.grey[200],
            child: Text(
              dateRangeText ?? localizations.translate('noDateFilter'),
              style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Builder(
              builder: (context) {
                if (showFullScreenLoader) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(localizations.translate('loadingData')),
                      ],
                    ),
                  );
                }

                if (_displayedReceipts.isEmpty) {
                  return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(localizations.translate('noReceiptsAvailable'), textAlign: TextAlign.center),
                      )
                  );
                }

                int totalReceipts = _displayedReceipts.length;
                double totalValue = ReceiptProvider.calculateTotalRevenue(_displayedReceipts);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(12.0)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: Text('${localizations.translate("Total")}: ${Utility.formatCurrency(totalValue, currencySymbol: localizations.translate('currency'))}', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 10),
                            Text('${localizations.translate("receiptsCountShort")}: $totalReceipts', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _displayedReceipts.length,
                        itemBuilder: (context, index) {
                          var receipt = _displayedReceipts[index];
                          DateTime dateTime = DateTime.parse(receipt['dateTime']);
                          String formattedDateTime = '${localizations.translate('date')}: ${DateFormat('dd.MM.yyyy').format(dateTime)} ${localizations.translate('time')}: ${DateFormat('HH:mm').format(dateTime)}';
                          Color cardColor = _getPaymentColor(receipt['paymentType']);
                          return Card(
                            color: cardColor,
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              title: Text(formattedDateTime, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (receipt['items'] != null && receipt['items'] is List)
                                    ...receipt['items'].map<Widget>((item) {
                                      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                                      final itemPrice = (item['itemPrice'] as num?)?.toDouble() ?? 0.0;
                                      final isNegative = quantity < 0 || itemPrice < 0;
                                      String formattedQuantity;
                                      if (quantity == quantity.truncateToDouble()) {
                                        formattedQuantity = quantity.toInt().toString();
                                      } else {
                                        formattedQuantity = NumberFormat("0.##", localizations.locale.languageCode).format(quantity);
                                      }
                                      return Text('$formattedQuantity x ${item['text']}: ${Utility.formatCurrency(itemPrice, currencySymbol: localizations.translate('currency'))}', style: TextStyle(fontSize: 14, color: isNegative ? Colors.red : Colors.black));
                                    }).toList(),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _getPaymentInfo(localizations, receipt['paymentType'], (receipt['total'] as num?)?.toDouble() ?? 0.0).toUpperCase(),
                                      style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}