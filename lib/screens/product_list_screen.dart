import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product_model.dart';
import '../widgets/product_widget.dart';
import '../services/api_service.dart';
import '../screens/edit_product_screen.dart';
import '../services/utility_services.dart';
import '../l10n/app_localizations.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

String? expandedProductId;

class _ProductListScreenState extends State<ProductListScreen> {
  Map<String, double> stockData = {};
  bool isSearchActive = false;
  String searchText = "";
  String? currentCategoryId = '';
  bool showOnlyOnSale = true;
  bool showOnlyInStock = false;
  List<Product> filteredProducts = [];
  String currentSortCriteria = "name";
  bool currentSortAscending = true;
  late ProductProvider productProvider;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.fetchCategories();
    productProvider.fetchProducts().then((_) {
      _applyAllFiltersAndSorting(productProvider);
    });
    productProvider.addListener(_onProductProviderChange);
    _loadStockData();
  }

  void _onProductProviderChange() {
    _applyAllFiltersAndSorting(productProvider);
  }

  @override
  void dispose() {
    productProvider.removeListener(_onProductProviderChange);
    _savePreferences();
    super.dispose();
  }

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

  void _applySearch(String query, ProductProvider productProvider) {
    setState(() {
      searchText = query;
      _applyAllFiltersAndSorting(productProvider);
    });
  }

  void _loadStockData() async {
    try {
      final stockList = await ApiService.fetchActualStockData();
      setState(() {
        stockData = {
          for (var item in stockList)
            if (item['sku'] != null) item['sku']: item['quantity'] as double,
        };
      });
    } catch (e) {
      print('Error loading stock data: $e');
    }
  }

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
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: localizations.translate('searchTooltip'),
            onPressed: () {
              setState(() {
                isSearchActive = !isSearchActive;
                if (!isSearchActive) {
                  searchText = "";
                  _applyAllFiltersAndSorting(productProvider);
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: localizations.translate('sortTooltip'),
            onPressed: () => _showSortDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_sharp, color: Colors.white),
            tooltip: localizations.translate('filterTooltip'),
            onPressed: () => _showCategoryFilterDialog(context),
          ),
        ],
        bottom: isSearchActive
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: localizations.translate('searchForProduct'),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                    onChanged: (value) => _applySearch(value, productProvider),
                  ),
                ),
              )
            : null,
      ),
      body: productProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: filteredProducts.isEmpty
                      ? Center(
                          child: Text(
                            localizations.translate('noProductsAvailable'),
                            style: const TextStyle(fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ProductWidget(
                              product: product,
                              categories: productProvider.categories,
                              stockQuantity: stockData[product.sku],
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
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await productProvider.fetchCategories();
          final result = await Navigator.of(context).push<bool?>(
            MaterialPageRoute(
              builder: (context) => EditProductScreen(
                categories: productProvider.categories,
                product: null,
              ),
            ),
          );
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

  void _showCategoryFilterDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
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

  void _applySorting(String criteria, bool ascending) {
    setState(() {
      currentSortCriteria = criteria;
      currentSortAscending = ascending;
      _applyAllFiltersAndSorting(productProvider);
    });
  }

  void _applyAllFiltersAndSorting(ProductProvider provider) {
    final filtered = provider.products.where((product) {
      final matchesCategory =
          (currentCategoryId == null || currentCategoryId!.isEmpty) ||
              product.categoryId == currentCategoryId;
      final matchesOnSale = !showOnlyOnSale || product.onSale;
      final matchesInStock = !showOnlyInStock ||
          (product.sku != null &&
              stockData[product.sku] != null &&
              stockData[product.sku]! > 0);
      final matchesSearch = searchText.isEmpty ||
          Utility.normalizeString(product.itemName.toLowerCase())
              .contains(Utility.normalizeString(searchText.toLowerCase()));
      return matchesCategory &&
          matchesOnSale &&
          matchesInStock &&
          matchesSearch;
    }).toList();

    filtered.sort((a, b) {
      dynamic valueA;
      dynamic valueB;
      if (currentSortCriteria == 'name') {
        valueA = Utility.normalizeString(a.itemName.toLowerCase());
        valueB = Utility.normalizeString(b.itemName.toLowerCase());
      } else if (currentSortCriteria == 'price') {
        valueA = a.price;
        valueB = b.price;
      } else if (currentSortCriteria == 'category') {
        valueA = Utility.normalizeString(a.categoryName.toLowerCase());
        valueB = Utility.normalizeString(b.categoryName.toLowerCase());
      } else if (currentSortCriteria == 'quantity') {
        valueA = stockData[a.sku] ?? 0.0;
        valueB = stockData[b.sku] ?? 0.0;
      }
      return currentSortAscending
          ? Comparable.compare(valueA, valueB)
          : Comparable.compare(valueB, valueA);
    });

    setState(() {
      filteredProducts = filtered;
    });
  }
}
