import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product_model.dart';
import '../widgets/product_widget.dart';
import '../screens/edit_product_screen.dart';
import '../services/utility_services.dart';
import '../l10n/app_localizations.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

// Globální identifikátor pro rozbalení detailu
String? expandedProductId;

class _ProductListScreenState extends State<ProductListScreen> {
  late ProductProvider productProvider;
  bool isSearchActive = false;
  String searchText = "";
  String? currentCategoryId = '';
  bool showOnlyOnSale = true;
  bool showOnlyInStock = false;
  List<Product> filteredProducts = [];

  // Parametry třídění
  String currentSortCriteria = "name";
  bool currentSortAscending = true;

  @override
  void initState() {
    super.initState();
    productProvider = Provider.of<ProductProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await productProvider.fetchAllProductData();
      // Až tady zavoláme filtrační metodu:
      _applyAllFiltersAndSorting(productProvider);
    });
  }

  @override
  void dispose() {
    productProvider.removeListener(_onProductProviderChange);
    _savePreferences();
    super.dispose();
  }

  // -- Uložení/Nahrání filtračních preferencí do SharedPreferences --
  Future<void> _loadPreferences() async {
    final preferences = await PreferencesHelper.loadFilterPreferences();
    setState(() {
      currentSortCriteria = preferences['sortCriteria'] ?? "name";
      currentSortAscending = preferences['sortAscending'] ?? true;
      showOnlyOnSale = preferences['showOnlyOnSale'] ?? true;
      showOnlyInStock = preferences['showOnlyInStock'] ?? false;
      currentCategoryId = preferences['currentCategoryId'] ?? '';
    });
  }

  Future<void> _savePreferences() async {
    await PreferencesHelper.saveFilterPreferences(
      sortCriteria: currentSortCriteria,
      sortAscending: currentSortAscending,
      showOnlyOnSale: showOnlyOnSale,
      showOnlyInStock: showOnlyInStock,
      currentCategoryId: currentCategoryId!,
    );
  }

  // -- Když productProvider změní data (např. fetchProducts), synchronně se dofiltruje
  void _onProductProviderChange() {
    _applyAllFiltersAndSorting(productProvider);
  }

  // -- Vyhledávání (search field) --
  void _applySearch(String query, ProductProvider productProvider) {
    setState(() {
      searchText = query;
      _applyAllFiltersAndSorting(productProvider);
    });
  }


  // -- Vlastní logika filtrace a řazení --
  void _applyAllFiltersAndSorting(ProductProvider provider) {
    // Vezmeme všechny produkty z provideru
    final originalList = provider.products;

    // 1) Filtrace
    final filtered = originalList.where((product) {
      final matchesCategory =
          (currentCategoryId == null || currentCategoryId!.isEmpty)
              || product.categoryId == currentCategoryId;

      final matchesOnSale = !showOnlyOnSale || product.onSale;

      final quantityInStock = product.sku != null ? (productProvider.stockData[product.sku] ?? 0) : 0;
      final matchesInStock = !showOnlyInStock || (quantityInStock > 0);

      // fulltext search
      final normalizedSearchText = Utility.normalizeString(searchText.toLowerCase());
      final normalizedName = Utility.normalizeString(product.itemName.toLowerCase());
      final normalizedCategory = Utility.normalizeString(product.categoryName.toLowerCase());
      final normalizedPrice = Utility.normalizeString(product.price.toString().toLowerCase());

      final matchesSearch = normalizedSearchText.isEmpty ||
          normalizedName.contains(normalizedSearchText) ||
          normalizedCategory.contains(normalizedSearchText) ||
          normalizedPrice.contains(normalizedSearchText);

      return matchesCategory && matchesOnSale && matchesInStock && matchesSearch;
    }).toList();

    // 2) Řazení
    filtered.sort((a, b) {
      dynamic valueA;
      dynamic valueB;

      switch (currentSortCriteria) {
        case 'price':
          valueA = a.price;
          valueB = b.price;
          break;
        case 'category':
          valueA = Utility.normalizeString(a.categoryName.toLowerCase());
          valueB = Utility.normalizeString(b.categoryName.toLowerCase());
          break;
        case 'quantity':
          final qtyA = productProvider.stockData[a.sku] ?? 0.0;
          final qtyB = productProvider.stockData[b.sku] ?? 0.0;
          valueA = qtyA;
          valueB = qtyB;
          break;
        case 'name':
        default:
          valueA = Utility.normalizeString(a.itemName.toLowerCase());
          valueB = Utility.normalizeString(b.itemName.toLowerCase());
          break;
      }

      return currentSortAscending
          ? Comparable.compare(valueA, valueB)
          : Comparable.compare(valueB, valueA);
    });

    // 3) Uložíme do state
    setState(() {
      filteredProducts = filtered;
    });
  }

  // -- Metoda pro zobrazení sort dialogu --
  void _showSortDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.translate('sortProducts')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(localizations.translate('nameAscending')),
                  onTap: () {
                    _applySorting('name', true);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('nameDescending')),
                  onTap: () {
                    _applySorting('name', false);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('priceAscending')),
                  onTap: () {
                    _applySorting('price', true);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('priceDescending')),
                  onTap: () {
                    _applySorting('price', false);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('categoryAscending')),
                  onTap: () {
                    _applySorting('category', true);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('categoryDescending')),
                  onTap: () {
                    _applySorting('category', false);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('quantityAscending')),
                  onTap: () {
                    _applySorting('quantity', true);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  title: Text(localizations.translate('quantityDescending')),
                  onTap: () {
                    _applySorting('quantity', false);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -- Metoda pro aplikaci konkrétního sortu (volaná z dialogu) --
  void _applySorting(String criteria, bool ascending) {
    setState(() {
      currentSortCriteria = criteria;
      currentSortAscending = ascending;
      _applyAllFiltersAndSorting(productProvider);
    });
  }

  // -- Metoda pro otevření filter dialogu (vybírání kategorie atd.) --
  void _showCategoryFilterDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;

    // Znovu fetch kategorií (pokud by se mezitím něco změnilo)
    await productProvider.fetchCategories();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateSB) => AlertDialog(
            title: Text(localizations.translate('filterProducts')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: currentCategoryId,
                    isExpanded: true,
                    hint: Text(localizations.translate('selectCategory')),
                    items: [
                      DropdownMenuItem<String>(
                        value: '',
                        child: Text(localizations.translate('allCategories')),
                      ),
                      ...productProvider.categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['categoryId'],
                          child: Text(category['name']),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setStateSB(() {
                        currentCategoryId = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(localizations.translate('onlyOnSale')),
                    value: showOnlyOnSale,
                    onChanged: (value) {
                      setStateSB(() {
                        showOnlyOnSale = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: Text(localizations.translate('stockItems')),
                    value: showOnlyInStock,
                    onChanged: (value) {
                      setStateSB(() {
                        showOnlyInStock = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(localizations.translate('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  // Aplikace filtru
                  _applyAllFiltersAndSorting(productProvider);
                  Navigator.of(context).pop();
                },
                child: Text(localizations.translate('applyFilter')),
              ),
            ],
          ),
        );
      },
    );
  }

  // -- Hlavní build() --
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('productsTitle'),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[850],
        actions: <Widget>[
          // Ikona hledání
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: localizations.translate('searchTooltip'),
            onPressed: () {
              setState(() {
                isSearchActive = !isSearchActive;
                if (!isSearchActive) {
                  // Když zavřeme search, zrušíme text
                  searchText = "";
                  _applyAllFiltersAndSorting(productProvider);
                }
              });
            },
          ),
          // Ikona řazení
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: localizations.translate('sortTooltip'),
            onPressed: () => _showSortDialog(context),
          ),
          // Ikona filtru
          IconButton(
            icon: const Icon(Icons.filter_alt_sharp, color: Colors.white),
            tooltip: localizations.translate('filterTooltip'),
            onPressed: () => _showCategoryFilterDialog(context),
          ),
        ],
        // Pokud je search aktivní, zobrazíme TextField v bottom:
        bottom: isSearchActive
            ? PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Padding(
            padding: const EdgeInsets.all(0.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: localizations.translate('searchForProduct'),
                hintStyle: const TextStyle(color: Colors.grey),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0),
              ),
              style: const TextStyle(color: Colors.black),
              onChanged: (value) => _applySearch(value, productProvider),
            ),
          ),
        )
            : null,
      ),

      // Tady použijeme Consumer, abychom nejprve reagovali na isLoading:
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // V tuto chvíli isLoading == false.
          // Nyní zkontrolujeme `filteredProducts`
          if (filteredProducts.isEmpty) {
            // Může to být i localizations.translate('noProductsAvailable')
            return Center(
              child: Text('Žádné produkty k zobrazení.'),
            );
          }

          // Jinak zobrazíme reálná data.
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ProductWidget(
                      product: product,
                      categories: provider.categories,
                      stockQuantity: productProvider.stockData[product.sku],
                      isExpanded: expandedProductId == product.itemId,
                      onExpand: () {
                        setState(() {
                          if (expandedProductId == product.itemId) {
                            expandedProductId = null;
                          } else {
                            expandedProductId = product.itemId;
                          }
                        });
                      },
                      highlightText: searchText,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      // FAB pro přidání nového produktu
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Než otevřeme EditProductScreen, chceme mít i kategorie
          await productProvider.fetchCategories();

          final result = await Navigator.of(context).push<bool?>(
            MaterialPageRoute(
              builder: (context) => EditProductScreen(
                categories: productProvider.categories,
                product: null,
              ),
            ),
          );

          // Pokud se vrátí true, re-fetch products
          if (result == true) {
            await productProvider.fetchProducts();
            _applyAllFiltersAndSorting(productProvider);
          }
        },
        backgroundColor: Colors.grey[850],
        tooltip: localizations.translate('addNewProduct'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
