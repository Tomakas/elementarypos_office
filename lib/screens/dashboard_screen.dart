// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../models/dashboard_widget_model.dart';
import '../services/utility_services.dart';
import '../widgets/dashboard_widgets.dart'; // Bude také upraven
import '../providers/receipt_provider.dart';
import '../providers/product_provider.dart';

class DashboardScreen extends StatefulWidget {
  final bool isSelected;

  const DashboardScreen({
    super.key,
    this.isSelected = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool isEditMode = false;
  List<DashboardWidgetModel> widgetsList = [];
  bool _initialDataLoaded = false;

  // Lokální stav pro data dashboardu
  List<dynamic> _dashboardReceipts = [];
  // Lokální příznak načítání specificky pro data dashboardu
  bool _isLoadingDashboardData = false;

  // Pro předání instancí providerů do statických metod (pokud je třeba)
  // nebo pro přístup k jiným částem providerů (např. ProductProvider pro TopCategories)
  late ProductProvider _productProviderInstance;


  @override
  void initState() {
    super.initState();
    _productProviderInstance = Provider.of<ProductProvider>(context, listen: false);
    print("DashboardScreen: initState, isSelected: ${widget.isSelected}");
    _loadWidgetsList().then((_) {
      if (mounted && widget.isSelected && widgetsList.isNotEmpty) {
        print("DashboardScreen: initState - obrazovka je aktivní a widgety načteny, načítám data.");
        _loadDashboardDataStrategically();
        _initialDataLoaded = true;
      } else if (mounted && widget.isSelected && widgetsList.isEmpty) {
        print("DashboardScreen: initState - obrazovka je aktivní, ale nejsou žádné widgety.");
        _initialDataLoaded = true;
      }
    });
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("DashboardScreen: didUpdateWidget, isSelected: ${widget.isSelected}, oldWidget.isSelected: ${oldWidget.isSelected}, _initialDataLoaded: $_initialDataLoaded");
    if (widget.isSelected && (!oldWidget.isSelected || !_initialDataLoaded)) {
      if (widgetsList.isNotEmpty) {
        print("DashboardScreen: didUpdateWidget - obrazovka se stala aktivní, načítám data.");
        _loadDashboardDataStrategically();
        _initialDataLoaded = true;
      } else {
        _loadWidgetsList().then((_) {
          if (mounted && widget.isSelected && widgetsList.isNotEmpty) {
            print("DashboardScreen: didUpdateWidget - widgety načteny, obrazovka aktivní, načítám data.");
            _loadDashboardDataStrategically();
            _initialDataLoaded = true;
          } else if (mounted && widget.isSelected && widgetsList.isEmpty) {
            print("DashboardScreen: didUpdateWidget - widgety načteny, ale nejsou žádné widgety.");
            _initialDataLoaded = true; // Data pro widgety se nenačítají, protože nejsou widgety
            // Pokud by se měly načíst defaultní widgety a pak data, upravit zde
            if (mounted) { // Vynutíme překreslení, aby se zobrazil případný text "no widgets"
              setState(() {});
            }
          }
        });
      }
    } else if (!widget.isSelected) {
      _initialDataLoaded = false;
      print("DashboardScreen: didUpdateWidget - obrazovka již není aktivní.");
    }
  }

  Future<void> _loadWidgetsList() async {
    if (!mounted) return;
    List<DashboardWidgetModel> loaded = await StorageService.getDashboardWidgetsOrder();
    if (loaded.isEmpty && mounted) {
      loaded = [
        DashboardWidgetModel(id: const Uuid().v4(), type: 'summary'),
        DashboardWidgetModel(id: const Uuid().v4(), type: 'today_revenue'),
        DashboardWidgetModel(id: const Uuid().v4(), type: 'top_products'),
        DashboardWidgetModel(id: const Uuid().v4(), type: 'top_categories'),
        DashboardWidgetModel(id: const Uuid().v4(), type: 'hourly_graph'),
        DashboardWidgetModel(id: const Uuid().v4(), type: 'payment_pie_chart'),
      ];
      await StorageService.saveDashboardWidgetsOrder(loaded);
    }
    if (mounted) {
      setState(() {
        widgetsList = loaded;
      });
      print('DashboardScreen: Seznam widgetů načten/aktualizován (${widgetsList.length} widgetů).');
    }
  }

  Future<void> _loadDashboardDataStrategically() async {
    if (!mounted) return;
    if (widgetsList.isEmpty) {
      print("DashboardScreen: Žádné widgety k zobrazení, přeskakuji načítání dat.");
      // Pokud by se měly defaultní widgety načíst zde, pokud nejsou:
      // await _loadWidgetsList();
      // if (widgetsList.isEmpty && mounted) return;
      // Pro jistotu aktualizujeme stav, kdyby se mělo zobrazit "no widgets"
      setState(() {
        _dashboardReceipts = []; // Vyčistíme stará data, pokud by tam byla
        _isLoadingDashboardData = false;
      });
      return;
    }

    print("DashboardScreen: Zahajuji strategické načítání dat pro dashboard.");
    if(mounted) {
      setState(() {
        _isLoadingDashboardData = true;
      });
    }

    final receiptProvider = Provider.of<ReceiptProvider>(context, listen: false);
    // _productProviderInstance je již inicializován v initState

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

    List<dynamic> newDashboardReceipts = [];
    List<Future> futures = [];

    if (needsReceipts) {
      print("DashboardScreen: Potřebná data o účtenkách. Zahajuji fetch.");
      final now = DateTime.now();
      final todayRange = DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
      );
      // Zavoláme metodu, která vrací data
      futures.add(
          receiptProvider.fetchReceipts(
            dateRange: todayRange,
            showCash: true,
            showCard: true,
            showBank: true,
            showOther: true,
            showWithDiscount: false,
          ).then((receipts) {
            newDashboardReceipts = receipts; // Uložíme do dočasné proměnné
          })
      );
    }

    if (needsProductsAndCategories) {
      print("DashboardScreen: Potřebná data o produktech/kategoriích.");
      if (_productProviderInstance.products.isEmpty || _productProviderInstance.categories.isEmpty) {
        futures.add(_productProviderInstance.fetchAllProductData());
      }
    }

    try {
      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
      print("DashboardScreen: Strategické načítání dat dokončeno.");
      if (mounted) {
        setState(() {
          _dashboardReceipts = newDashboardReceipts; // Aktualizujeme lokální stav účtenek
        });
      }
    } catch (e) {
      print("DashboardScreen: Chyba během strategického načítání dat: $e");
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        if (localizations != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('errorLoadingData'))),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDashboardData = false;
        });
      }
    }
  }

  Future<void> _saveWidgetsOrder() async {
    await StorageService.saveDashboardWidgetsOrder(widgetsList);
    print("DashboardScreen: Pořadí widgetů uloženo.");
  }

  void _enterEditMode() {
    if (mounted) setState(() => isEditMode = true);
  }

  void _exitEditMode() {
    if (mounted) setState(() => isEditMode = false);
  }

  void _showAddWidgetDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) {
        String? selectedType;
        final Map<String, String> availableWidgetTypes = {
          'summary': localizations.translate('summary'),
          'today_revenue': localizations.translate('todayRevenue'),
          'top_products': localizations.translate('topProducts'),
          'top_categories': localizations.translate('topCategories'),
          'hourly_graph': localizations.translate('hourlyGraph'),
          'payment_pie_chart': localizations.translate('paymentPieChart'),
        };
        return AlertDialog(
          title: Text(localizations.translate('addWidget')),
          content: DropdownButtonFormField<String>(
            items: availableWidgetTypes.entries.map((entry) {
              return DropdownMenuItem(value: entry.key, child: Text(entry.value));
            }).toList(),
            onChanged: (val) => selectedType = val,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: localizations.translate('selectWidgetType'),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(localizations.translate('cancel'))),
            ElevatedButton(
              onPressed: () {
                if (selectedType != null) {
                  final newWidget = DashboardWidgetModel(id: const Uuid().v4(), type: selectedType!);
                  if (mounted) setState(() => widgetsList.add(newWidget));
                  _saveWidgetsOrder();
                  _loadDashboardDataStrategically();
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

  Widget _buildItem(DashboardWidgetModel model, {bool isDragging = false}) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return SizedBox.shrink(key: ValueKey("no_localizations_${model.id}"));

    return Column(
      key: ValueKey(model.id),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // ... (dekorace a Stack logika pro ReorderableDragStartListener a IconButton zůstává)
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isEditMode ? Colors.blueAccent : Colors.grey.shade300,
              width: isEditMode ? 2 : 1,
            ),
            boxShadow: isEditMode && !isDragging ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ] : [],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                // Zde předáváme potřebná data do _buildWidgetByType
                child: _buildWidgetByType(
                  model.type,
                  _dashboardReceipts, // Předáváme lokální data
                  _productProviderInstance, // Předáváme instanci ProductProvider
                  localizations,
                ),
              ),
              if (isEditMode)
                Positioned(
                  top: 4, left: 4,
                  child: ReorderableDragStartListener(
                    index: widgetsList.indexWhere((w) => w.id == model.id),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(Icons.drag_indicator, size: 28, color: Colors.grey.shade600),
                    ),
                  ),
                ),
              if (isEditMode)
                Positioned(
                  top: 4, right: 4,
                  child: IconButton(
                    icon: Icon(Icons.close, size: 28, color: Colors.red.shade400),
                    tooltip: localizations.translate('delete'),
                    onPressed: () {
                      if (mounted) setState(() => widgetsList.removeWhere((w) => w.id == model.id));
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
        if (newIndex > oldIndex) newIndex -= 1;
        final item = widgetsList.removeAt(oldIndex);
        widgetsList.insert(newIndex, item);
      });
    }
    _saveWidgetsOrder();
  }

  void _noReorderAllowed(int oldIndex, int newIndex) {
    if (mounted) setState(() {});
  }

  // Upravená metoda pro předání dat
  Widget _buildWidgetByType(
      String type,
      List<dynamic> currentReceipts, // Data z lokálního stavu
      ProductProvider productProvider, // Instance ProductProvider
      AppLocalizations localizations, // Instance lokalizací
      ) {
    // Pokud se data ještě načítají (a _dashboardReceipts je prázdný), můžeme zobrazit indikátor
    // nebo necháme widgety, aby si poradily s prázdným seznamem.
    // V tomto případě předpokládáme, že widgety zvládnou prázdný seznam.

    switch (type) {
      case 'summary':
        return SummaryWidget(receipts: currentReceipts); // Předáme lokální data
      case 'top_products':
      // Výpočet top produktů zde nebo uvnitř widgetu pomocí statické metody
        final topProductsData = ReceiptProvider.getTopProductsFromList(currentReceipts, limit: 5);
        return TopProductsWidget(topProductsData: topProductsData); // Předáme zpracovaná data
      case 'top_categories':
        final topCategoriesData = ReceiptProvider.getTopCategoriesFromList(
          currentReceipts,
          limit: 5,
          productProvider: productProvider,
          localizations: localizations,
        );
        return TopCategoriesWidget(topCategoriesData: topCategoriesData); // Předáme zpracovaná data
      case 'hourly_graph':
        return HourlyGraphWidget(receipts: currentReceipts); // Předáme lokální data
      case 'payment_pie_chart':
        return PaymentPieChartWidget(receipts: currentReceipts); // Předáme lokální data
      case 'today_revenue':
        return TodayRevenueWidget(receipts: currentReceipts); // Předáme lokální data
      default:
        return Text(localizations.translate('unknownWidgetType'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // Globální indikátor načítání pro celý dashboard, pokud se načítají widgety nebo data
    // a zároveň je obrazovka aktivní a ještě nebylo nic načteno.
    if (_isLoadingDashboardData && widget.isSelected && !_initialDataLoaded && widgetsList.isNotEmpty) {
      return Scaffold(
          appBar: AppBar( /* ... stejný AppBar ... */
            automaticallyImplyLeading: false,
            iconTheme: const IconThemeData(color: Colors.white),
            backgroundColor: Colors.grey[850],
            title: Text(localizations.translate('dashboardTitle'), style: const TextStyle(color: Colors.white)),
            actions: <Widget>[ /* ... akce ... */
              if (!isEditMode) IconButton(icon: const Icon(Icons.edit), tooltip: localizations.translate('editDashboard'), onPressed: _enterEditMode)
              else ...[
                IconButton(icon: const Icon(Icons.check), tooltip: localizations.translate('finishEditing'), onPressed: _exitEditMode),
                IconButton(icon: const Icon(Icons.add), tooltip: localizations.translate('addWidget'), onPressed: () => _showAddWidgetDialog(context)),
              ]
            ],
          ),
          body: const Center(child: CircularProgressIndicator())
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[400],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.grey[850],
        title: Text(localizations.translate('dashboardTitle'), style: const TextStyle(color: Colors.white)),
        actions: <Widget>[
          if (!isEditMode)
            IconButton(icon: const Icon(Icons.edit), tooltip: localizations.translate('editDashboard'), onPressed: _enterEditMode)
          else ...[
            IconButton(icon: const Icon(Icons.check), tooltip: localizations.translate('finishEditing'), onPressed: _exitEditMode),
            IconButton(icon: const Icon(Icons.add), tooltip: localizations.translate('addWidget'), onPressed: () => _showAddWidgetDialog(context)),
          ]
        ],
      ),
      body: Container(
        color: Colors.grey[400],
        child: widgetsList.isEmpty
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              localizations.translate('noWidgetsOnDashboard'), // Přidej tento klíč
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ),
        )
            : ReorderableListView(
          buildDefaultDragHandles: false,
          onReorder: isEditMode ? _handleReorder : _noReorderAllowed,
          proxyDecorator: (Widget child, int index, Animation<double> animation) {
            if (widgetsList.isEmpty || index < 0 || index >= widgetsList.length) {
              return Material(child: SizedBox.shrink());
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
}