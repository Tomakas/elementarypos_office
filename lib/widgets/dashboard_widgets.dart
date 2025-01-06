import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/receipt_provider.dart';
import '../providers/product_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/utility_services.dart';

/// 1) Widget: Počet účtenek (Summary)
class SummaryWidget extends StatefulWidget {
  const SummaryWidget({Key? key}) : super(key: key);

  @override
  State<SummaryWidget> createState() => _SummaryWidgetState();
}

class _SummaryWidgetState extends State<SummaryWidget> {
  bool isLoading = false;
  int receiptsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);

    // Pro jistotu načteme i stavy účtenek (pokud se widget otevře poprvé).
    await receiptProvider.fetchReceipts();

    setState(() {
      receiptsCount = receiptProvider.receipts.length;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            localizations.translate('receiptsToday'),
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black,
            ),
          ),
          Text(
            receiptsCount.toString(),
            style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/// 2) Widget: TopProducts (tabulka nejprodávanějších produktů)
class TopProductsWidget extends StatefulWidget {
  const TopProductsWidget({Key? key}) : super(key: key);

  @override
  State<TopProductsWidget> createState() => _TopProductsWidgetState();
}

class _TopProductsWidgetState extends State<TopProductsWidget> {
  bool isLoading = false;
  List<Map<String, dynamic>> topProducts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);

    // Pokud nejsou receipts načteny, tak je můžeme načíst
    await receiptProvider.fetchReceipts();

    // Získáme top produkty
    topProducts = receiptProvider.getTopProducts(limit: 5);

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(6.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            localizations.translate('topSales'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12.0),
          // Záhlaví tabulky
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  localizations.translate('Product'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  localizations.translate('Amount'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  localizations.translate('Total'),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(),
          for (var product in topProducts)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(product['name']),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      product['quantity'].toStringAsFixed(0),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      Utility.formatCurrency(product['revenue']),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 3) Widget: TopCategories (tabulka nejprodávanějších kategorií)
class TopCategoriesWidget extends StatefulWidget {
  const TopCategoriesWidget({Key? key}) : super(key: key);

  @override
  State<TopCategoriesWidget> createState() => _TopCategoriesWidgetState();
}

class _TopCategoriesWidgetState extends State<TopCategoriesWidget> {
  bool isLoading = false;
  List<Map<String, dynamic>> topCategories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    // Načíst receipts
    await receiptProvider.fetchReceipts();
    // Načíst products (protože ve getTopCategories je volán productProvider.getProductByName)
    await productProvider.fetchProducts();

    // Nyní z receiptProvideru vytáhneme top kategorie
    topCategories = receiptProvider.getTopCategories(
      limit: 5,
      productProvider: productProvider,
    );

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(6.0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            localizations.translate('topCategories'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12.0),
          // Záhlaví
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  localizations.translate('category'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  localizations.translate('Amount'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  localizations.translate('Total'),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(),
          for (var category in topCategories)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(category['name']),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      category['quantity'].toStringAsFixed(0),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      Utility.formatCurrency(category['revenue']),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 4) Widget: Hodinový graf tržeb (Hourly Graph)
class HourlyGraphWidget extends StatefulWidget {
  const HourlyGraphWidget({Key? key}) : super(key: key);

  @override
  State<HourlyGraphWidget> createState() => _HourlyGraphWidgetState();
}

class _HourlyGraphWidgetState extends State<HourlyGraphWidget> {
  bool isLoading = false;
  List<double> hourlyRevenue = List.filled(24, 0.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);

    // Načíst receipts
    await receiptProvider.fetchReceipts();

    // Naplnit hourlyRevenue
    final receipts = receiptProvider.receipts;
    for (int i = 0; i < 24; i++) {
      hourlyRevenue[i] = 0.0;
    }
    for (var receipt in receipts) {
      if (receipt['dateTime'] != null && receipt['total'] != null) {
        try {
          final date = DateTime.parse(receipt['dateTime']);
          final revenue = (receipt['total'] as num).toDouble();
          if (date.hour >= 0 && date.hour < 24) {
            hourlyRevenue[date.hour] += revenue;
          }
        } catch (_) {}
      }
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Najít min a max. Určíme range
    int minHour = hourlyRevenue.indexWhere((value) => value > 0);
    int maxHour = hourlyRevenue.lastIndexWhere((value) => value > 0);
    final maxValue = (hourlyRevenue.isNotEmpty)
        ? hourlyRevenue.reduce((a, b) => a > b ? a : b)
        : 0.0;

    // Pokud nenajdeme nic, dáme standard 8..18
    if (minHour == -1) minHour = 8;
    if (maxHour == -1) maxHour = 18;
    if (minHour > maxHour) {
      // fallback
      minHour = 8;
      maxHour = 18;
    }

    final barGroups = <BarChartGroupData>[];
    for (int hour = minHour; hour <= maxHour; hour++) {
      barGroups.add(
        BarChartGroupData(
          x: hour,
          barRods: [
            BarChartRodData(
              toY: hourlyRevenue[hour],
              color: Colors.blueAccent,
              width: 16,
            ),
          ],
        ),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(6.0),
      color: Colors.white,
      child: Column(
        children: [
          Center(
            child: Text(
              localizations.translate('hourlyGraph'),
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == maxValue) {
                          return const Text('');
                        }
                        return Text(Utility.formatCurrency(value, decimals: 0),
                            style: const TextStyle(fontSize: 12));
                      },
                      reservedSize: 40,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        if (hour >= minHour && hour <= maxHour) {
                          return Text(hour.toString());
                        }
                        return const Text('');
                      },
                      reservedSize: 20,
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5) Widget: Payment Pie Chart (koláčový graf tržeb podle typu platby)
class PaymentPieChartWidget extends StatefulWidget {
  const PaymentPieChartWidget({Key? key}) : super(key: key);

  @override
  State<PaymentPieChartWidget> createState() => _PaymentPieChartWidgetState();
}

class _PaymentPieChartWidgetState extends State<PaymentPieChartWidget> {
  bool isLoading = false;
  final Map<String, double> paymentData = {};

  @override
  void initState() {
    super.initState();
    paymentData.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context)!;

    // Načíst receipts
    await receiptProvider.fetchReceipts();

    // Payment data
    paymentData[localizations.translate('cashPaymentType')] = 0.0;
    paymentData[localizations.translate('cardPaymentType')] = 0.0;
    paymentData[localizations.translate('bankPaymentType')] = 0.0;
    paymentData[localizations.translate('otherPaymentType')] = 0.0;

    for (var receipt in receiptProvider.receipts) {
      final paymentType = receipt['paymentType'];
      final total = (receipt['total'] as num?)?.toDouble() ?? 0.0;

      if (paymentType == 'CASH') {
        paymentData[localizations.translate('cashPaymentType')] =
            (paymentData[localizations.translate('cashPaymentType')] ?? 0.0) +
                total;
      } else if (paymentType == 'CARD') {
        paymentData[localizations.translate('cardPaymentType')] =
            (paymentData[localizations.translate('cardPaymentType')] ?? 0.0) +
                total;
      } else if (paymentType == 'BANK') {
        paymentData[localizations.translate('bankPaymentType')] =
            (paymentData[localizations.translate('bankPaymentType')] ?? 0.0) +
                total;
      } else {
        paymentData[localizations.translate('otherPaymentType')] =
            (paymentData[localizations.translate('otherPaymentType')] ?? 0.0) +
                total;
      }
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalRevenue = paymentData.values.fold(0.0, (sum, val) => sum + val);
    final paymentColors = {
      localizations.translate('cashPaymentType'): Colors.yellow,
      localizations.translate('cardPaymentType'): Colors.blue,
      localizations.translate('bankPaymentType'): Colors.red,
      localizations.translate('otherPaymentType'): Colors.grey,
    };

    final chartSections = paymentData.entries.map((entry) {
      final value = entry.value;
      final percentage = (totalRevenue > 0)
          ? (value / totalRevenue * 100).toDouble()
          : 0.0;

      return PieChartSectionData(
        color: paymentColors[entry.key],
        value: percentage,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold,
        ),
      );
    }).toList();

    // Legenda
    final legendItems = paymentData.keys.map((key) {
      return Padding(
        padding: const EdgeInsets.all(6.0),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              color: paymentColors[key],
              margin: const EdgeInsets.all(2.0),
            ),
            Text(key, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(6.0),
      height: 300,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 30),
          Center(
            child: Text(
              localizations.translate('salesByPaymentType'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sections: chartSections,
                      centerSpaceRadius: 0,
                      sectionsSpace: 4,
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: legendItems,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 6) Widget: TodayRevenue (blok s dnešní tržbou)
class TodayRevenueWidget extends StatefulWidget {
  const TodayRevenueWidget({Key? key}) : super(key: key);

  @override
  State<TodayRevenueWidget> createState() => _TodayRevenueWidgetState();
}

class _TodayRevenueWidgetState extends State<TodayRevenueWidget> {
  bool isLoading = false;
  double todayRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);

    // Můžeme například omezit data na dnešní den (dle logiky).
    final now = DateTime.now();
    receiptProvider.updateDateRange(
      DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
    );
    await receiptProvider.fetchReceipts();

    // Sečteme
    todayRevenue = 0.0;
    for (var r in receiptProvider.receipts) {
      todayRevenue += (r['total'] as num?)?.toDouble() ?? 0.0;
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            localizations.translate('todayRevenue'),
            style: const TextStyle(
              fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            Utility.formatCurrency(todayRevenue),
            style: const TextStyle(
              fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
