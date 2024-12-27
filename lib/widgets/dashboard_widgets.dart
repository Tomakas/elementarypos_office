//lib/widgets/dashboard_widgets.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../providers/receipt_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/utility_services.dart';

Widget buildSummaryBlock(BuildContext context, String value,
    {required bool isEditMode}) {
  final localizations = AppLocalizations.of(context)!;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(6.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.0),

    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          localizations.translate('receiptsToday'),
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}



Widget buildTopCategoriesTable(
    BuildContext context, List<Map<String, dynamic>> topCategories) {
  final localizations = AppLocalizations.of(context)!;

  return Padding(
    padding: const EdgeInsets.all(6.0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
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

Widget buildTopProductsTable(
    BuildContext context, List<Map<String, dynamic>> topProducts) {
  final localizations = AppLocalizations.of(context)!;

  return Padding(
    padding: const EdgeInsets.all(6.0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          localizations.translate('topSales'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(
            height:
                12.0), // Vytvoří mezeru mezi textem "topSales" a následujícím obsahem
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

Widget buildHourlyRevenueChart(
    BuildContext context, ReceiptProvider receiptProvider) {
  final localizations = AppLocalizations.of(context)!;
  List<double> hourlyRevenue = List.generate(24, (index) => 0.0);

  for (var receipt in receiptProvider.receipts) {
    if (receipt['dateTime'] != null && receipt['total'] != null) {
      try {
        DateTime date = DateTime.parse(receipt['dateTime']);
        double revenue = (receipt['total'] as num).toDouble();
        hourlyRevenue[date.hour] += revenue;
      } catch (e) {
        print('Error processing receipt: $e');
      }
    }
  }

  int minHour = hourlyRevenue.indexWhere((value) => value > 0);
  int maxHour = hourlyRevenue.lastIndexWhere((value) => value > 0);
  final maxValue = hourlyRevenue.reduce((a, b) => a > b ? a : b);

  minHour = minHour == -1 ? 8 : min(8, minHour);
  maxHour = maxHour == -1 ? 18 : max(18, maxHour);

  final barGroups = List.generate(maxHour - minHour + 1, (index) {
    int hour = minHour + index;
    return BarChartGroupData(
      x: hour,
      barRods: [
        BarChartRodData(
          toY: hourlyRevenue[hour],
          color: Colors.blueAccent,
          width: 16,
        ),
      ],
    );
  });

  return Container(
    height: 300,
    padding: const EdgeInsets.all(6.0),
    decoration: BoxDecoration(
      color: Colors.white,
    ),
    child: Column(
      children: [
        Center(
          child: Text(
            localizations.translate('hourlyGraph'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
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
                      // Skryje nejvyšší a nejnižší hodnotu
                      if (value == maxValue || value == 0) {
                        return const Text('');
                      }
                      return Text(
                        Utility.formatCurrency(value, decimals: 0),  // Např. bez desetinných míst
                        style: const TextStyle(fontSize: 12),
                      );
                    },
                    reservedSize: 50, // Ujistěte se, že rezervovaná velikost je dostatečná
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= minHour &&
                          value.toInt() <= maxHour) {
                        return Text(value.toInt().toString());
                      }
                      return const Text('');
                    },
                    reservedSize: 40,
                  ),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false), // Skrýt horní osu
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false), // Skrýt pravou osu
                ),
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




Widget buildTodayRevenueBlock(BuildContext context, double todayRevenue,
    {required bool isEditMode}) {
  final localizations = AppLocalizations.of(context)!;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(6.0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.0),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          localizations.translate('todayRevenue'),
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          Utility.formatCurrency(todayRevenue),
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget buildDynamicPieChart(BuildContext context,
    ReceiptProvider receiptProvider, AppLocalizations localizations) {
  final paymentData = {
    localizations.translate('cashPaymentType'): 0.0,
    localizations.translate('cardPaymentType'): 0.0,
    localizations.translate('bankPaymentType'): 0.0,
    localizations.translate('otherPaymentType'): 0.0,
  };

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

  final paymentColors = {
    localizations.translate('cashPaymentType'): Colors.yellow,
    localizations.translate('cardPaymentType'): Colors.blue,
    localizations.translate('bankPaymentType'): Colors.red,
    localizations.translate('otherPaymentType'): Colors.grey,
  };

  final totalRevenue =
      paymentData.values.fold(0.0, (sum, value) => sum + (value));
  final chartSections = paymentData.entries.map((entry) {
    final value = entry.value;
    final percentage =
        value > 0 ? (value / totalRevenue * 100).toDouble() : 0.0;

    return PieChartSectionData(
      color: paymentColors[entry.key],
      value: percentage,
      title: '${percentage.toStringAsFixed(1)}%',
      radius: 100,
      titleStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }).toList();

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
    padding: const EdgeInsets.all(1.0),
    height: 300,
    decoration: BoxDecoration(
      color: Colors.white,
    ),
    child: Column(
      children: [
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              localizations.translate('salesByPaymentType'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
                    centerSpaceRadius: 0, // Změna na 0 pro plný kruh
                    sectionsSpace: 4,
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ...legendItems,
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
