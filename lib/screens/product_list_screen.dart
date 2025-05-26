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
  bool showOnlyOnSale = false;
  bool showOnlyInStock = false;
  List<Product> filteredProducts = [];

  String currentSortCriteria = "name";
  bool currentSortAscending = true;

  @override
  void initState() {
    super.initState();
    productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.addListener(_onProductProviderChange);
    _loadPreferences().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Zajistíme, aby se data načetla, pokud ještě nejsou
        if (productProvider.products.isEmpty || productProvider.categories.isEmpty) {
          await productProvider.fetchAllProductData();
        } else {
          // Pokud data již jsou, jen aplikujeme filtry (což se stane přes _onProductProviderChange)
          // nebo explicitně zde, pokud by listener nebyl spolehlivý při startu
          _applyAllFiltersAndSorting(productProvider);
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

  Future<void> _loadPreferences() async {
    final preferences = await PreferencesHelper.loadFilterPreferences();
    if (mounted) {
      setState(() {
        currentSortCriteria = preferences['sortCriteria'] ?? "name";
        currentSortAscending = preferences['sortAscending'] ?? true;
        showOnlyOnSale = preferences['showOnlyOnSale'] ?? false; // Načtená hodnota, výchozí je v PreferencesHelper
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
      _applyAllFiltersAndSorting(productProvider);
    }
  }

  void _applySearch(String query) {
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
    List<Product> tempFilteredProducts = List.from(originalList);

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

    // Filter by inStock (SKLADOVÉ POLOŽKY) - Zobrazí produkty s SKU, nezávisle na množství
    if (showOnlyInStock) {
      tempFilteredProducts = tempFilteredProducts.where((product) {
        return product.sku != null && product.sku!.isNotEmpty;
      }).toList();
    }

    // Filter by search text
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

    // Sorting
    tempFilteredProducts.sort((a, b) {
      dynamic valueA;
      dynamic valueB;

      switch (currentSortCriteria) {
        case 'price':
          valueA = a.sellingPrice;
          valueB = b.sellingPrice;
          break;
        case 'category':
          valueA = Utility.normalizeString(a.categoryName.toLowerCase());
          valueB = Utility.normalizeString(b.categoryName.toLowerCase());
          break;
        case 'quantity':
          final qtyA = provider.stockData[a.sku] ?? (a.sku != null && a.sku!.isNotEmpty ? 0.0 : -double.infinity);
          final qtyB = provider.stockData[b.sku] ?? (b.sku != null && b.sku!.isNotEmpty ? 0.0 : -double.infinity);
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

    if (mounted) {
      setState(() {
        filteredProducts = tempFilteredProducts;
      });
    }
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
        return StatefulBuilder(
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
                            dialogCategoryId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(localizations.translate('onlyOnSale')),
                        value: dialogShowOnlyOnSale,
                        onChanged: (value) {
                          setStateSB(() {
                            dialogShowOnlyOnSale = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        title: Text(localizations.translate('stockItems')),
                        value: dialogShowOnlyInStock,
                        onChanged: (value) {
                          setStateSB(() {
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
                        setState(() {
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
        iconTheme: const IconThemeData(color: Colors.white),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: localizations.translate('searchTooltip'),
            onPressed: () {
              setState(() {
                isSearchActive = !isSearchActive;
                if (!isSearchActive) {
                  searchText = "";
                  _applySearch("");
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
          preferredSize: const Size.fromHeight(kToolbarHeight - 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: localizations.translate('searchForProduct'),
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                isDense: true,
              ),
              style: const TextStyle(color: Colors.black, fontSize: 15),
              onChanged: (value) => _applySearch(value),
            ),
          ),
        )
            : null,
      ),
      body: Consumer<ProductProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && filteredProducts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.products.isEmpty && !provider.isLoading) {
            return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(localizations.translate('noProductsAvailable'), textAlign: TextAlign.center),
                )
            );
          }
          if (filteredProducts.isEmpty && (searchText.isNotEmpty || (currentCategoryId != null && currentCategoryId!.isNotEmpty) || showOnlyOnSale || showOnlyInStock) && !provider.isLoading ) {
            return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(localizations.translate('noProductsMatchFilter'), textAlign: TextAlign.center),
                )
            );
          }
          if (filteredProducts.isEmpty && provider.products.isNotEmpty && !provider.isLoading && searchText.isEmpty && (currentCategoryId == null || currentCategoryId!.isEmpty) && !showOnlyOnSale && !showOnlyInStock) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if(mounted) _applyAllFiltersAndSorting(provider);
            });
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 70.0),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return ProductWidget(
                product: product,
                categories: provider.categories, // <<== VRÁCENÝ PARAMETR
                stockQuantity: product.sku != null ? provider.stockData[product.sku] : null,
                isExpanded: expandedProductId == product.itemId,
                onExpand: () {
                  if (mounted) {
                    setState(() {
                      if (expandedProductId == product.itemId) {
                        expandedProductId = null;
                      } else {
                        expandedProductId = product.itemId;
                      }
                    });
                  }
                },
                highlightText: searchText,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'productListScreenFAB',
        onPressed: () async {
          if (productProvider.categories.isEmpty && mounted) {
            await productProvider.fetchCategories();
          }
          if (!mounted) return;

          final result = await Navigator.of(context).push<bool?>(
            MaterialPageRoute(
              builder: (context) => EditProductScreen(
                categories: productProvider.categories,
                product: null,
              ),
            ),
          );

          if (result == true && mounted) {
            // Není třeba nic dělat, _onProductProviderChange se postará o refresh
          }
        },
        backgroundColor: Colors.grey[850],
        tooltip: localizations.translate('addNewProduct'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

