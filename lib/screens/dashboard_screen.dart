// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/dashboard_widget_model.dart';
import '../services/utility_services.dart';
import 'package:uuid/uuid.dart';
import '../widgets/dashboard_widgets.dart';
import '../providers/receipt_provider.dart';
import '../providers/product_provider.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isEditMode = false;
  List<DashboardWidgetModel> widgetsList = [];

  @override
  void initState() {
    super.initState();
    _loadWidgetsList().then((_) {
      if (mounted) {
        _loadDashboardDataStrategically();
      }
    });
  }

  Future<void> _loadWidgetsList() async {
    List<DashboardWidgetModel> loaded =
    await StorageService.getDashboardWidgetsOrder();
    if (loaded.isEmpty) {
      loaded = [
        DashboardWidgetModel(id: const Uuid().v4(), type: 'summary'),
        DashboardWidgetModel(id: const Uuid().v4(), type: 'top_products'),
        DashboardWidgetModel(id: const Uuid().v4(), type: 'top_categories'),
        DashboardWidgetModel(id: const Uuid().v4(), type: 'hourly_graph'),
        DashboardWidgetModel(id: const Uuid().v4(), type: 'payment_pie_chart'),
        DashboardWidgetModel(id: const Uuid().v4(), type: 'today_revenue'),
      ];
      await StorageService.saveDashboardWidgetsOrder(loaded);
    }
    if (mounted) {
      setState(() {
        widgetsList = loaded;
        print('Loaded widgets: ${widgetsList.length}');
      });
    }
  }

  Future<void> _loadDashboardDataStrategically() async {
    if (!mounted || widgetsList.isEmpty) {
      print("Dashboard: No widgets configured or screen not mounted, skipping strategic data load.");
      return;
    }
    print("Dashboard: Starting strategic data load based on active widgets.");

    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    bool needsReceipts = false;
    bool needsProductsAndCategories = false;

    for (var widgetModel in widgetsList) {
      switch (widgetModel.type) {
        case 'summary':
        case 'top_products':
        case 'hourly_graph':
        case 'payment_pie_chart':
        case 'today_revenue':
          needsReceipts = true;
          break;
        case 'top_categories':
          needsReceipts = true;
          needsProductsAndCategories = true;
          break;
      }
    }

    List<Future> futures = [];

    if (needsReceipts) {
      print("Dashboard: Receipts data needed. Initiating fetch...");
      final now = DateTime.now();
      final todayRange = DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
      futures.add(receiptProvider.fetchReceipts(dateRange: todayRange));
    }

    if (needsProductsAndCategories) {
      print("Dashboard: Product and category data needed. Initiating fetch...");
      // Například, pokud productProvider nemá načtené produkty nebo kategorie.
      // Pro jednoduchost můžeme vždy volat fetchAllProductData, pokud je potřeba.
      // V reálné aplikaci by zde mohla být sofistikovanější logika pro rozhodnutí, zda je fetch nutný.
      if (productProvider.products.isEmpty || productProvider.categories.isEmpty) {
        futures.add(productProvider.fetchAllProductData());
      }
    }

    if (futures.isNotEmpty) {
      try {
        await Future.wait(futures);
        print("Dashboard: Strategic data loading operations completed.");
      } catch (e) {
        print("Dashboard: Error during strategic data loading: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.translate('errorLoadingDashboardData'))),
          );
        }
      }
    } else {
      print("Dashboard: No specific data fetch needed by active widgets.");
    }
  }

  Future<void> _saveWidgetsOrder() async {
    await StorageService.saveDashboardWidgetsOrder(widgetsList);
  }

  void _enterEditMode() {
    if (mounted) {
      setState(() {
        isEditMode = true;
      });
    }
  }

  void _exitEditMode() {
    if (mounted) {
      setState(() {
        isEditMode = false;
      });
    }
  }

  void _showAddWidgetDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) {
        String? selectedType;
        return AlertDialog(
          title: Text(localizations.translate('addWidget')),
          content: DropdownButtonFormField<String>(
            items: const [
              DropdownMenuItem(value: 'summary', child: Text('Summary')),
              DropdownMenuItem(
                  value: 'top_products', child: Text('Top Products')),
              DropdownMenuItem(
                  value: 'top_categories', child: Text('Top Categories')),
              DropdownMenuItem(
                  value: 'hourly_graph', child: Text('Hourly Graph')),
              DropdownMenuItem(
                  value: 'payment_pie_chart', child: Text('Payment Pie Chart')),
              DropdownMenuItem(
                  value: 'today_revenue', child: Text('Today Revenue')),
            ],
            onChanged: (val) => selectedType = val,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: localizations.translate('selectWidgetType'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedType != null) {
                  final newWidget = DashboardWidgetModel(
                    id: const Uuid().v4(),
                    type: selectedType!,
                  );
                  if (mounted) {
                    setState(() {
                      widgetsList.add(newWidget);
                    });
                  }
                  _saveWidgetsOrder();
                  _loadDashboardDataStrategically(); // Znovu načteme data, pokud nový widget něco vyžaduje
                  Navigator.pop(context);
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
      backgroundColor: Colors.grey[400],
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.grey[850],
        title: Text(localizations.translate('dashboardTitle'),
            style: const TextStyle(color: Colors.white)),
        actions: <Widget>[
          if (!isEditMode)
            IconButton(
              icon: const Icon(
                Icons.edit,
              ),
              tooltip: localizations.translate('edit'),
              onPressed: _enterEditMode,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: localizations.translate('finishEditing'),
              onPressed: _exitEditMode,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: localizations.translate('addWidget'),
              onPressed: () => _showAddWidgetDialog(context),
            ),
          ]
        ],
      ),
      body: Container(
        color: Colors.grey[400],
        child: ReorderableListView(
          buildDefaultDragHandles: false,
          onReorder: isEditMode ? _handleReorder : _noReorderAllowed,
          proxyDecorator:
              (Widget child, int index, Animation<double> animation) {
            // Zajistíme, že widgetsList není prázdný a index je platný
            if (widgetsList.isEmpty || index < 0 || index >= widgetsList.length) {
              return Material(child: SizedBox.shrink()); // Vrátíme prázdný widget, pokud je problém
            }
            final model = widgetsList[index];
            return Material(
              elevation: 6.0,
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              child: _buildItem(model, isDragging: true),
            );
          },
          padding: const EdgeInsets.all(16.0),
          children: [
            for (int index = 0; index < widgetsList.length; index++)
              _buildItem(widgetsList[index]),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(DashboardWidgetModel model, {bool isDragging = false}) {
    if (!mounted) return SizedBox.shrink(key: ValueKey("unmounted_placeholder_${model.id}"));

    final localizations = AppLocalizations.of(context);
    if (localizations == null) return SizedBox.shrink(key: ValueKey("no_localizations_placeholder_${model.id}"));

    return Column(
      key: ValueKey(model.id),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isEditMode ? Colors.black : Colors.grey,
              width: isEditMode ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildWidgetByType(model.type),
              ),
              if (isEditMode)
                Positioned(
                  top: 8,
                  left: 8,
                  child: ReorderableDragStartListener(
                    index: widgetsList.indexWhere((w) => w.id == model.id), // Bezpečnější nalezení indexu
                    child: const Icon(
                      Icons.drag_indicator,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              if (isEditMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_outlined,
                      size: 40,
                      color: Colors.red,
                    ),
                    tooltip: localizations.translate('delete'),
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          widgetsList.removeWhere((w) => w.id == model.id);
                        });
                      }
                      _saveWidgetsOrder();
                      _loadDashboardDataStrategically();
                    },
                  ),
                ),
            ],
          ),
        ),
        if (!isDragging) const SizedBox(height: 12.0),
      ],
    );
  }

  void _handleReorder(int oldIndex, int newIndex) {
    if (mounted) {
      setState(() {
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }
        final item = widgetsList.removeAt(oldIndex);
        widgetsList.insert(newIndex, item);
      });
    }
    _saveWidgetsOrder();
  }

  void _noReorderAllowed(int oldIndex, int newIndex) {
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildWidgetByType(String type) {
    switch (type) {
      case 'summary':
        return const SummaryWidget();
      case 'top_products':
        return const TopProductsWidget();
      case 'top_categories':
        return const TopCategoriesWidget();
      case 'hourly_graph':
        return const HourlyGraphWidget();
      case 'payment_pie_chart':
        return const PaymentPieChartWidget();
      case 'today_revenue':
        return const TodayRevenueWidget();
      default:
      // Použijeme AppLocalizations.of(context) pro případ, že by buildWidgetByType bylo voláno mimo build metodu _DashboardScreenState
      // Nicméně, v tomto kontextu je to voláno z _buildItem, kde localizations již máme.
      // Pro jistotu, pokud by se kontext měnil:
        final currentContext = context;
        final localizations = AppLocalizations.of(currentContext);
        return Text(localizations?.translate('unknownWidgetType') ?? 'Unknown Widget Type');
    }
  }
}