// lib/screens/product_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product_model.dart';
import '../widgets/product_widget.dart';
import '../screens/edit_product_screen.dart';
import '../services/utility_services.dart';
import '../l10n/app_localizations.dart';

class ProductListScreen extends StatefulWidget {
  final bool isSelected; // Přijímáme isSelected z MainScreen

  const ProductListScreen({
    super.key,
    this.isSelected = false,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late ProductProvider productProvider;
  bool isSearchActive = false;
  String searchText = "";
  String? currentCategoryId = '';
  bool showOnlyOnSale = false;
  bool showOnlyInStock = false;
  List<Product> filteredProducts = [];

  String currentSortCriteria = "name";
  bool currentSortAscending = true;

  bool _initialDataLoaded = false;
  String? _expandedProductId;

  @override
  void initState() {
    super.initState();
    print("ProductListScreen: initState, isSelected: ${widget.isSelected}");
    productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.addListener(_onProductProviderChange);

    _loadPreferences().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isSelected) {
          print("ProductListScreen: initState - obrazovka je aktivní, zajišťuji data.");
          _ensureDataAndApplyFilters();
        }
      });
    });
  }

  @override
  void dispose() {
    productProvider.removeListener(_onProductProviderChange);
    _savePreferences();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("ProductListScreen: didUpdateWidget, isSelected: ${widget.isSelected}, oldWidget.isSelected: ${oldWidget.isSelected}, _initialDataLoaded: $_initialDataLoaded");
    if (widget.isSelected && (!oldWidget.isSelected || !_initialDataLoaded)) {
      print("ProductListScreen: Obrazovka se stala aktivní nebo data vyžadují obnovu.");
      _ensureDataAndApplyFilters();
    } else if (!widget.isSelected) {
      _initialDataLoaded = false;
      print("ProductListScreen: Obrazovka již není aktivní.");
    }
  }

  void _onProductProviderChange() {
    if (mounted) {
      print("ProductListScreen: _onProductProviderChange - data v provideru aktualizována.");
      // Vždy aplikujeme filtry na (potenciálně nová) data z provideru.
      // To zaktualizuje náš lokální filteredProducts.
      _applyAllFiltersAndSorting(productProvider);

      // Pokud je obrazovka aktivní, označíme, že cyklus načtení/zpracování pro tuto aktivaci proběhl.
      if (widget.isSelected) {
        _initialDataLoaded = true;
      }
      // Překreslení UI, pokud je potřeba (setState v _applyAllFiltersAndSorting by to měl řešit)
      // Pokud by provider.isLoading byl false, ale my jsme čekali na data, tak se UI překreslí.
      if(mounted) setState(() {}); // Zajistí překreslení i pokud se jen změní isLoading v provideru
    }
  }

  Future<void> _ensureDataAndApplyFilters() async {
    if (!mounted) return;

    // Provider sám nastavuje isLoading = true na začátku fetchAllProductData a false na konci.
    // UI bude reagovat na provider.isLoading přes Consumer/Provider.of(context).watch.
    print("ProductListScreen: _ensureDataAndApplyFilters - Vždy volám fetchAllProductData.");
    try {
      await productProvider.fetchAllProductData(); // Vždy načteme čerstvá data
      // Po dokončení fetchAllProductData, ProductProvider zavolá notifyListeners().
      // Listener _onProductProviderChange v této obrazovce pak zavolá _applyAllFiltersAndSorting,
      // aktualizuje filteredProducts a nastaví _initialDataLoaded = true.
    } catch (e) {
      print("ProductListScreen: Chyba při fetchAllProductData v _ensureDataAndApplyFilters: $e");
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        if (localizations != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('errorLoadingData'))),
          );
        }
      }
    }
    // _initialDataLoaded se nastaví v _onProductProviderChange, když jsou data skutečně zpracována.
    // Pokud by fetchAllProductData nevedlo ke změně (a tudíž k notifyListeners),
    // museli bychom _initialDataLoaded nastavit zde. Ale fetchAllProductData vždy notifikuje na konci.
  }

  Future<void> _loadPreferences() async {
    // ... (metoda _loadPreferences zůstává stejná)
    final preferences = await PreferencesHelper.loadFilterPreferences();
    if (mounted) {
      setState(() {
        currentSortCriteria = preferences['sortCriteria'] ?? "name";
        currentSortAscending = preferences['sortAscending'] ?? true;
        showOnlyOnSale = preferences['showOnlyOnSale'] ?? false;
        showOnlyInStock = preferences['showOnlyInStock'] ?? false;
        currentCategoryId = preferences['currentCategoryId'] ?? '';
      });
    }
  }

  Future<void> _savePreferences() async {
    // ... (metoda _savePreferences zůstává stejná)
    await PreferencesHelper.saveFilterPreferences(
      sortCriteria: currentSortCriteria,
      sortAscending: currentSortAscending,
      showOnlyOnSale: showOnlyOnSale,
      showOnlyInStock: showOnlyInStock,
      currentCategoryId: currentCategoryId ?? '',
    );
  }

  void _applySearch(String query) {
    // ... (metoda _applySearch zůstává stejná)
    if (mounted) {
      setState(() {
        searchText = query;
        _applyAllFiltersAndSorting(productProvider);
      });
    }
  }

  void _applyAllFiltersAndSorting(ProductProvider provider) {
    // ... (metoda _applyAllFiltersAndSorting zůstává stejná, pracuje s provider.products a ukládá do filteredProducts)
    if (!mounted) return;
    print("ProductListScreen: Aplikuji všechny filtry a řazení.");

    final originalList = provider.products;
    List<Product> tempFilteredProducts = List.from(originalList);

    if (currentCategoryId != null && currentCategoryId!.isNotEmpty) {
      tempFilteredProducts = tempFilteredProducts.where((p) => p.categoryId == currentCategoryId).toList();
    }
    if (showOnlyOnSale) {
      tempFilteredProducts = tempFilteredProducts.where((p) => p.onSale).toList();
    }
    if (showOnlyInStock) {
      tempFilteredProducts = tempFilteredProducts.where((p) => p.sku != null && p.sku!.isNotEmpty).toList();
    }
    if (searchText.isNotEmpty) {
      final normalizedSearchText = Utility.normalizeString(searchText.toLowerCase());
      tempFilteredProducts = tempFilteredProducts.where((product) {
        final normalizedName = Utility.normalizeString(product.itemName.toLowerCase());
        final normalizedCategory = Utility.normalizeString(product.categoryName.toLowerCase());
        final normalizedPrice = Utility.normalizeString(product.sellingPrice.toString().toLowerCase());
        final normalizedSku = product.sku != null ? Utility.normalizeString(product.sku!.toLowerCase()) : '';
        return normalizedName.contains(normalizedSearchText) ||
            normalizedCategory.contains(normalizedSearchText) ||
            normalizedPrice.contains(normalizedSearchText) ||
            (normalizedSku.isNotEmpty && normalizedSku.contains(normalizedSearchText));
      }).toList();
    }

    tempFilteredProducts.sort((a, b) {
      dynamic valueA;
      dynamic valueB;
      switch (currentSortCriteria) {
        case 'price': valueA = a.sellingPrice; valueB = b.sellingPrice; break;
        case 'category': valueA = Utility.normalizeString(a.categoryName.toLowerCase()); valueB = Utility.normalizeString(b.categoryName.toLowerCase()); break;
        case 'quantity':
          final qtyA = provider.stockData[a.sku] ?? (a.sku != null && a.sku!.isNotEmpty ? 0.0 : (currentSortAscending ? double.infinity : -double.infinity) );
          final qtyB = provider.stockData[b.sku] ?? (b.sku != null && b.sku!.isNotEmpty ? 0.0 : (currentSortAscending ? double.infinity : -double.infinity) );
          valueA = qtyA; valueB = qtyB; break;
        case 'name': default: valueA = Utility.normalizeString(a.itemName.toLowerCase()); valueB = Utility.normalizeString(b.itemName.toLowerCase()); break;
      }
      int comparisonResult;
      if (valueA is String && valueB is String) comparisonResult = valueA.compareTo(valueB);
      else if (valueA is num && valueB is num) comparisonResult = valueA.compareTo(valueB);
      else comparisonResult = 0;
      return currentSortAscending ? comparisonResult : -comparisonResult;
    });

    if (mounted) {
      setState(() {
        filteredProducts = tempFilteredProducts;
      });
      print("ProductListScreen: Filtry a řazení aplikovány, filteredProducts má ${filteredProducts.length} položek.");
    }
  }

  void _showSortDialog(BuildContext context) {
    // ... (metoda _showSortDialog zůstává stejná)
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.translate('sortProducts')),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: Text(localizations.translate('nameAscending')), onTap: () { _applySorting('name', true); Navigator.of(context).pop(); }),
            ListTile(title: Text(localizations.translate('nameDescending')), onTap: () { _applySorting('name', false); Navigator.of(context).pop(); }),
            ListTile(title: Text(localizations.translate('priceAscending')), onTap: () { _applySorting('price', true); Navigator.of(context).pop(); }),
            ListTile(title: Text(localizations.translate('priceDescending')), onTap: () { _applySorting('price', false); Navigator.of(context).pop(); }),
            ListTile(title: Text(localizations.translate('categoryAscending')), onTap: () { _applySorting('category', true); Navigator.of(context).pop(); }),
            ListTile(title: Text(localizations.translate('categoryDescending')), onTap: () { _applySorting('category', false); Navigator.of(context).pop(); }),
            ListTile(title: Text(localizations.translate('quantityAscending')), onTap: () { _applySorting('quantity', true); Navigator.of(context).pop(); }),
            ListTile(title: Text(localizations.translate('quantityDescending')), onTap: () { _applySorting('quantity', false); Navigator.of(context).pop(); }),
          ])),
        );
      },
    );
  }

  void _applySorting(String criteria, bool ascending) {
    // ... (metoda _applySorting zůstává stejná)
    if (mounted) {
      setState(() {
        currentSortCriteria = criteria;
        currentSortAscending = ascending;
      });
      _applyAllFiltersAndSorting(productProvider);
      print("ProductListScreen: Řazení aplikováno: $criteria, $ascending");
    }
  }

  void _showCategoryFilterDialog(BuildContext context) async {
    // ... (metoda _showCategoryFilterDialog zůstává stejná)
    final localizations = AppLocalizations.of(context)!;
    if (productProvider.categories.isEmpty && mounted) {
      await productProvider.fetchCategories();
    }
    if (!mounted) return;

    String? dialogCategoryId = currentCategoryId;
    bool dialogShowOnlyOnSale = showOnlyOnSale;
    bool dialogShowOnlyInStock = showOnlyInStock;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(localizations.translate('filterProducts')),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: dialogCategoryId, isExpanded: true, hint: Text(localizations.translate('selectCategory')),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem<String>(value: '', child: Text(localizations.translate('allCategories'))),
                  ...productProvider.categories.map((category) => DropdownMenuItem<String>(value: category['categoryId'], child: Text(category['name']))).toList(),
                ],
                onChanged: (value) => setStateSB(() => dialogCategoryId = value),
              ),
              const SizedBox(height: 16),
              SwitchListTile(title: Text(localizations.translate('onlyOnSale')), value: dialogShowOnlyOnSale, onChanged: (value) => setStateSB(() => dialogShowOnlyOnSale = value)),
              SwitchListTile(title: Text(localizations.translate('stockItems')), value: dialogShowOnlyInStock, onChanged: (value) => setStateSB(() => dialogShowOnlyInStock = value)),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations.translate('cancel'))),
              ElevatedButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      currentCategoryId = dialogCategoryId; showOnlyOnSale = dialogShowOnlyOnSale; showOnlyInStock = dialogShowOnlyInStock;
                    });
                    _applyAllFiltersAndSorting(productProvider);
                    print("ProductListScreen: Filtry kategorie, prodeje, skladu aplikovány.");
                  }
                  Navigator.of(context).pop();
                },
                child: Text(localizations.translate('applyFilter')),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // Sledujeme ProductProvider pro jeho isLoading stav a seznam produktů/kategorií
    final currentProductProvider = context.watch<ProductProvider>();

    // Určíme, zda se má zobrazit hlavní indikátor načítání
    bool showOverallLoading = currentProductProvider.isLoading && filteredProducts.isEmpty && widget.isSelected;

    return Scaffold(
      appBar: AppBar( /* ... AppBar zůstává stejný (včetně actions a bottom pro search) ... */
        automaticallyImplyLeading: false,
        title: Text(localizations.translate('productsTitle'), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850],
        iconTheme: const IconThemeData(color: Colors.white),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.search, color: Colors.white), tooltip: localizations.translate('searchTooltip'), onPressed: () { if(mounted) setState(() { isSearchActive = !isSearchActive; if (!isSearchActive) { searchText = ""; _applySearch(""); } }); }),
          IconButton(icon: const Icon(Icons.sort, color: Colors.white), tooltip: localizations.translate('sortTooltip'), onPressed: () => _showSortDialog(context)),
          IconButton(icon: const Icon(Icons.filter_alt_sharp, color: Colors.white), tooltip: localizations.translate('filterTooltip'), onPressed: () => _showCategoryFilterDialog(context)),
        ],
        bottom: isSearchActive ? PreferredSize( preferredSize: const Size.fromHeight(kToolbarHeight - 8), child: Padding( padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0), child: TextField( autofocus: true, decoration: InputDecoration( hintText: localizations.translate('searchForProduct'), hintStyle: const TextStyle(color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0), isDense: true, ), style: const TextStyle(color: Colors.black, fontSize: 15), onChanged: (value) => _applySearch(value), ), ), ) : null,
      ),
      body: Builder(
          builder: (context) {
            if (showOverallLoading) {
              return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 10),
                      Text(localizations.translate('loadingData')),
                    ],
                  )
              );
            }

            // Pokud nejsou žádné produkty v provideru ani po dokončení načítání
            if (currentProductProvider.products.isEmpty && !currentProductProvider.isLoading) {
              return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(localizations.translate('noProductsAvailable'), textAlign: TextAlign.center)));
            }
            // Pokud nejsou žádné produkty odpovídající filtrům (a neprobíhá načítání)
            if (filteredProducts.isEmpty && (searchText.isNotEmpty || (currentCategoryId != null && currentCategoryId!.isNotEmpty) || showOnlyOnSale || showOnlyInStock) && !currentProductProvider.isLoading ) {
              return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(localizations.translate('noProductsMatchFilter'), textAlign: TextAlign.center)));
            }
            // Fallback, pokud je filteredProducts prázdný, ale neměl by být (např. při první inicializaci a data ještě nejsou v filteredProducts)
            // a provider ještě nenahlásil data nebo je widget.isSelected false.
            if (filteredProducts.isEmpty && !currentProductProvider.isLoading && currentProductProvider.products.isNotEmpty && widget.isSelected && !_initialDataLoaded) {
              return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(localizations.translate('loadingData')), // Nebo "Aplikuji filtry..."
                ],
              ));
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 70.0),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return ProductWidget(
                  product: product,
                  categories: currentProductProvider.categories,
                  stockQuantity: product.sku != null ? currentProductProvider.stockData[product.sku] : null,
                  isExpanded: _expandedProductId == product.itemId,
                  onExpand: () {
                    if (mounted) {
                      setState(() {
                        if (_expandedProductId == product.itemId) _expandedProductId = null;
                        else _expandedProductId = product.itemId;
                      });
                    }
                  },
                  highlightText: searchText,
                );
              },
            );
          }
      ),
      floatingActionButton: FloatingActionButton( /* ... FAB zůstává stejný ... */
        heroTag: 'productListScreenFAB',
        onPressed: () async {
          // Použijeme instanční productProvider, který je inicializován v initState
          if (productProvider.categories.isEmpty && mounted) {
            await productProvider.fetchCategories();
          }
          if (!mounted) return;
          final result = await Navigator.of(context).push<bool?>(MaterialPageRoute(builder: (context) => EditProductScreen(categories: productProvider.categories, product: null)));
          // Listener _onProductProviderChange by měl zajistit refresh, pokud dojde ke změně
        },
        backgroundColor: Colors.grey[850],
        tooltip: localizations.translate('addNewProduct'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}