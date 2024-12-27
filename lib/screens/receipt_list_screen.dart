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
  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    receiptProvider.updateDateRange(DateTimeRange(start: todayStart, end: todayEnd));
  }

  static String _formatPaymentLine(AppLocalizations localizations, String paymentType, double total) {
    final numberFormat = NumberFormat.currency(
      locale: 'cs_CZ',
      symbol: '',
      decimalDigits: 2,
    );
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

  @override
  Widget build(BuildContext context) {
    final receiptProvider = Provider.of<ReceiptProvider>(context);
    final localizations = AppLocalizations.of(context)!;

    String dateRangeText;
    if (receiptProvider.dateRange != null) {
      final start = receiptProvider.dateRange!.start;
      final end = receiptProvider.dateRange!.end;
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        // Pokud je rozsah jednoho dne
        dateRangeText = DateFormat('d.MM.yyyy').format(start);
      } else {
        // Pokud je rozsah více dnů
        dateRangeText =
        '${DateFormat('d.MM.yyyy').format(start)} - ${DateFormat('d.MM.yyyy').format(end)}';
      }
    } else {
      dateRangeText = localizations.translate('noDateFilter');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('salesTitle'), style: const TextStyle(color: Colors.white)),
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
      body: Consumer<ReceiptProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          int totalReceipts = provider.receipts.length;
          double totalValue = provider.receipts.fold<double>(
            0.0,
                (sum, receipt) => sum + (receipt['total'] ?? 0.0),
          );

          final numberFormat = NumberFormat.currency(
            locale: 'cs_CZ',
            symbol: '',
            decimalDigits: 2,
          );

          if (totalReceipts == 0) {
            return Center(
              child: Text(localizations.translate('noReceiptsAvailable')),
            );
          }

          return Column(
            children: [
              // Widget pro zobrazení vybraného data/rozmezí dat
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                color: Colors.grey[200],
                child: Text(
                  dateRangeText,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
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
                        style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${localizations.translate("receiptsCountShort")}: $totalReceipts',
                        style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              // ListView pro zobrazení účtenek
              Expanded(
                child: ListView.builder(
                  itemCount: provider.receipts.length,
                  itemBuilder: (context, index) {
                    var receipt = provider.receipts[index];
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
                                final numberFormat = NumberFormat.currency(
                                  locale: 'cs_CZ',
                                  symbol: '',
                                  decimalDigits: 2,
                                );
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
    );
  }

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
    }
  }

  void _showSortDialog(BuildContext context) {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
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
                    _sortReceipts(receiptProvider, 'price', true);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('priceDescending')),
                  onTap: () {
                    _sortReceipts(receiptProvider, 'price', false);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('timeAscending')),
                  onTap: () {
                    _sortReceipts(receiptProvider, 'time', true);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('timeDescending')),
                  onTap: () {
                    _sortReceipts(receiptProvider, 'time', false);
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

  void _sortReceipts(ReceiptProvider provider, String criteria, bool ascending) {
    provider.receipts.sort((a, b) {
      dynamic valueA;
      dynamic valueB;
      if (criteria == 'price') {
        valueA = a['total'];
        valueB = b['total'];
      } else if (criteria == 'time') {
        valueA = DateTime.parse(a['dateTime']);
        valueB = DateTime.parse(b['dateTime']);
      }
      if (ascending) {
        return Comparable.compare(valueA, valueB);
      } else {
        return Comparable.compare(valueB, valueA);
      }
    });
    provider.notifyListeners();
  }

  void _showFilterDialog(BuildContext context) {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.translate('receiptFiltersTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(localizations.translate('cashPaymentType')),
                  value: context.watch<ReceiptProvider>().showCash,
                  onChanged: (value) {
                    context.read<ReceiptProvider>().updateFilters(showCash: value);
                  },
                ),
                SwitchListTile(
                  title: Text(localizations.translate('cardPaymentType')),
                  value: context.watch<ReceiptProvider>().showCard,
                  onChanged: (value) {
                    context.read<ReceiptProvider>().updateFilters(showCard: value);
                  },
                ),
                SwitchListTile(
                  title: Text(localizations.translate('bankPaymentType')),
                  value: context.watch<ReceiptProvider>().showBank,
                  onChanged: (value) {
                    context.read<ReceiptProvider>().updateFilters(showBank: value);
                  },
                ),
                SwitchListTile(
                  title: Text(localizations.translate('otherPaymentType')),
                  value: context.watch<ReceiptProvider>().showOther,
                  onChanged: (value) {
                    context.read<ReceiptProvider>().updateFilters(showOther: value);
                  },
                ),
                SwitchListTile(
                  title: Text(localizations.translate('onlyDiscounts')),
                  value: context.watch<ReceiptProvider>().showWithDiscount,
                  onChanged: (value) {
                    context.read<ReceiptProvider>().updateFilters(showWithDiscount: value);
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
        );
      },
    );
  }
}
