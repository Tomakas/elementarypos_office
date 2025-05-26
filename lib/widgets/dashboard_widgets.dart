// lib/widgets/dashboard_widgets.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/receipt_provider.dart';
import '../providers/product_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/utility_services.dart';

/// 1) Widget: Počet účtenek (Summary)
class SummaryWidget extends StatelessWidget {
  const SummaryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final receiptProvider = context.watch<ReceiptProvider>();

    if (receiptProvider.isLoading && receiptProvider.receipts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3,))),
      );
    }

    final receiptsCount = receiptProvider.receipts.length;

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
class TopProductsWidget extends StatelessWidget {
  const TopProductsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final receiptProvider = context.watch<ReceiptProvider>();

    if (receiptProvider.isLoading && receiptProvider.receipts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Map<String, dynamic>> topProducts = receiptProvider.getTopProducts(limit: 5);

    if (topProducts.isEmpty && !receiptProvider.isLoading) {
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
          if (topProducts.isEmpty && receiptProvider.isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3,)),
            ),
          for (var product in topProducts)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(product['name'] ?? ''),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      (product['quantity'] as num?)?.toStringAsFixed(0) ?? "0",
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      Utility.formatCurrency((product['revenue'] as num?)?.toDouble() ?? 0.0),
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
class TopCategoriesWidget extends StatelessWidget {
  const TopCategoriesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final receiptProvider = context.watch<ReceiptProvider>();
    final productProvider = context.watch<ProductProvider>();

    if ((receiptProvider.isLoading && receiptProvider.receipts.isEmpty) ||
        (productProvider.isLoading && productProvider.products.isEmpty && productProvider.categories.isEmpty)) { // Upravená podmínka
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Zkontrolujeme, zda productProvider má načtené produkty, než zavoláme getTopCategories
    if (productProvider.products.isEmpty && !productProvider.isLoading) {
      return Center(child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(localizations.translate('productsNotLoadedYet'), style: TextStyle(color: Colors.grey[600])) // Přidat do lokalizace
      ));
    }


    final List<Map<String, dynamic>> topCategories = receiptProvider.getTopCategories(
      limit: 5,
      productProvider: productProvider,
    );

    if (topCategories.isEmpty && !receiptProvider.isLoading && !productProvider.isLoading) {
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
          Text(
            localizations.translate('topCategories'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12.0),
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
          if (topCategories.isEmpty && (receiptProvider.isLoading || productProvider.isLoading))
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3,)),
            ),
          for (var category in topCategories)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(category['name'] ?? ''),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      (category['quantity'] as num?)?.toStringAsFixed(0) ?? "0",
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      Utility.formatCurrency((category['revenue'] as num?)?.toDouble() ?? 0.0),
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
class HourlyGraphWidget extends StatelessWidget {
  const HourlyGraphWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final receiptProvider = context.watch<ReceiptProvider>();

    if (receiptProvider.isLoading && receiptProvider.receipts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    List<double> hourlyRevenue = List.filled(24, 0.0);
    for (var receipt in receiptProvider.receipts) {
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
    if (!hasData && !receiptProvider.isLoading) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(localizations.translate('noDataForHourlyGraph'), style: TextStyle(color: Colors.grey[600])),
      ));
    }

    int minHour = hourlyRevenue.indexWhere((value) => value > 0);
    int maxHour = hourlyRevenue.lastIndexWhere((value) => value > 0);
    final maxValue = (hourlyRevenue.isNotEmpty)
        ? hourlyRevenue.reduce((a, b) => a > b ? a : b)
        : 0.0;
    if (minHour == -1) minHour = 8;
    if (maxHour == -1) maxHour = 18;
    if (minHour > maxHour) {
      minHour = 8;
      maxHour = 18;
    }

    final barGroups = <BarChartGroupData>[];
    if(hasData){ // Vytváříme skupiny jen pokud máme data
      for (int hour = minHour; hour <= maxHour; hour++) {
        barGroups.add(
          BarChartGroupData(
            x: hour,
            barRods: [
              BarChartRodData(
                toY: hourlyRevenue[hour],
                color: Colors.blueAccent,
                width: 16,
                borderRadius: BorderRadius.zero, // Ostré hrany pro klasický vzhled
              ),
            ],
          ),
        );
      }
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
            padding: const EdgeInsets.only(top: 8.0, bottom: 16.0), // Větší padding
            child: Text(
              localizations.translate('hourlyGraph'),
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!hasData && receiptProvider.isLoading)
            const Expanded(child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3,)))),
          if (hasData)
            Expanded(
              child: BarChart(
                BarChartData(
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('');
                          if (maxValue > 0 && (value == maxValue || value % (maxValue / 4).ceilToDouble() == 0)) {
                            return Text(Utility.formatCurrency(value, decimals: 0, currencySymbol: ''), style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                        reservedSize: 35, // Upraveno
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          if (hour >= minHour && hour <= maxHour && hour % 2 == 0) {
                            return Padding(padding: const EdgeInsets.only(top:4.0), child: Text(hour.toString(), style: const TextStyle(fontSize: 10)));
                          }
                          return const Text('');
                        },
                        reservedSize: 22, // Upraveno
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(color: Colors.grey.shade300, strokeWidth: 0.8);
                    },
                  ),
                  borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade400, width: 1.5),
                        left: BorderSide(color: Colors.grey.shade400, width: 1.5),
                      )
                  ),
                  barTouchData: BarTouchData( // Přidáno pro tooltips
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String hour;
                        hour = '${group.x.toInt()}:00 - ${(group.x.toInt() + 1)}:00';
                        return BarTooltipItem(
                          '$hour\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          children: <TextSpan>[
                            TextSpan(
                              text: Utility.formatCurrency(rod.toY, decimals:0),
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
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

/// 5) Widget: Payment Pie Chart (koláčový graf tržeb podle typu platby)
class PaymentPieChartWidget extends StatelessWidget {
  const PaymentPieChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final receiptProvider = context.watch<ReceiptProvider>();

    if (receiptProvider.isLoading && receiptProvider.receipts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final Map<String, double> paymentData = {
      localizations.translate('cashPaymentType'): 0.0,
      localizations.translate('cardPaymentType'): 0.0,
      localizations.translate('bankPaymentType'): 0.0,
      localizations.translate('otherPaymentType'): 0.0,
    };

    for (var receipt in receiptProvider.receipts) {
      final paymentType = receipt['paymentType'];
      final total = (receipt['total'] as num?)?.toDouble() ?? 0.0;

      String key;
      switch (paymentType) {
        case 'CASH':
          key = localizations.translate('cashPaymentType');
          break;
        case 'CARD':
          key = localizations.translate('cardPaymentType');
          break;
        case 'BANK':
          key = localizations.translate('bankPaymentType');
          break;
        default:
          key = localizations.translate('otherPaymentType');
      }
      paymentData[key] = (paymentData[key] ?? 0.0) + total;
    }

    final totalRevenue = paymentData.values.fold(0.0, (sum, val) => sum + val);
    bool hasData = totalRevenue > 0;

    if (!hasData && !receiptProvider.isLoading) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(localizations.translate('noDataForPaymentChart'), style: TextStyle(color: Colors.grey[600])),
      ));
    }

    final paymentColors = {
      localizations.translate('cashPaymentType'): Colors.yellow.shade700,
      localizations.translate('cardPaymentType'): Colors.blue.shade600,
      localizations.translate('bankPaymentType'): Colors.red.shade600,
      localizations.translate('otherPaymentType'): Colors.grey.shade500,
    };

    final chartSections = paymentData.entries
        .where((entry) => entry.value > 0.001) // Zobrazit jen pokud je hodnota > 0 (malá tolerance pro double)
        .map((entry) {
      final value = entry.value;
      final percentage = (totalRevenue > 0) ? (value / totalRevenue * 100).toDouble() : 0.0;
      return PieChartSectionData(
        color: paymentColors[entry.key],
        value: value, // Hodnota pro výpočet úhlu výseče
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 80,
        titleStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white,
            shadows: <Shadow>[Shadow(color: Colors.black45, blurRadius: 2.0)]),
      );
    }).toList();

    final legendItems = paymentData.entries
        .where((entry) => entry.value > 0.001)
        .map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 6.0),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: paymentColors[entry.key],
                  shape: BoxShape.circle
              ),
              margin: const EdgeInsets.only(right: 8.0),
            ),
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
      height: 280, // Mírně snížená výška
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
            child: Text(
              localizations.translate('salesByPaymentType'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!hasData && receiptProvider.isLoading)
            const Expanded(child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3,)))),
          if (hasData)
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2, // Větší prostor pro graf
                    child: chartSections.isNotEmpty ? PieChart( // Zobrazit graf jen pokud jsou data
                      PieChartData(
                        sections: chartSections,
                        centerSpaceRadius: 0, // Plný koláč
                        sectionsSpace: 2,
                        borderData: FlBorderData(show: false),
                        pieTouchData: PieTouchData( // Přidáno pro interakci
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              // Zde můžete implementovat logiku pro interakci, např. zvýraznění výseče
                            }
                        ),
                      ),
                    ) : Center(child: Text(localizations.translate('noDataToDisplayInChart'), style: TextStyle(fontSize: 12, color: Colors.grey[600]))), // Přidat do lokalizace
                  ),
                  Expanded(
                    flex: 1, // Menší prostor pro legendu
                    child: ListView(
                      shrinkWrap: true,
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
class TodayRevenueWidget extends StatelessWidget {
  const TodayRevenueWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final receiptProvider = context.watch<ReceiptProvider>();

    if (receiptProvider.isLoading && receiptProvider.receipts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3,))),
      );
    }

    double todayRevenue = 0.0;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    // Výpočet tržby pouze pro dnešní den, i když provider může obsahovat více
    for (var r in receiptProvider.receipts) {
      try {
        DateTime receiptDate = DateTime.parse(r['dateTime']);
        // Normalizace dat na půlnoc pro spolehlivé porovnání
        DateTime receiptDateOnly = DateTime(receiptDate.year, receiptDate.month, receiptDate.day);

        if (!receiptDateOnly.isBefore(todayStart) && !receiptDateOnly.isAfter(todayEnd)) {
          todayRevenue += (r['total'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {
        // Ignorovat chyby parsování data při výpočtu pro tento widget
      }
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