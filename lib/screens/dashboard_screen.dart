// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/dashboard_widget_model.dart';
import '../services/utility_services.dart';
import 'package:uuid/uuid.dart';
import '../widgets/dashboard_widgets.dart';

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
    _loadWidgetsList();
  }

  Future<void> _loadWidgetsList() async {
    // Načtení pořadí widgetů z persistentního úložiště
    List<DashboardWidgetModel> loaded =
    await StorageService.getDashboardWidgetsOrder();

    // Pokud není žádné uložené pořadí, nastavíme výchozí pořadí
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
    setState(() {
      widgetsList = loaded;
      print('Loaded widgets: $widgetsList');
    });
  }

  Future<void> _saveWidgetsOrder() async {
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
              DropdownMenuItem(value: 'top_products', child: Text('Top Products')),
              DropdownMenuItem(value: 'top_categories', child: Text('Top Categories')),
              DropdownMenuItem(value: 'hourly_graph', child: Text('Hourly Graph')),
              DropdownMenuItem(value: 'payment_pie_chart', child: Text('Payment Pie Chart')),
              DropdownMenuItem(value: 'today_revenue', child: Text('Today Revenue')),
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
                  setState(() {
                    widgetsList.add(newWidget);
                  });
                  _saveWidgetsOrder();
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
      backgroundColor: Colors.grey[400], // Barva pozadí Scaffoldu
      appBar: AppBar(
        title: Text(localizations.translate('dashboardTitle'),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        actions: <Widget>[
          if (!isEditMode)
            IconButton(
              icon: const Icon(
                Icons.edit,
                color: Colors.white,
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
        color: Colors.grey[400], // Barva pozadí ReorderableListView
        child: ReorderableListView(
          // Vypnout výchozí drag handles, abychom mohli přidat vlastní
          buildDefaultDragHandles: false,

          // Pokud je editovací mód aktivní, použijeme skutečnou metodu pro přeuspořádání
          // Jinak použijeme metodu, která nepřesune položky
          onReorder: isEditMode ? _handleReorder : _noReorderAllowed,

          // Přidáme proxyDecorator pro přizpůsobení vzhledu přetahovaného widgetu
          proxyDecorator: (Widget child, int index, Animation<double> animation) {
            return Material(
              elevation: 6.0,
              color: Colors.white, // Stejná barva jako ostatní widgety
              borderRadius: BorderRadius.circular(12.0),
              child: child,
            );
          },

          padding: const EdgeInsets.all(16.0),
          children: [
            for (final model in widgetsList)
            // Obalení každého Containeru do Padding pro vytvoření mezery
              Padding(
                key: ValueKey(model.id), // Klíč přiřazen přímo k Padding
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
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
                      // V editačním módu zobrazíme drag handle
                      if (isEditMode)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: ReorderableDragStartListener(
                            index: widgetsList.indexOf(model),
                            child: const Icon(
                              Icons.drag_handle,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      // Zobrazení tlačítka pro odstranění widgetu v editačním módu
                      if (isEditMode)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close_outlined,
                              color: Colors.red,
                            ),
                            tooltip: localizations.translate('delete'),
                            onPressed: () {
                              setState(() {
                                widgetsList.removeWhere((w) => w.id == model.id);
                              });
                              _saveWidgetsOrder();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Metoda pro přeuspořádání widgetů
  void _handleReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = widgetsList.removeAt(oldIndex);
      widgetsList.insert(newIndex, item);
    });
    _saveWidgetsOrder();
  }

  /// Metoda, která neprovádí žádnou změnu pořadí (v ne-edit módu)
  void _noReorderAllowed(int oldIndex, int newIndex) {
    // Nic neděláme, takže se pořadí nezmění
    setState(() {});
  }

  /// Metoda pro vytvoření widgetu na základě jeho typu
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
        return const Text('Unknown Widget Type');
    }
  }
}
