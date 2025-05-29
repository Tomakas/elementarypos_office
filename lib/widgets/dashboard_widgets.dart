// lib/widgets/dashboard_widgets.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Pouze pokud je skutečně používán zde
import '../providers/receipt_provider.dart'; // Pro statické metody a ProductProvider
import '../l10n/app_localizations.dart';
import '../services/utility_services.dart';

/// 1) Widget: Souhrn (dříve Počet účtenek)
class SummaryWidget extends StatelessWidget {
  final List<dynamic> receipts; // NOVÝ PARAMETR

  const SummaryWidget({super.key, required this.receipts}); // UPRAVENÝ KONSTRUKTOR

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // final receiptProvider = context.watch<ReceiptProvider>(); // JIŽ NEPOTŘEBUJEME PRO receipts

    // Pokud by se zde měl zobrazovat loading indikátor, musel by být řízen z DashboardScreen
    // nebo by tento widget přijal další parametr `isLoading`. Pro jednoduchost předpokládáme,
    // že DashboardScreen zobrazí globální loader nebo předá data až když jsou připravena.
    // if (isLoading && receipts.isEmpty) {
    //   return const Center(child: CircularProgressIndicator());
    // }

    final receiptsCount = receipts.length; // Používáme předaný seznam

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
            localizations.translate('receiptsToday'), // Nebo obecnější 'receiptsCount' pokud data nejsou jen pro dnešek
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

/// 2) Widget: TopProducts
class TopProductsWidget extends StatelessWidget {
  // Přijímá již zpracovaná data
  final List<Map<String, dynamic>> topProductsData;

  const TopProductsWidget({super.key, required this.topProductsData});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (topProductsData.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(localizations.translate('noDataForTopProducts'), style: TextStyle(color: Colors.grey[600])),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            localizations.translate('topSales'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 4,
                child: Text(localizations.translate('Product'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: Text(localizations.translate('Amount'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 3,
                child: Text(localizations.translate('Total'), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(),
          for (var product in topProductsData) // Používáme předaná data
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(flex: 4, child: Text(product['name'] ?? '')),
                  Expanded(flex: 2, child: Text((product['quantity'] as num?)?.toStringAsFixed(0) ?? "0", textAlign: TextAlign.center)),
                  Expanded(flex: 3, child: Text(Utility.formatCurrency((product['revenue'] as num?)?.toDouble() ?? 0.0), textAlign: TextAlign.right)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 3) Widget: TopCategories
class TopCategoriesWidget extends StatelessWidget {
  // Přijímá již zpracovaná data
  final List<Map<String, dynamic>> topCategoriesData;

  const TopCategoriesWidget({super.key, required this.topCategoriesData});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    if (topCategoriesData.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(localizations.translate('noDataForTopCategories'), style: TextStyle(color: Colors.grey[600])),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(localizations.translate('topCategories'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(flex: 4, child: Text(localizations.translate('category'), style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text(localizations.translate('Amount'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: Text(localizations.translate('Total'), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(),
          for (var category in topCategoriesData) // Používáme předaná data
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(flex: 4, child: Text(category['name'] ?? '')),
                  Expanded(flex: 2, child: Text((category['quantity'] as num?)?.toStringAsFixed(0) ?? "0", textAlign: TextAlign.center)),
                  Expanded(flex: 3, child: Text(Utility.formatCurrency((category['revenue'] as num?)?.toDouble() ?? 0.0), textAlign: TextAlign.right)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


/// 4) Widget: Hodinový graf tržeb (Hourly Graph)
class HourlyGraphWidget extends StatelessWidget {
  final List<dynamic> receipts; // NOVÝ PARAMETR

  const HourlyGraphWidget({super.key, required this.receipts}); // UPRAVENÝ KONSTRUKTOR

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // final receiptProvider = context.watch<ReceiptProvider>(); // JIŽ NEPOTŘEBUJEME

    List<double> hourlyRevenue = List.filled(24, 0.0);
    for (var receipt in receipts) { // Používáme předaný seznam
      if (receipt['dateTime'] != null && receipt['total'] != null) {
        try {
          final date = DateTime.parse(receipt['dateTime']);
          final revenue = (receipt['total'] as num?)?.toDouble() ?? 0.0;
          if (date.hour >= 0 && date.hour < 24) {
            hourlyRevenue[date.hour] += revenue;
          }
        } catch (_) {}
      }
    }

    bool hasData = hourlyRevenue.any((value) => value > 0);
    if (!hasData) { // Pokud nejsou data, zobrazíme zprávu
      return Center(child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(localizations.translate('noDataForHourlyGraph'), style: TextStyle(color: Colors.grey[600])),
      ));
    }

    // ... (zbytek logiky pro minHour, maxHour, maxValue, barGroups zůstává stejný, ale pracuje s lokální hourlyRevenue)
    int minHour = hourlyRevenue.indexWhere((value) => value > 0);
    int maxHour = hourlyRevenue.lastIndexWhere((value) => value > 0);
    final maxValue = (hourlyRevenue.isNotEmpty)
        ? hourlyRevenue.reduce((a, b) => a > b ? a : b)
        : 0.0;
    if (minHour == -1) minHour = 8; // Defaultní zobrazený rozsah, pokud nejsou data
    if (maxHour == -1) maxHour = 18;
    if (minHour > maxHour) { minHour = 8; maxHour = 18; }


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
              borderRadius: BorderRadius.zero,
            ),
          ],
        ),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
            child: Text(
              localizations.translate('hourlyGraph'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: barGroups,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 && maxValue == 0) return const Text(''); // Pro případ nulových dat
                        if (value == 0) return const Text('');
                        if (maxValue > 0 && (value == maxValue || value % (maxValue / 4).ceilToDouble() == 0)) {
                          return Text(Utility.formatCurrency(value, decimals: 0, currencySymbol: ''), style: const TextStyle(fontSize: 10));
                        }
                        return const Text('');
                      },
                      reservedSize: 35,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        if (hour >= minHour && hour <= maxHour && hour % 2 == 0) { // Zobrazujeme každou druhou hodinu
                          return Padding(padding: const EdgeInsets.only(top:4.0), child: Text(hour.toString(), style: const TextStyle(fontSize: 10)));
                        }
                        return const Text('');
                      },
                      reservedSize: 22,
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.8),
                ),
                borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade400, width: 1.5),
                      left: BorderSide(color: Colors.grey.shade400, width: 1.5),
                    )
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String hourRange = '${group.x.toInt()}:00 - ${(group.x.toInt() + 1)}:00';
                      return BarTooltipItem(
                        '$hourRange\n',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        children: <TextSpan>[
                          TextSpan(
                            text: Utility.formatCurrency(rod.toY, decimals:0),
                            style: const TextStyle(color: Colors.yellow, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5) Widget: Payment Pie Chart
class PaymentPieChartWidget extends StatelessWidget {
  final List<dynamic> receipts; // NOVÝ PARAMETR

  const PaymentPieChartWidget({super.key, required this.receipts}); // UPRAVENÝ KONSTRUKTOR

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // final receiptProvider = context.watch<ReceiptProvider>(); // JIŽ NEPOTŘEBUJEME

    final Map<String, double> paymentData = {
      localizations.translate('cashPaymentType'): 0.0,
      localizations.translate('cardPaymentType'): 0.0,
      localizations.translate('bankPaymentType'): 0.0,
      localizations.translate('otherPaymentType'): 0.0,
    };

    for (var receipt in receipts) { // Používáme předaný seznam
      final paymentType = receipt['paymentType'];
      final total = (receipt['total'] as num?)?.toDouble() ?? 0.0;
      String key;
      switch (paymentType) {
        case 'CASH': key = localizations.translate('cashPaymentType'); break;
        case 'CARD': key = localizations.translate('cardPaymentType'); break;
        case 'BANK': key = localizations.translate('bankPaymentType'); break;
        default: key = localizations.translate('otherPaymentType'); break;
      }
      paymentData[key] = (paymentData[key] ?? 0.0) + total;
    }

    final totalRevenue = paymentData.values.fold(0.0, (sum, val) => sum + val);
    bool hasData = totalRevenue > 0.001; // Malá tolerance pro double

    if (!hasData) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(localizations.translate('noDataForPaymentChart'), style: TextStyle(color: Colors.grey[600])),
      ));
    }

    // ... (zbytek logiky pro paymentColors, chartSections, legendItems zůstává stejný, ale pracuje s lokální paymentData)
    final paymentColors = {
      localizations.translate('cashPaymentType'): Colors.yellow.shade700,
      localizations.translate('cardPaymentType'): Colors.blue.shade600,
      localizations.translate('bankPaymentType'): Colors.red.shade600,
      localizations.translate('otherPaymentType'): Colors.grey.shade500,
    };

    final chartSections = paymentData.entries
        .where((entry) => entry.value > 0.001)
        .map((entry) {
      final value = entry.value;
      final percentage = (totalRevenue > 0) ? (value / totalRevenue * 100).toDouble() : 0.0;
      return PieChartSectionData(
        color: paymentColors[entry.key],
        value: value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 80, // Můžeš upravit
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: <Shadow>[Shadow(color: Colors.black45, blurRadius: 2.0)]),
      );
    }).toList();

    final legendItems = paymentData.entries
        .where((entry) => entry.value > 0.001) // Zobrazujeme jen pokud je hodnota
        .map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 6.0),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: paymentColors[entry.key], shape: BoxShape.circle), margin: const EdgeInsets.only(right: 8.0)),
            Expanded(child: Text('${entry.key} (${Utility.formatCurrency(entry.value)})', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis,)),
          ],
        ),
      );
    }).toList();


    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
      ),
      height: 280,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
            child: Text(localizations.translate('salesByPaymentType'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: chartSections.isNotEmpty ? PieChart(
                    PieChartData(
                      sections: chartSections,
                      centerSpaceRadius: 0, // Pro plný koláč; pro doughnut nastav např. 40
                      sectionsSpace: 2, // Mezery mezi výsečemi
                      borderData: FlBorderData(show: false),
                      pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            // Zde můžeš implementovat interakci
                          }
                      ),
                    ),
                  ) : Center(child: Text(localizations.translate('noDataToDisplayInChart'), style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                ),
                Expanded(
                  flex: 1, // Prostor pro legendu
                  child: ListView(
                    shrinkWrap: true, // Aby zabral jen potřebné místo
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


/// 6) Widget: TodayRevenue
class TodayRevenueWidget extends StatelessWidget {
  final List<dynamic> receipts; // NOVÝ PARAMETR

  const TodayRevenueWidget({super.key, required this.receipts}); // UPRAVENÝ KONSTRUKTOR

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // final receiptProvider = context.watch<ReceiptProvider>(); // JIŽ NEPOTŘEBUJEME

    // Výpočet tržby POUZE pro dnešní den z předaných receipts.
    // Předpokládáme, že `DashboardScreen` předává účtenky, které jsou již jen pro dnešek.
    // Pokud by receipts mohly být i pro jiný rozsah, museli bychom zde filtrovat znovu.
    // Pro jednoduchost nyní předpokládáme, že `receipts` jsou již správně filtrované pro kontext dashboardu ("dnes").
    double todayRevenue = ReceiptProvider.calculateTotalRevenue(receipts); // Použijeme statickou metodu

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
            style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold),
          ),
          Text(
            Utility.formatCurrency(todayRevenue),
            style: const TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}