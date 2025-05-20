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
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

String? expandedProductId;

class _ProductListScreenState extends State<ProductListScreen> {
  late ProductProvider productProvider;
  bool isSearchActive = false;
  String searchText = "";
  String? currentCategoryId = ''; // Default to all categories
  bool showOnlyOnSale = false; // Default changed to false
  bool showOnlyInStock = false;
  List<Product> filteredProducts = [];

  String currentSortCriteria = "name";
  bool currentSortAscending = true;

  @override
  void initState() {
    super.initState();
    productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.addListener(_onProductProviderChange); // Přidán listener
    _loadPreferences().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await productProvider.fetchAllProductData();
        // _applyAllFiltersAndSorting je již voláno v _onProductProviderChange nebo po fetchAllProductData
      });
    });
  }

  @override
  void dispose() {
    productProvider.removeListener(_onProductProviderChange);
    _savePreferences();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
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
    await PreferencesHelper.saveFilterPreferences(
      sortCriteria: currentSortCriteria,
      sortAscending: currentSortAscending,
      showOnlyOnSale: showOnlyOnSale,
      showOnlyInStock: showOnlyInStock,
      currentCategoryId: currentCategoryId ?? '',
    );
  }

  void _onProductProviderChange() {
    if (mounted) {
      // Provider data changed (e.g., after fetchAllProductData), re-apply filters
      _applyAllFiltersAndSorting(productProvider);
    }
  }

  void _applySearch(String query) { // Odebrán nepotřebný argument provider
    if (mounted) {
      setState(() {
        searchText = query;
        _applyAllFiltersAndSorting(productProvider);
      });
    }
  }

  void _applyAllFiltersAndSorting(ProductProvider provider) {
    if (!mounted) return;

    final originalList = provider.products;
    List<Product> tempFilteredProducts = originalList;

    // Filter by category
    if (currentCategoryId != null && currentCategoryId!.isNotEmpty) {
      tempFilteredProducts = tempFilteredProducts.where((product) {
        return product.categoryId == currentCategoryId;
      }).toList();
    }

    // Filter by onSale
    if (showOnlyOnSale) {
      tempFilteredProducts = tempFilteredProducts.where((product) {
        return product.onSale;
      }).toList();
    }

    // Filter by inStock
    if (showOnlyInStock) {
      tempFilteredProducts = tempFilteredProducts.where((product) {
        final quantityInStock = product.sku != null ? (provider.stockData[product.sku] ?? 0) : 0;
        return quantityInStock > 0;
      }).toList();
    }

    // Filter by search text
    if (searchText.isNotEmpty) {
      final normalizedSearchText = Utility.normalizeString(searchText.toLowerCase());
      tempFilteredProducts = tempFilteredProducts.where((product) {
        final normalizedName = Utility.normalizeString(product.itemName.toLowerCase());
        final normalizedCategory = Utility.normalizeString(product.categoryName.toLowerCase());
        // Použití sellingPrice pro vyhledávání v ceně
        final normalizedPrice = Utility.normalizeString(product.sellingPrice.toString().toLowerCase());
        final normalizedSku = product.sku != null ? Utility.normalizeString(product.sku!.toLowerCase()) : '';

        return normalizedName.contains(normalizedSearchText) ||
            normalizedCategory.contains(normalizedSearchText) ||
            normalizedPrice.contains(normalizedSearchText) ||
            normalizedSku.contains(normalizedSearchText);
      }).toList();
    }

    // Sorting
    tempFilteredProducts.sort((a, b) {
      dynamic valueA;
      dynamic valueB;

      switch (currentSortCriteria) {
        case 'price':
          valueA = a.sellingPrice; // Aktualizováno na sellingPrice
          valueB = b.sellingPrice; // Aktualizováno na sellingPrice
          break;
        case 'category':
          valueA = Utility.normalizeString(a.categoryName.toLowerCase());
          valueB = Utility.normalizeString(b.categoryName.toLowerCase());
          break;
        case 'quantity':
          final qtyA = provider.stockData[a.sku] ?? 0.0;
          final qtyB = provider.stockData[b.sku] ?? 0.0;
          valueA = qtyA;
          valueB = qtyB;
          break;
        case 'name':
        default:
          valueA = Utility.normalizeString(a.itemName.toLowerCase());
          valueB = Utility.normalizeString(b.itemName.toLowerCase());
          break;
      }

      int comparisonResult = Comparable.compare(valueA, valueB);
      return currentSortAscending ? comparisonResult : -comparisonResult;
    });

    setState(() {
      filteredProducts = tempFilteredProducts;
    });
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
                  title: Text(localizations.translate('priceAscending')), // Název je "price..." ale třídí se podle sellingPrice
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

  void _applySorting(String criteria, bool ascending) {
    if (mounted) {
      setState(() {
        currentSortCriteria = criteria;
        currentSortAscending = ascending;
        _applyAllFiltersAndSorting(productProvider);
      });
    }
  }

  void _showCategoryFilterDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    // Ensure categories are loaded, but don't make it part of this dialog's state logic directly
    if (productProvider.categories.isEmpty) {
      await productProvider.fetchCategories();
    }


    // Temporary state for the dialog
    String? dialogCategoryId = currentCategoryId;
    bool dialogShowOnlyOnSale = showOnlyOnSale;
    bool dialogShowOnlyInStock = showOnlyInStock;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder( // Use StatefulBuilder for dialog's own state
            builder: (context, setStateSB) {
              return AlertDialog(
                title: Text(localizations.translate('filterProducts')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: dialogCategoryId,
                        isExpanded: true,
                        hint: Text(localizations.translate('selectCategory')),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: [
                          DropdownMenuItem<String>(
                            value: '', // Represents "All Categories"
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
                          setStateSB(() { // Update dialog's temporary state
                            dialogCategoryId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(localizations.translate('onlyOnSale')),
                        value: dialogShowOnlyOnSale,
                        onChanged: (value) {
                          setStateSB(() { // Update dialog's temporary state
                            dialogShowOnlyOnSale = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: Text(localizations.translate('stockItems')),
                        value: dialogShowOnlyInStock,
                        onChanged: (value) {
                          setStateSB(() { // Update dialog's temporary state
                            dialogShowOnlyInStock = value;
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
                      if (mounted) {
                        setState(() { // Apply changes to the screen's state
                          currentCategoryId = dialogCategoryId;
                          showOnlyOnSale = dialogShowOnlyOnSale;
                          showOnlyInStock = dialogShowOnlyInStock;
                          _applyAllFiltersAndSorting(productProvider);
                        });
                      }
                      Navigator.of(context).pop();
                    },
                    child: Text(localizations.translate('applyFilter')),
                  ),
                ],
              );
            }
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
                  _applySearch(""); // Apply empty search to refresh
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
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Added padding
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
              onChanged: (value) => _applySearch(value),
            ),
          ),
        )
            : null,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && filteredProducts.isEmpty) { // Show loader only if products not yet loaded
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.products.isEmpty && !provider.isLoading) {
            return Center(
              child: Text(localizations.translate('noProductsAvailable')),
            );
          }

          if (filteredProducts.isEmpty && searchText.isNotEmpty) {
            return Center(
              child: Text(localizations.translate('noProductsMatchFilter')), // PŘIDAT DO LOKALIZACE
            );
          }


          return ListView.builder(
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return ProductWidget(
                product: product,
                categories: provider.categories, // Pass categories from provider
                stockQuantity: provider.stockData[product.sku],
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (productProvider.categories.isEmpty) {
            await productProvider.fetchCategories();
          }
          final result = await Navigator.of(context).push<bool?>(
            MaterialPageRoute(
              builder: (context) => EditProductScreen(
                categories: productProvider.categories,
                product: null, // Creating a new product
              ),
            ),
          );

          if (result == true) {
            // Data already re-fetched and filters re-applied by _onProductProviderChange
            // or directly if addProduct in provider calls notifyListeners which
            // triggers _onProductProviderChange
          }
        },
        backgroundColor: Colors.grey[850],
        tooltip: localizations.translate('addNewProduct'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}