// lib/screens/receipt_list_screen.dart
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
      // Při první inicializaci nastavíme defaultní rozsah na dnešek v provideru
      if (receiptProvider.dateRange == null) {
        receiptProvider.updateDateRange(DateTimeRange(start: todayStart, end: todayEnd));
      }
      // A aktualizujeme text zobrazený na obrazovce
      _updateDateRangeText(receiptProvider);

      // Načteme účtenky s aktuálně nastaveným filtrem v provideru (nebo s výchozím, pokud žádný není)
      _fetchReceipts();
    });
  }

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
    if (mounted) {
      setState(() {});
    }
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

  Future<void> _fetchReceipts() async {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    try {
      await receiptProvider.fetchReceipts(
        dateRange: receiptProvider.dateRange, // Použijeme dateRange z providera
        showCash: showCash,
        showCard: showCard,
        showBank: showBank,
        showOther: showOther,
        showWithDiscount: showWithDiscount,
      );
      print('Filtered Receipts (from provider): ${receiptProvider.receipts.length}');
    } catch (e) {
      print('Error while getting Receipts: $e');
    } finally {
      if(mounted) {
        _updateDateRangeText(receiptProvider);
      }
    }
  }

  void _showDateRangePickerfilter(BuildContext context) async {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    DateTimeRange? selectedDateRange;
    selectedDateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)), // Umožníme výběr i budoucích dat pro případné plánování
      initialDateRange: receiptProvider.dateRange,
    );
    if (selectedDateRange != null) {
      receiptProvider.updateDateRange(selectedDateRange); // Aktualizujeme dateRange v provideru
      await _fetchReceipts();
    }
  }

  void _showSortDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);

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
                    receiptProvider.sortReceipts('price', true);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('priceDescending')),
                  onTap: () {
                    receiptProvider.sortReceipts('price', false);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('timeAscending')),
                  onTap: () {
                    receiptProvider.sortReceipts('time', true);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('timeDescending')),
                  onTap: () {
                    receiptProvider.sortReceipts('time', false);
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

  void _showFilterDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
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
                  SwitchListTile(
                    title: Text(localizations.translate('cashFilter')),
                    value: tempShowCash,
                    onChanged: (value) {
                      setStateDialog(() => tempShowCash = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(localizations.translate('cardFilter')),
                    value: tempShowCard,
                    onChanged: (value) {
                      setStateDialog(() => tempShowCard = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(localizations.translate('bankFilter')),
                    value: tempShowBank,
                    onChanged: (value) {
                      setStateDialog(() => tempShowBank = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(localizations.translate('otherFilter')),
                    value: tempShowOther,
                    onChanged: (value) {
                      setStateDialog(() => tempShowOther = value);
                    },
                  ),
                  SwitchListTile(
                    title: Text(localizations.translate('discountFilter')),
                    value: tempShowWithDiscount,
                    onChanged: (value) {
                      setStateDialog(() => tempShowWithDiscount = value);
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
                  setState(() {
                    showCash = tempShowCash;
                    showCard = tempShowCard;
                    showBank = tempShowBank;
                    showOther = tempShowOther;
                    showWithDiscount = tempShowWithDiscount;
                  });
                  _fetchReceipts();
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
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title:
        Text(localizations.translate('salesTitle'), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: localizations.translate('dateRangeTooltip'),
            onPressed: () {
              _showDateRangePickerfilter(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: localizations.translate('sortReceipts'),
            onPressed: () {
              _showSortDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_sharp),
            tooltip: localizations.translate('filterTooltip'),
            onPressed: () {
              _showFilterDialog(context);
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
              dateRangeText ?? '',
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
                if (provider.isLoading && provider.receipts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                int totalReceipts = provider.receipts.length;
                double totalValue = provider.receipts.fold<double>(
                  0.0,
                      (sum, receipt) => sum + ((receipt['total'] as num?)?.toDouble() ?? 0.0),
                );

                if (totalReceipts == 0 && !provider.isLoading) {
                  return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(localizations.translate('noReceiptsAvailable'), textAlign: TextAlign.center),
                      )
                  );
                }

                return Column(
                  children: [
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
                            Flexible( // Přidáno Flexible pro zalamování textu
                              child: Text(
                                '${localizations.translate("Total")}: ${Utility.formatCurrency(totalValue)}',
                                style: const TextStyle(
                                    fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 10), // Mezera
                            Text(
                              '${localizations.translate("receiptsCountShort")}: $totalReceipts',
                              style: const TextStyle(
                                  fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                                      final quantity = (item['quantity'] as num?)?.toDouble() ?? 0.0;
                                      final itemPrice = (item['itemPrice'] as num?)?.toDouble() ?? 0.0;
                                      final isNegative = quantity < 0 || itemPrice < 0;

                                      String formattedQuantity;
                                      if (quantity == quantity.truncateToDouble()) {
                                        formattedQuantity = quantity.toInt().toString();
                                      } else {
                                        formattedQuantity = NumberFormat("0.##", localizations.locale.languageCode).format(quantity);
                                      }

                                      return Text(
                                        // OPRAVA ZDE:
                                        '${formattedQuantity}x ${item['text']}: ${Utility.formatCurrency(itemPrice)}',
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
                                      (receipt['total'] as num?)?.toDouble() ?? 0.0,
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