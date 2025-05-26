// lib/screens/receipt_list_screen.dart
import 'package:flutter/material.dart';
import '../services/utility_services.dart'; //
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/receipt_provider.dart'; //
import '../l10n/app_localizations.dart'; //

// TŘÍDA PRO SOUHRN POLOŽEK
class ItemSummary {
  String name; //
  double quantity; //
  // Použijeme double pro množství
  double totalPrice; //

  ItemSummary({required this.name, this.quantity = 0.0, this.totalPrice = 0.0}); //

  void add(double quantity, double price) {
    this.quantity += quantity; //
    this.totalPrice += price; //
  }
}

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key}); //

  @override
  _ReceiptListScreenState createState() => _ReceiptListScreenState(); //
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  String? dateRangeText;

  // Filtrační parametry - v lokálním stavu
  bool showCash = true; //
  bool showCard = true; //
  bool showBank = true; //
  bool showOther = true; // Pro CRYPTO
  bool showWithDiscount = false; //

  // Definice barev pro typy plateb
  static const Color _cashColor = Color(0xFFFFF9C4); //
  // Jemně žlutá (Colors.yellow[100])
  static const Color _cardColor = Color(0xFFE3F2FD); //
  // Jemně modrá (Colors.blue[50]) - OPRAVA KOMENTÁŘE
  static const Color _bankColor = Color(0xFFC8E6C9); //
  // Jemně zelená (Colors.green[100]) - OPRAVA KOMENTÁŘE
  static const Color _otherColor = Color(0xFFF5F5F5); //
  // Jemně šedá (Colors.grey[100])


  @override
  void initState() {
    super.initState(); //
    WidgetsBinding.instance.addPostFrameCallback((_) { //
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
      if (receiptProvider.dateRange == null) {
        receiptProvider.updateDateRange(DateTimeRange(start: todayStart, end: todayEnd));
      }
      _updateDateRangeText(receiptProvider);
      _fetchReceipts();
    });
  }

  void _updateDateRangeText(ReceiptProvider receiptProvider) {
    final localizations = AppLocalizations.of(context)!; //
    if (receiptProvider.dateRange != null) { //
      final start = receiptProvider.dateRange!.start; //
      final end = receiptProvider.dateRange!.end; //
      if (start.year == end.year && start.month == end.month && start.day == end.day) { //
        dateRangeText = DateFormat('d.MM.yyyy').format(start); //
      } else {
        dateRangeText =
        '${DateFormat('d.MM.yyyy').format(start)} - ${DateFormat('d.MM.yyyy').format(end)}'; //
      }
    } else {
      dateRangeText = localizations.translate('noDateFilter'); //
    }
    if (mounted) { //
      setState(() {}); //
    }
  }

  static String _getPaymentInfo(
      AppLocalizations localizations, String paymentType, double total) {
    String paymentText;
    switch (paymentType) { //
      case 'CARD':
        paymentText = localizations.translate('cardPaymentType'); //
        break;
      case 'CASH':
        paymentText = localizations.translate('cashPaymentType'); //
        break;
      case 'BANK':
        paymentText = localizations.translate('bankPaymentType'); //
        break;
      case 'CRYPTO': // Změněno z 'OTHER'
        paymentText = localizations.translate('otherPaymentType'); // Stále zobrazujeme jako "Jiné"
        break;
      case 'OTHER': // Ponecháno pro případnou zpětnou kompatibilitu nebo jiný případ
      default:
        paymentText = localizations.translate('otherPaymentType'); //
        break;
    }
    String currencySymbol = localizations.translate('currency'); //
    return '$paymentText: ${Utility.formatCurrency(total, currencySymbol: currencySymbol.isNotEmpty ? currencySymbol : null)}'; //
  }

  Color _getPaymentColor(String paymentType) {
    switch (paymentType) {
      case 'CASH':
        return _cashColor; //
      case 'CARD':
        return _cardColor; //
      case 'BANK':
        return _bankColor; //
      case 'CRYPTO': // Změněno z 'OTHER'
        return _otherColor; // Stále používáme barvu pro "Jiné"
      case 'OTHER':
      default:
        return _otherColor; //
    }
  }

  Future<void> _fetchReceipts() async {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false); //
    try {
      await receiptProvider.fetchReceipts( //
        dateRange: receiptProvider.dateRange, //
        showCash: showCash, //
        showCard: showCard, //
        showBank: showBank, //
        showOther: showOther, //
        showWithDiscount: showWithDiscount, //
      );
    } catch (e) {
      if (mounted) { //
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.translate('errorFetchingReceipts'))) //
        );
      }
    } finally {
      if(mounted) { //
        _updateDateRangeText(receiptProvider); //
      }
    }
  }

  void _showDateRangePickerfilter(BuildContext context) async {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false); //
    DateTimeRange? initialRange = receiptProvider.dateRange; //
    if (initialRange == null) { //
      final now = DateTime.now();
      initialRange = DateTimeRange(start: now, end: now); //
    }

    DateTimeRange? selectedDateRange = await showDateRangePicker( //
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialRange,
      locale: Localizations.localeOf(context), //
    );
    if (selectedDateRange != null) { //
      receiptProvider.updateDateRange(selectedDateRange);
      await _fetchReceipts(); //
    }
  }

  void _showSortDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; //
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false); //

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.translate('sortReceipts')), //
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(localizations.translate('priceAscending')), //
                  onTap: () {
                    receiptProvider.sortReceipts('price', true); //
                    Navigator.of(context).pop(); //
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('priceDescending')), //
                  onTap: () {
                    receiptProvider.sortReceipts('price', false); //
                    Navigator.of(context).pop(); //
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('timeAscending')), //
                  onTap: () {
                    receiptProvider.sortReceipts('time', true); //
                    Navigator.of(context).pop(); //
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('timeDescending')), //
                  onTap: () {
                    receiptProvider.sortReceipts('time', false); //
                    Navigator.of(context).pop(); //
                  },
                ),
              ],
            ),
          ),
        );
      }, //
    );
  }

  void _showFilterDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; //
    showDialog( //
      context: context,
      builder: (BuildContext context) {
        bool tempShowCash = showCash; //
        bool tempShowCard = showCard; //
        bool tempShowBank = showBank; //
        bool tempShowOther = showOther; //
        bool tempShowWithDiscount = showWithDiscount; //

        return StatefulBuilder( //
          builder: (context, setStateDialog) => AlertDialog(
            title: Text(localizations.translate('receiptFiltersTitle')), //
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile( //
                    title: Text(localizations.translate('cashFilter')), //
                    value: tempShowCash, //
                    onChanged: (value) {
                      setStateDialog(() => tempShowCash = value); //
                    },
                  ),
                  SwitchListTile( //
                    title: Text(localizations.translate('cardFilter')), //
                    value: tempShowCard, //
                    onChanged: (value) {
                      setStateDialog(() => tempShowCard = value); //
                    }, //
                  ),
                  SwitchListTile( //
                    title: Text(localizations.translate('bankFilter')), //
                    value: tempShowBank, //
                    onChanged: (value) { //
                      setStateDialog(() => tempShowBank = value); //
                    },
                  ),
                  SwitchListTile( //
                    title: Text(localizations.translate('otherFilter')), //
                    value: tempShowOther, //
                    onChanged: (value) {
                      setStateDialog(() => tempShowOther = value); //
                    },
                  ),
                  SwitchListTile( //
                    title: Text(localizations.translate('discountFilter')), //
                    value: tempShowWithDiscount, //
                    onChanged: (value) {
                      setStateDialog(() => tempShowWithDiscount = value); //
                    },
                  ),
                ],
              ),
            ),
            actions: [ //
              TextButton( //
                onPressed: () {
                  Navigator.of(context).pop(); //
                },
                child: Text(localizations.translate('cancel')), //
              ),
              ElevatedButton( //
                onPressed: () {
                  setState(() { //
                    showCash = tempShowCash; //
                    showCard = tempShowCard; //
                    showBank = tempShowBank; //
                    showOther = tempShowOther; //
                    showWithDiscount = tempShowWithDiscount; //
                  });
                  _fetchReceipts(); //
                  Navigator.of(context).pop(); //
                },
                child: Text(localizations.translate('applyFilters')), //
              ),
            ], //
          ),
        );
      }, //
    );
  }

  void _showItemsSummaryDialog() {
    final localizations = AppLocalizations.of(context)!; //
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false); //
    final List<dynamic> currentReceipts = receiptProvider.receipts; //
    if (currentReceipts.isEmpty) { //
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('noReceiptsToSummarize'))), //
      );
      return; //
    }

    Map<String, ItemSummary> itemsSummary = {}; //
    for (var receipt in currentReceipts) { //
      if (receipt['items'] != null && receipt['items'] is List) { //
        for (var item in (receipt['items'] as List)) { //
          String itemName = item['text'] as String? ?? localizations.translate('unknownItem'); //
          double itemQuantity = (item['quantity'] as num?)?.toDouble() ?? 0.0; //
          double lineItemTotalPrice; //
          if (item['priceToPay'] != null) { //
            lineItemTotalPrice = (item['priceToPay'] as num).toDouble(); //
          } else {
            double singleUnitPrice = (item['itemPrice'] as num?)?.toDouble() ?? 0.0; //
            lineItemTotalPrice = singleUnitPrice * itemQuantity; //
          }
          itemsSummary.putIfAbsent(itemName, () => ItemSummary(name: itemName)) //
              .add(itemQuantity, lineItemTotalPrice); //
        }
      }
    }

    var sortedItems = itemsSummary.values.toList(); //
    sortedItems.removeWhere((item) => item.quantity == 0 && item.totalPrice == 0); //
    sortedItems.sort((a, b) => b.totalPrice.compareTo(a.totalPrice)); //
    showDialog( //
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(localizations.translate('itemSummaryDialogTitle')), //
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0), //
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView( //
              child: ListBody( //
                children: sortedItems.isEmpty
                    ? [Center(child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(localizations.translate('noItemsToSummarizeInDialog')), //
                ))]
                    : sortedItems.map((item) { //
                  String trimmedName = item.name.length > 25 ? '${item.name.substring(0, 25)}...' : item.name; //
                  String formattedQuantity;
                  if (item.quantity == item.quantity.truncateToDouble()) { //
                    formattedQuantity = item.quantity.toInt().toString(); //
                  } else {
                    formattedQuantity = NumberFormat("0.##", localizations.locale.languageCode).format(item.quantity); //
                  }
                  String currencySymbol = localizations.translate('currency'); //
                  return Padding( //
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded( //
                          child: Text(
                            "$formattedQuantity x $trimmedName",
                            style: const TextStyle(color: Colors.black, fontSize: 14), //
                          ),
                        ),
                        Text( //
                          "${item.totalPrice.toStringAsFixed(2)} ${currencySymbol.isNotEmpty ? currencySymbol : ''}",
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14), //
                        ),
                      ],
                    ),
                  );
                }).toList(), //
              ),
            ),
          ),
          actions: <Widget>[ //
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white, //
                backgroundColor: Colors.grey[850], //
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(localizations.translate('close')), //
            ),
          ], //
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!; //
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(localizations.translate('salesTitle'), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.functions, color: Colors.white),
            tooltip: localizations.translate('itemSummaryTooltip'),
            onPressed: _showItemsSummaryDialog, //
          ),
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            tooltip: localizations.translate('dateRangeTooltip'),
            onPressed: () {
              _showDateRangePickerfilter(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: localizations.translate('sortReceipts'),
            onPressed: () {
              _showSortDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_sharp, color: Colors.white),
            tooltip: localizations.translate('filterTooltip'),
            onPressed: () {
              _showFilterDialog(context); //
            },
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
              dateRangeText ?? '', //
              style: const TextStyle(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Consumer<ReceiptProvider>(
              builder: (context, provider, child) {
                // ZMĚNA PODMÍNKY PRO ZOBRAZENÍ INDIKÁTORU NAČÍTÁNÍ:
                if (provider.isLoading) {
                  return Center( //
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(localizations.translate('loadingData')),                      ],
                    ),
                  );
                }

                // Pokud není načítání a seznam účtenek je prázdný
                if (provider.receipts.isEmpty) { //
                  return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(localizations.translate('noReceiptsAvailable'), //
                            textAlign: TextAlign.center),
                      )
                  );
                }

                // Pokud je načítání dokončeno a jsou zde účtenky k zobrazení
                int totalReceipts = provider.receipts.length; //
                double totalValue = provider.receipts.fold<double>( //
                  0.0,
                      (sum, receipt) => sum + ((receipt['total'] as num?)?.toDouble() ?? 0.0), //
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container( //
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey, //
                          borderRadius: BorderRadius.circular(12.0), //
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, //
                          children: [
                            Flexible(
                              child: Text( //
                                '${localizations.translate("Total")}: ${Utility.formatCurrency(totalValue, currencySymbol: localizations.translate('currency'))}',
                                style: const TextStyle(
                                    fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis, //
                              ),
                            ),
                            const SizedBox(width: 10), //
                            Text(
                              '${localizations.translate("receiptsCountShort")}: $totalReceipts',
                              style: const TextStyle( //
                                  fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder( //
                        itemCount: provider.receipts.length, //
                        itemBuilder: (context, index) {
                          var receipt = provider.receipts[index]; //
                          DateTime dateTime = DateTime.parse(receipt['dateTime']); //
                          String formattedDateTime =
                              '${localizations.translate('date')}: ${DateFormat('dd.MM.yyyy').format(dateTime)} '
                              '${localizations.translate('time')}: ${DateFormat('HH:mm').format(dateTime)}';
                          Color cardColor = _getPaymentColor(receipt['paymentType']); //
                          return Card(
                            color: cardColor, //
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile( //
                              title: Text(
                                formattedDateTime,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start, //
                                children: [
                                  if (receipt['items'] != null && receipt['items'] is List)
                                    ...receipt['items'].map<Widget>((item) { //
                                      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0; //
                                      final itemPrice = (item['itemPrice'] as num?)?.toDouble() ?? 0.0; //
                                      final isNegative = quantity < 0 || itemPrice < 0; //
                                      String formattedQuantity;
                                      if (quantity == quantity.truncateToDouble()) { //
                                        formattedQuantity = quantity.toInt().toString();
                                      } else {
                                        formattedQuantity = NumberFormat("0.##", localizations.locale.languageCode).format(quantity); //
                                      }
                                      return Text(
                                        '$formattedQuantity x ${item['text']}: ${Utility.formatCurrency(itemPrice, currencySymbol: localizations.translate('currency'))}',
                                        style: TextStyle( //
                                          fontSize: 14, //
                                          color: isNegative ? Colors.red : Colors.black, //
                                        ),
                                      );
                                    }).toList(), //
                                  const SizedBox(height: 10), //
                                  Align(
                                    alignment: Alignment.centerRight, //
                                    child: Text( //
                                      _getPaymentInfo( //
                                        localizations,
                                        receipt['paymentType'], //
                                        (receipt['total'] as num?)?.toDouble() ?? 0.0,
                                      ).toUpperCase(),
                                      style: const TextStyle( //
                                        color: Colors.black, //
                                        fontSize: 16, //
                                        fontWeight: FontWeight.bold, //
                                      ),
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