import 'package:flutter/material.dart';
import '../services/utility_services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/receipt_provider.dart';
import '../l10n/app_localizations.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  _ReceiptListScreenState createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  String? dateRangeText;

  // Filtrační parametry - v lokálním stavu
  bool showCash = true;
  bool showCard = true;
  bool showBank = true;
  bool showOther = true;
  bool showWithDiscount = false;

  List<dynamic> _receipts = []; // Lokální seznam účtenek

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
      receiptProvider.updateDateRange(DateTimeRange(start: todayStart, end: todayEnd));

      _fetchReceipts().then((_) {
        _updateDateRangeText(receiptProvider);
      });
    });
  }

  // Pomocná metoda pro aktualizaci textu data
  void _updateDateRangeText(ReceiptProvider receiptProvider) {
    final localizations = AppLocalizations.of(context)!;
    if (receiptProvider.dateRange != null) {
      final start = receiptProvider.dateRange!.start;
      final end = receiptProvider.dateRange!.end;
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        dateRangeText = DateFormat('d.MM.yyyy').format(start);
      } else {
        dateRangeText =
        '${DateFormat('d.MM.yyyy').format(start)} - ${DateFormat('d.MM.yyyy').format(end)}';
      }
    } else {
      dateRangeText = localizations.translate('noDateFilter');
    }
    setState(() {});
  }

  static String _formatPaymentLine(
      AppLocalizations localizations, String paymentType, double total) {
    String paymentText;
    switch (paymentType) {
      case 'CARD':
        paymentText = localizations.translate('cardPaymentType');
        break;
      case 'CASH':
        paymentText = localizations.translate('cashPaymentType');
        break;
      case 'BANK':
        paymentText = localizations.translate('bankPaymentType');
        break;
      case 'OTHER':
      default:
        paymentText = localizations.translate('otherPaymentType');
        break;
    }
    return '$paymentText: ${Utility.formatCurrency(total)}';
  }


  // Upravená metoda _fetchReceipts - volá metodu z provideru
  Future<void> _fetchReceipts() async {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    setState(() => receiptProvider.isLoading = true);

    try {
      // Předání filtračních parametrů do provideru
      await receiptProvider.fetchReceipts(
        dateRange: receiptProvider.dateRange,
        showCash: showCash,
        showCard: showCard,
        showBank: showBank,
        showOther: showOther,
        showWithDiscount: showWithDiscount,
      );

      // Získání filtrovaných dat z provideru
      _receipts = receiptProvider.receipts;

      print('Filtered Receipts: ${_receipts.length}');
    } catch (e) {
      print('Error while getting Receipts: $e');
    } finally {
      setState(() => receiptProvider.isLoading = false);
    }
  }

  // Upravená metoda _showDateRangePickerfilter - volá _fetchReceipts
  void _showDateRangePickerfilter(BuildContext context) async {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    DateTimeRange? selectedDateRange;
    selectedDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: receiptProvider.dateRange,
    );
    if (selectedDateRange != null) {
      receiptProvider.updateDateRange(selectedDateRange);
      await _fetchReceipts(); // Aktualizace seznamu účtenek
      _updateDateRangeText(receiptProvider);
    }
  }

  // Upravená metoda _showSortDialog - pracuje s lokálním seznamem
  void _showSortDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.translate('sortReceipts')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(localizations.translate('priceAscending')),
                  onTap: () {
                    setState(() {
                      _receipts.sort((a, b) => (a['total'] as num).compareTo((b['total'] as num)));
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('priceDescending')),
                  onTap: () {
                    setState(() {
                      _receipts.sort((a, b) => (b['total'] as num).compareTo((a['total'] as num)));
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('timeAscending')),
                  onTap: () {
                    setState(() {
                      _receipts.sort((a, b) => DateTime.parse(a['dateTime']).compareTo(DateTime.parse(b['dateTime'])));
                    });
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('timeDescending')),
                  onTap: () {
                    setState(() {
                      _receipts.sort((a, b) => DateTime.parse(b['dateTime']).compareTo(DateTime.parse(a['dateTime'])));
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

  // Upravená metoda _showFilterDialog - pracuje s lokálním stavem
  void _showFilterDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(localizations.translate('receiptFiltersTitle')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(localizations.translate('cashFilter')),
                    value: showCash,
                    onChanged: (value) {
                      setState(() => showCash = value);
                      _fetchReceipts();
                    },
                  ),
                  SwitchListTile(
                    title: Text(localizations.translate('cardFilter')),
                    value: showCard,
                    onChanged: (value) {
                      setState(() => showCard = value);
                      _fetchReceipts();
                    },
                  ),
                  SwitchListTile(
                    title: Text(localizations.translate('bankFilter')),
                    value: showBank,
                    onChanged: (value) {
                      setState(() => showBank = value);
                      _fetchReceipts();
                    },
                  ),
                  SwitchListTile(
                    title: Text(localizations.translate('otherFilter')),
                    value: showOther,
                    onChanged: (value) {
                      setState(() => showOther = value);
                      _fetchReceipts();
                    },
                  ),
                  SwitchListTile(
                    title: Text(localizations.translate('discountFilter')),
                    value: showWithDiscount,
                    onChanged: (value) {
                      setState(() => showWithDiscount = value);
                      _fetchReceipts();
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(localizations.translate('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final receiptProvider = Provider.of<ReceiptProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title:
        Text(localizations.translate('salesTitle'), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        actions: <Widget>[
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
              _showFilterDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Widget pro zobrazení vybraného data/rozmezí dat (nezávislý na Consumer)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            color: Colors.grey[200],
            child: Text(
              dateRangeText ?? '', // Použijeme naši proměnnou
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
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                int totalReceipts = _receipts.length; // Použití lokálního seznamu
                double totalValue = _receipts.fold<double>(
                  0.0,
                      (sum, receipt) => sum + (receipt['total'] ?? 0.0),
                );

                if (totalReceipts == 0) {
                  return Center(
                    child: Text(localizations.translate('noReceiptsAvailable')),
                  );
                }

                return Column(
                  children: [
                    // Widget pro zobrazení celkového počtu a hodnoty
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${localizations.translate("Total")}: ${Utility.formatCurrency(totalValue)}',
                              style: const TextStyle(
                                  fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${localizations.translate("receiptsCountShort")}: $totalReceipts',
                              style: const TextStyle(
                                  fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ListView
                    Expanded(
                      child: ListView.builder(
                        itemCount: _receipts.length, // Použití lokálního seznamu
                        itemBuilder: (context, index) {
                          var receipt = _receipts[index];
                          DateTime dateTime = DateTime.parse(receipt['dateTime']);
                          String formattedDateTime =
                              '${localizations.translate('date')}: ${DateFormat('dd.MM.yyyy').format(dateTime)} '
                              '${localizations.translate('time')}: ${DateFormat('HH:mm').format(dateTime)}';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: ListTile(
                              title: Text(
                                formattedDateTime,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (receipt['items'] != null && receipt['items'] is List)
                                    ...receipt['items'].map<Widget>((item) {
                                      final quantity = item['quantity'] ?? 0;
                                      final itemPrice = item['itemPrice'] ?? 0.0;
                                      final isNegative = quantity < 0 || itemPrice < 0;
                                      return Text(
                                        '${quantity}x ${item['text']}: ${Utility.formatCurrency(itemPrice)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isNegative ? Colors.red : Colors.black,
                                        ),
                                      );
                                    }).toList(),
                                  const SizedBox(height: 10),
                                  Text(
                                    _formatPaymentLine(
                                      localizations,
                                      receipt['paymentType'],
                                      receipt['total'],
                                    ).toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
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