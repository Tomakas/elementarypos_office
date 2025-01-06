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
    // Místo, kde si stáhnete seznam widgetů (z SharedPreferences, serveru atd.)
    // Pro ukázku zkusíme načíst z StorageService:
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
    setState(() {
      widgetsList = loaded;
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
      appBar: AppBar(
        title: Text(localizations.translate('dashboardTitle'),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        actions: [
          if (!isEditMode)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white,),
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
      body: ReorderableListView(
        padding: const EdgeInsets.all(16.0),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final item = widgetsList.removeAt(oldIndex);
            widgetsList.insert(newIndex, item);
          });
          _saveWidgetsOrder();
        },
        children: [
          for (final model in widgetsList)
            Container(
              key: ValueKey(model.id),
              margin: const EdgeInsets.only(bottom: 12.0),
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
                  _buildWidgetByType(model.type),
                  if (isEditMode)
                    Positioned(
                      top: -10,
                      right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close_outlined, color: Colors.red, size: 40, ),
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
        ],
      ),
    );
  }

  /// Namísto `_buildWidgetContent` voláme samostatné widgety definované v `dashboard_widgets.dart`.
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
