import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/receipt_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/dashboard_widgets.dart' as widgets;
import '../models/dashboard_widget_model.dart' as model;
import '../services/utility_services.dart';
import 'package:uuid/uuid.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<void> _fetchData;
  bool isEditMode = false;
  List<model.DashboardWidgetModel> widgetsList = [];

  @override
  void initState() {
    super.initState();
    _fetchData = _loadData();
  }

  Future<void> _loadData() async {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    final today = DateTime.now();
    // Nastavíme dateRange na aktuální den
    receiptProvider.updateDateRange(
      DateTimeRange(
        start: DateTime(today.year, today.month, today.day),
        end: DateTime(today.year, today.month, today.day, 23, 59, 59),
      ),
    );

    await productProvider.fetchProducts();  // Nejdříve produkty
    await receiptProvider.fetchReceipts();  // Pak účtenky

    List<model.DashboardWidgetModel> loadedWidgets = await StorageService.getDashboardWidgetsOrder();
    if (loadedWidgets.isEmpty) {
      loadedWidgets = [
        model.DashboardWidgetModel(id: const Uuid().v4(), type: 'summary'),
        model.DashboardWidgetModel(id: const Uuid().v4(), type: 'top_products'),
        model.DashboardWidgetModel(id: const Uuid().v4(), type: 'top_categories'),
        model.DashboardWidgetModel(id: const Uuid().v4(), type: 'hourly_graph'),
        model.DashboardWidgetModel(id: const Uuid().v4(), type: 'payment_pie_chart'),
        model.DashboardWidgetModel(id: const Uuid().v4(), type: 'today_revenue'),
      ];
      await StorageService.saveDashboardWidgetsOrder(loadedWidgets);
    }
    setState(() {
      widgetsList = loadedWidgets;
    });
  }

  Future<void> _saveWidgets() async {
    await StorageService.saveDashboardWidgetsOrder(widgetsList);
  }

  void _enterEditMode() {
    setState(() {
      isEditMode = true;
    });
  }

  void _exitEditMode() {
    setState(() {
      isEditMode = false;
    });
  }

  void _addNewWidget(String type) {
    setState(() {
      widgetsList.add(model.DashboardWidgetModel(id: const Uuid().v4(), type: type));
    });
    _saveWidgets();
  }

  void _removeWidget(String id) {
    setState(() {
      widgetsList.removeWhere((widget) => widget.id == id);
    });
    _saveWidgets();
  }

  void _showAddWidgetDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        String? selectedType;
        return AlertDialog(
          title: Text(localizations.translate('addWidget')),
          content: DropdownButtonFormField<String>(
            value: selectedType,
            items: [
              DropdownMenuItem(
                value: 'summary',
                child: Text(localizations.translate('summary')),
              ),
              DropdownMenuItem(
                value: 'top_products',
                child: Text(localizations.translate('topProducts')),
              ),
              DropdownMenuItem(
                value: 'top_categories',
                child: Text(localizations.translate('topCategories')),
              ),
              DropdownMenuItem(
                value: 'hourly_graph',
                child: Text(localizations.translate('hourlyGraph')),
              ),
              DropdownMenuItem(
                value: 'payment_pie_chart',
                child: Text(localizations.translate('paymentPieChart')),
              ),
              DropdownMenuItem(
                value: 'today_revenue',
                child: Text(localizations.translate('todayRevenue')),
              ),
            ],
            onChanged: (value) {
              selectedType = value;
            },
            decoration: InputDecoration(
              labelText: localizations.translate('selectWidgetType'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(localizations.translate('cancel')),
            ),
            TextButton(
              onPressed: () {
                if (selectedType != null) {
                  _addNewWidget(selectedType!);
                  Navigator.of(context).pop();
                }
              },
              child: Text(localizations.translate('add')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('dashboardTitle'),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[850],
        actions: [
          if (!isEditMode)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: localizations.translate('editDashboard'),
              onPressed: _enterEditMode,
            ),
          if (isEditMode) ...[
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              tooltip: localizations.translate('finishEditing'),
              onPressed: _exitEditMode,
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: localizations.translate('addWidget'),
              onPressed: _showAddWidgetDialog,
            ),
          ],
        ],
      ),
      body: FutureBuilder<void>(
        future: _fetchData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                '${localizations.translate('errorLoadingData')}: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else {
            return _buildDashboardContent(context, localizations);
          }
        },
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, AppLocalizations localizations) {
    return ReorderableListView(
      padding: const EdgeInsets.all(16.0),
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 4.0,
          color: Colors.transparent,
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = widgetsList.removeAt(oldIndex);
          widgetsList.insert(newIndex, item);
        });
        _saveWidgets();
      },
      children: [
        for (final widgetModel in widgetsList)
          GestureDetector(
            key: ValueKey(widgetModel.id),
            onLongPress: isEditMode
                ? null
                : () {
              // Do something on long press in normal mode (optional)
            },
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isEditMode ? Colors.black : Colors.grey,
                      width: isEditMode ? 2 : 1,
                    ),
                    boxShadow: isEditMode
                        ? [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(4, 8),
                        spreadRadius: 10,
                      ),
                    ]
                        : [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildWidgetContent(widgetModel.type),
                  ),
                ),
                if (isEditMode)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                        border: Border.all(color: Colors.white70, width: 2),
                      ),
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      child: FittedBox(
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red, size: 34),
                          onPressed: () => _removeWidget(widgetModel.id),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWidgetContent(String type) {
    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context)!;

    switch (type) {
      case 'summary':
      // Zobrazení počtu účtenek
        return widgets.buildSummaryBlock(
          context,
          '${receiptProvider.receipts.length}',
          isEditMode: isEditMode,
        );

      case 'top_products':
      // Zavolání nově definované metody v ReceiptProvider
        final topProducts = receiptProvider.getTopProducts(limit: 5);
        return widgets.buildTopProductsTable(context, topProducts);

      case 'top_categories':
      // Zavolání nově definované metody v ReceiptProvider
        final topCategories = receiptProvider.getTopCategories(
          limit: 5,
          productProvider: productProvider,
        );
        return widgets.buildTopCategoriesTable(context, topCategories);

      case 'hourly_graph':
        return widgets.buildHourlyRevenueChart(context, receiptProvider);

      case 'payment_pie_chart':
        return widgets.buildDynamicPieChart(context, receiptProvider, localizations);

      case 'today_revenue':
        final double todayRevenue = receiptProvider.receipts.fold(
          0.0,
              (sum, receipt) => sum + (receipt['total'] as num).toDouble(),
        );
        return widgets.buildTodayRevenueBlock(context, todayRevenue, isEditMode: isEditMode);

      default:
        return Text(localizations.translate('unknownWidgetType'));
    }
  }
}
