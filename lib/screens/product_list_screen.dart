// lib/screens/product_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product_model.dart';
import '../widgets/product_widget.dart';
import '../screens/edit_product_screen.dart';
import '../services/utility_services.dart';
import '../l10n/app_localizations.dart';

// Pomocné třídy pro odlišení typů položek v seznamu
abstract class _CategoryListItem {}

class _DisplayCategoryWrapperItem extends _CategoryListItem {
  final Map<String, dynamic> categoryData;
  _DisplayCategoryWrapperItem(this.categoryData);
}

class _DisplayProductItem extends _CategoryListItem {
  final Product product;
  _DisplayProductItem(this.product);
}

class ProductListScreen extends StatefulWidget {
  final bool isSelected;

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
  String? currentFlatCategoryIdFilter = '';
  bool showOnlyOnSale = false;
  bool showOnlyInStock = false;

  List<Product> flatFilteredProducts = [];
  List<_CategoryListItem> _currentCategoryViewList = [];

  String currentSortCriteria = "name";
  bool currentSortAscending = true;
  bool _isCategoryView = true; // Výchozí je hierarchické zobrazení

  bool _initialDataLoaded = false;
  String? _expandedProductId;
  bool _isScreenCurrentlyLoading = false;
  String? _activeParentCategoryId; // null znamená kořenovou úroveň

  @override
  void initState() {
    super.initState();
    print("ProductListScreen: initState, isSelected: ${widget.isSelected}");
    productProvider = Provider.of<ProductProvider>(context, listen: false);
    productProvider.addListener(_onProductProviderChange);

    _loadPreferences().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isSelected) {
          print("ProductListScreen: initState - obrazovka je aktivní, zajišťuji data a filtry.");
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
      // Pokud se přepínáme na tento tab a je aktivní hierarchické zobrazení,
      // vždy začneme od kořenových kategorií.
      if (_isCategoryView && oldWidget.isSelected == false && widget.isSelected == true) {
        _activeParentCategoryId = null;
      }
      _ensureDataAndApplyFilters();
    } else if (!widget.isSelected) {
      _initialDataLoaded = false; // Resetujeme, pokud tab již není aktivní
      print("ProductListScreen: Obrazovka již není aktivní.");
    }
  }

  void _onProductProviderChange() {
    if (mounted) {
      print("ProductListScreen: _onProductProviderChange - data v provideru aktualizována.");
      _applyAllFiltersAndSorting(productProvider); // Aplikujeme filtry na nová data
      if (widget.isSelected) { // Pokud je tab stále aktivní
        _initialDataLoaded = true; // Označíme, že data pro tento cyklus byla zpracována
      }
      // Pokud byl aktivní náš lokální loader, vypneme ho
      if (_isScreenCurrentlyLoading) {
        if(mounted) setState(() => _isScreenCurrentlyLoading = false);
      } else {
        // Pokud nebyl aktivní náš loader, ale data se změnila (např. z jiné části aplikace)
        // a jsme aktivní, je dobré překreslit UI
        if(widget.isSelected && mounted) setState((){});
      }
    }
  }

  Future<void> _ensureDataAndApplyFilters() async {
    if (!mounted) return;

    if (mounted) {
      setState(() {
        _isScreenCurrentlyLoading = true; // Zapneme náš lokální loader
      });
    }

    print("ProductListScreen: _ensureDataAndApplyFilters - Vždy volám fetchAllProductData.");
    try {
      await productProvider.fetchAllProductData(); // Vždy načteme čerstvá data
      // Listener _onProductProviderChange se postará o volání _applyAllFiltersAndSorting,
      // nastavení _initialDataLoaded a vypnutí _isScreenCurrentlyLoading.
    } catch (e) {
      print("ProductListScreen: Chyba při fetchAllProductData v _ensureDataAndApplyFilters: $e");
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        if (localizations != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('errorLoadingData'))),
          );
        }
        // Vypneme loader i v případě chyby
        if (mounted && _isScreenCurrentlyLoading) {
          setState(() => _isScreenCurrentlyLoading = false);
        }
      }
    }
  }

  Future<void> _loadPreferences() async {
    final preferences = await PreferencesHelper.loadFilterPreferences();
    if (mounted) {
      setState(() {
        currentSortCriteria = preferences['sortCriteria'] ?? "name";
        currentSortAscending = preferences['sortAscending'] ?? true;
        showOnlyOnSale = preferences['showOnlyOnSale'] ?? false;
        showOnlyInStock = preferences['showOnlyInStock'] ?? false;
        currentFlatCategoryIdFilter = preferences['currentCategoryId'] ?? '';
        _isCategoryView = preferences['isCategoryView'] ?? true; // Výchozí je true
      });
      print("ProductListScreen: Preference načteny. _isCategoryView: $_isCategoryView");
    }
  }

  Future<void> _savePreferences() async {
    await PreferencesHelper.saveFilterPreferences(
      sortCriteria: currentSortCriteria,
      sortAscending: currentSortAscending,
      showOnlyOnSale: showOnlyOnSale,
      showOnlyInStock: showOnlyInStock,
      currentCategoryId: currentFlatCategoryIdFilter ?? '',
      isCategoryView: _isCategoryView,
    );
    print("ProductListScreen: Preference uloženy. _isCategoryView: $_isCategoryView");
  }

  void _applySearch(String query) {
    if (mounted) {
      setState(() { searchText = query; });
      _applyAllFiltersAndSorting(productProvider);
    }
  }

  void _applyAllFiltersAndSorting(ProductProvider provider) {
    if (!mounted) return;
    print("ProductListScreen: Aplikuji všechny filtry a řazení. _isCategoryView: $_isCategoryView, _activeParentCategoryId: $_activeParentCategoryId");

    List<Product> productsAfterGlobalFilters = List.from(provider.products);

    if (showOnlyOnSale) { productsAfterGlobalFilters = productsAfterGlobalFilters.where((p) => p.onSale).toList(); }
    if (showOnlyInStock) { productsAfterGlobalFilters = productsAfterGlobalFilters.where((p) => p.sku != null && p.sku!.isNotEmpty).toList(); }
    if (searchText.isNotEmpty) {
      final normalizedSearchText = Utility.normalizeString(searchText.toLowerCase());
      productsAfterGlobalFilters = productsAfterGlobalFilters.where((product) {
        final normalizedName = Utility.normalizeString(product.itemName.toLowerCase());
        final normalizedCategoryName = Utility.normalizeString(product.categoryName.toLowerCase());
        final normalizedSku = product.sku != null ? Utility.normalizeString(product.sku!.toLowerCase()) : '';
        return normalizedName.contains(normalizedSearchText) ||
            normalizedCategoryName.contains(normalizedSearchText) ||
            (normalizedSku.isNotEmpty && normalizedSku.contains(normalizedSearchText));
      }).toList();
    }

    productsAfterGlobalFilters.sort((a, b) {
      dynamic valueA, valueB;
      switch (currentSortCriteria) {
        case 'price': valueA = a.sellingPrice; valueB = b.sellingPrice; break;
        case 'category': valueA = Utility.normalizeString(a.categoryName.toLowerCase()); valueB = Utility.normalizeString(b.categoryName.toLowerCase()); break;
        case 'quantity':
          double qtyAValue;
          if (a.sku != null && a.sku!.isNotEmpty) { qtyAValue = provider.stockData[a.sku] ?? 0.0;}
          else {qtyAValue = currentSortAscending ? double.infinity : -double.infinity;}
          valueA = qtyAValue;
          double qtyBValue;
          if (b.sku != null && b.sku!.isNotEmpty) { qtyBValue = provider.stockData[b.sku] ?? 0.0;}
          else {qtyBValue = currentSortAscending ? double.infinity : -double.infinity;}
          valueB = qtyBValue;
          break;
        case 'name':
        default:
          valueA = Utility.normalizeString(a.itemName.toLowerCase());
          valueB = Utility.normalizeString(b.itemName.toLowerCase());
          break;
      }
      int comparisonResult = (valueA is Comparable && valueB is Comparable) ? Comparable.compare(valueA, valueB) : 0;
      return currentSortAscending ? comparisonResult : -comparisonResult;
    });

    if (_isCategoryView) {
      List<_CategoryListItem> newViewList = [];
      final allProviderCategories = provider.categories;

      if (_activeParentCategoryId == null) { // KOŘENOVÉ ZOBRAZENÍ
        List<Map<String, dynamic>> rootCategoriesData = allProviderCategories.where((cat) {
          String? parentId = cat['parentCategoryId'] as String?;
          return parentId == null || parentId.isEmpty;
        }).toList();

        rootCategoriesData.sort((a, b) => Utility.normalizeString((a['name'] as String? ?? '').toLowerCase()).compareTo(Utility.normalizeString((b['name'] as String? ?? '').toLowerCase())));

        for (var catData in rootCategoriesData) {
          bool categoryHasProducts = productsAfterGlobalFilters.any((p) => _isProductInCategoryOrSubcategory(p, catData['categoryId'] as String, allProviderCategories));
          if(categoryHasProducts) {
            newViewList.add(_DisplayCategoryWrapperItem(catData));
          }
        }
        // Produkty bez kategorie (categoryId je prázdné)
        List<Product> rootLevelProducts = productsAfterGlobalFilters.where((p) => p.categoryId.isEmpty).toList();
        for (var prod in rootLevelProducts) {
          newViewList.add(_DisplayProductItem(prod));
        }
      } else { // ZOBRAZENÍ PODKATEGORIE/PRODUKTŮ UVNITŘ KATEGORIE
        List<Map<String, dynamic>> subCategoriesData = allProviderCategories.where((cat) => (cat['parentCategoryId'] as String?) == _activeParentCategoryId).toList();
        subCategoriesData.sort((a, b) => Utility.normalizeString((a['name'] as String? ?? '').toLowerCase()).compareTo(Utility.normalizeString((b['name'] as String? ?? '').toLowerCase())));
        for (var catData in subCategoriesData) {
          bool subCategoryHasProducts = productsAfterGlobalFilters.any((p) => _isProductInCategoryOrSubcategory(p, catData['categoryId'] as String, allProviderCategories));
          if(subCategoryHasProducts) {
            newViewList.add(_DisplayCategoryWrapperItem(catData));
          }
        }
        List<Product> productsInActiveCategory = productsAfterGlobalFilters.where((p) => p.categoryId == _activeParentCategoryId).toList();
        for (var prod in productsInActiveCategory) {
          newViewList.add(_DisplayProductItem(prod));
        }
      }

      if (mounted) {
        setState(() {
          _currentCategoryViewList = newViewList;
          flatFilteredProducts = [];
        });
      }
    } else {
      List<Product> productsForFlatList = productsAfterGlobalFilters;
      if (currentFlatCategoryIdFilter != null && currentFlatCategoryIdFilter!.isNotEmpty) {
        productsForFlatList = productsForFlatList.where((p) => p.categoryId == currentFlatCategoryIdFilter).toList();
      }
      if (mounted) {
        setState(() {
          flatFilteredProducts = productsForFlatList;
          _currentCategoryViewList = [];
        });
      }
    }
  }

  bool _isProductInCategoryOrSubcategory(Product product, String targetCategoryId, List<Map<String, dynamic>> allCategories) {
    if (product.categoryId == targetCategoryId) return true;
    List<String> subCategoryIds = allCategories.where((cat) => (cat['parentCategoryId'] as String?) == targetCategoryId).map((cat) => cat['categoryId'] as String).toList();
    for (String subCatId in subCategoryIds) {
      if (_isProductInCategoryOrSubcategory(product, subCatId, allCategories)) return true;
    }
    return false;
  }

  void _showSortDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    String tempSortCriteria = currentSortCriteria;
    bool tempSortAscending = currentSortAscending;
    bool tempIsCategoryView = _isCategoryView;
    showDialog(context: context, builder: (BuildContext dialogContext) {
      return StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: Text(localizations.translate('sortProducts')),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(title: Text(localizations.translate('viewByCategories')), value: tempIsCategoryView, onChanged: (bool value) => setStateDialog(() => tempIsCategoryView = value)),
            const Divider(),
            ListTile(title: Text(localizations.translate('nameAscending')), onTap: () { tempSortCriteria = 'name'; tempSortAscending = true; Navigator.of(dialogContext).pop(true); }),
            ListTile(title: Text(localizations.translate('nameDescending')), onTap: () { tempSortCriteria = 'name'; tempSortAscending = false; Navigator.of(dialogContext).pop(true); }),
            ListTile(title: Text(localizations.translate('priceAscending')), onTap: () { tempSortCriteria = 'price'; tempSortAscending = true; Navigator.of(dialogContext).pop(true); }),
            ListTile(title: Text(localizations.translate('priceDescending')), onTap: () { tempSortCriteria = 'price'; tempSortAscending = false; Navigator.of(dialogContext).pop(true); }),
            if (!tempIsCategoryView) ...[
              ListTile(title: Text(localizations.translate('categoryAscending')), onTap: () { tempSortCriteria = 'category'; tempSortAscending = true; Navigator.of(dialogContext).pop(true); }),
              ListTile(title: Text(localizations.translate('categoryDescending')), onTap: () { tempSortCriteria = 'category'; tempSortAscending = false; Navigator.of(dialogContext).pop(true); }),
            ],
            ListTile(title: Text(localizations.translate('quantityAscending')), onTap: () { tempSortCriteria = 'quantity'; tempSortAscending = true; Navigator.of(dialogContext).pop(true); }),
            ListTile(title: Text(localizations.translate('quantityDescending')), onTap: () { tempSortCriteria = 'quantity'; tempSortAscending = false; Navigator.of(dialogContext).pop(true); }),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(localizations.translate('cancel'))),
            ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(localizations.translate('applySort'))),
          ],
        );});
    }).then((shouldApply) {
      if (shouldApply == true && mounted) {
        bool criteriaOrViewChanged = currentSortCriteria != tempSortCriteria || currentSortAscending != tempSortAscending || _isCategoryView != tempIsCategoryView;
        if (criteriaOrViewChanged) {
          setState(() {
            currentSortCriteria = tempSortCriteria; currentSortAscending = tempSortAscending;
            if (_isCategoryView != tempIsCategoryView) _activeParentCategoryId = null;
            _isCategoryView = tempIsCategoryView;
          });
          _applyAllFiltersAndSorting(productProvider);
        }
      }
    });
  }

  void _showCategoryFilterDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    if (productProvider.categories.isEmpty && mounted) await productProvider.fetchCategories();
    if (!mounted) return;
    String? dialogFlatCategoryId = currentFlatCategoryIdFilter;
    bool dialogShowOnlyOnSale = showOnlyOnSale;
    bool dialogShowOnlyInStock = showOnlyInStock;
    showDialog(context: context, builder: (BuildContext context) {
      return StatefulBuilder(builder: (context, setStateSB) {
        return AlertDialog(
          title: Text(localizations.translate('filterProducts')),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!_isCategoryView) ...[
              DropdownButtonFormField<String>(
                value: dialogFlatCategoryId, isExpanded: true, hint: Text(localizations.translate('selectCategory')),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem<String>(value: '', child: Text(localizations.translate('allCategories'))),
                  ...productProvider.categories.map((category) => DropdownMenuItem<String>(value: category['categoryId'], child: Text(category['name']))).toList(),
                ],
                onChanged: (value) => setStateSB(() => dialogFlatCategoryId = value),
              ),
              const SizedBox(height: 16),
            ],
            SwitchListTile(title: Text(localizations.translate('onlyOnSale')), value: dialogShowOnlyOnSale, onChanged: (value) => setStateSB(() => dialogShowOnlyOnSale = value)),
            SwitchListTile(title: Text(localizations.translate('stockItems')), value: dialogShowOnlyInStock, onChanged: (value) => setStateSB(() => dialogShowOnlyInStock = value)),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations.translate('cancel'))),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    if (!_isCategoryView) currentFlatCategoryIdFilter = dialogFlatCategoryId; else currentFlatCategoryIdFilter = '';
                    showOnlyOnSale = dialogShowOnlyOnSale; showOnlyInStock = dialogShowOnlyInStock;
                  });
                  _applyAllFiltersAndSorting(productProvider);
                }
                Navigator.of(context).pop();
              },
              child: Text(localizations.translate('applyFilter')),
            ),
          ],
        );});
    });
  }

  void _navigateUpHierarchy(AppLocalizations localizations) {
    if (_activeParentCategoryId == null) return;
    String? grandparentCategoryId;
    try {
      final currentCatMeta = productProvider.categories.firstWhere((cat) => cat['categoryId'] == _activeParentCategoryId);
      grandparentCategoryId = currentCatMeta['parentCategoryId'] as String?;
      if (grandparentCategoryId != null && grandparentCategoryId.isEmpty) grandparentCategoryId = null;
    } catch (e) { grandparentCategoryId = null; }
    if (mounted) {
      setState(() { _activeParentCategoryId = grandparentCategoryId; _expandedProductId = null; });
      _applyAllFiltersAndSorting(productProvider);
    }
  }

  String _getCategoryPathText(AppLocalizations localizations) {
    if (_activeParentCategoryId == null) return ""; // V kořeni se lišta nezobrazuje, text není potřeba

    List<String> pathSegments = [];
    String? tempCategoryId = _activeParentCategoryId;
    int depth = 0;

    while (tempCategoryId != null && tempCategoryId.isNotEmpty && depth < 3) {
      try {
        final categoryMeta = productProvider.categories.firstWhere(
              (cat) => cat['categoryId'] == tempCategoryId,
        );
        pathSegments.insert(0, categoryMeta['name'] as String? ?? '...');
        tempCategoryId = categoryMeta['parentCategoryId'] as String?;
        if (tempCategoryId != null && tempCategoryId.isEmpty) tempCategoryId = null;
        depth++;
      } catch (e) {
        pathSegments.insert(0, '...');
        break;
      }
    }
    if (pathSegments.isEmpty && _activeParentCategoryId != null) {
      try {
        final activeCat = productProvider.categories.firstWhere((cat) => cat['categoryId'] == _activeParentCategoryId);
        return activeCat['name'] as String? ?? _activeParentCategoryId!;
      } catch (_) { return _activeParentCategoryId!;}
    }
    return pathSegments.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final currentProductProvider = context.watch<ProductProvider>();
    bool showLoadingIndicator = (_isScreenCurrentlyLoading && widget.isSelected && !_initialDataLoaded) ||
        (currentProductProvider.isLoading &&
            (_isCategoryView ? _currentCategoryViewList.isEmpty : flatFilteredProducts.isEmpty) &&
            widget.isSelected);
    Widget bodyContent;

    if (showLoadingIndicator) {
      bodyContent = Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const CircularProgressIndicator(), const SizedBox(height: 10),
        Text(localizations.translate('loadingData')),
      ]));
    } else if (_isCategoryView) {
      Widget categoryNavigationBar = const SizedBox.shrink(); // Výchozí: žádná lišta (pro kořen)

      if (_activeParentCategoryId != null) {
        String pathText = _getCategoryPathText(localizations); // Cesta k aktuální zobrazené kategorii

        categoryNavigationBar = Card(
          margin: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 4.0), // Odsazení shora, aby nebyla nalepená na AppBar
          elevation: 2.0, // Jemný stín jako u položek kategorií
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          color: Colors.blueGrey[100], // Tmavší odstín
          child: ListTile(
            leading: Icon(Icons.arrow_back_ios_new, color: Colors.blueGrey[700], size: 20), // Šipka doleva
            title: Text(
              pathText, // Zobrazí cestu aktuální kategorie, např. "Nápoje / Alkohol / Portské"
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.blueGrey[900]),
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _navigateUpHierarchy(localizations),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0), // Menší vertikální padding
            dense: true,
          ),
        );
      }

      bodyContent = Column(children: [
        categoryNavigationBar, // Zobrazí se, jen pokud _activeParentCategoryId != null
        Expanded(child: _currentCategoryViewList.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text( localizations.translate(_activeParentCategoryId == null ? 'noRootCategoriesOrProducts' : 'emptyCategoryOrNoMatchFilter'), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600]))))
            : ListView.builder(padding: EdgeInsets.only(bottom: 70.0, top: _activeParentCategoryId == null ? 8.0 : 4.0), itemCount: _currentCategoryViewList.length, itemBuilder: (context, index) {
          final item = _currentCategoryViewList[index];
          if (item is _DisplayCategoryWrapperItem) {
            return Card(margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), elevation: 1.5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), child: ListTile(
              leading: Icon(Icons.folder_outlined, color: Colors.amber[800], size: 28),
              title: Text(item.categoryData['name'] as String? ?? 'Neznámá kat.', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () { if (mounted) { setState(() { _activeParentCategoryId = item.categoryData['categoryId'] as String?; _expandedProductId = null; }); _applyAllFiltersAndSorting(productProvider); }},
            ));
          } else if (item is _DisplayProductItem) {
            return ProductWidget( // Volání ProductWidget beze změny oproti poslední verzi
              product: item.product, categories: currentProductProvider.categories,
              stockQuantity: item.product.sku != null ? currentProductProvider.stockData[item.product.sku] : null,
              isExpanded: _expandedProductId == item.product.itemId,
              onExpand: () { if (mounted) setState(() { if (_expandedProductId == item.product.itemId) _expandedProductId = null; else _expandedProductId = item.product.itemId; }); },
              highlightText: searchText,
            );
          }
          return const SizedBox.shrink();
        },),),
      ],);
    } else {
      if (currentProductProvider.products.isEmpty && !currentProductProvider.isLoading) {
        bodyContent = Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(localizations.translate('noProductsAvailable'), textAlign: TextAlign.center)));
      } else if (flatFilteredProducts.isEmpty && (searchText.isNotEmpty || (currentFlatCategoryIdFilter != null && currentFlatCategoryIdFilter!.isNotEmpty) || showOnlyOnSale || showOnlyInStock) && !currentProductProvider.isLoading ) {
        bodyContent = Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(localizations.translate('noProductsMatchFilter'), textAlign: TextAlign.center)));
      } else if (flatFilteredProducts.isEmpty && !currentProductProvider.isLoading && currentProductProvider.products.isNotEmpty && widget.isSelected && !_initialDataLoaded) {
        bodyContent = Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ const CircularProgressIndicator(), const SizedBox(height: 10), Text(localizations.translate('loadingData'))]));
      } else {
        bodyContent = ListView.builder(
          padding: const EdgeInsets.only(bottom: 70.0), itemCount: flatFilteredProducts.length,
          itemBuilder: (context, index) {
            final product = flatFilteredProducts[index];
            return ProductWidget( // Volání ProductWidget beze změny oproti poslední verzi
              product: product, categories: currentProductProvider.categories,
              stockQuantity: product.sku != null ? currentProductProvider.stockData[product.sku] : null,
              isExpanded: _expandedProductId == product.itemId,
              onExpand: () { if (mounted) setState(() { if (_expandedProductId == product.itemId) _expandedProductId = null; else _expandedProductId = product.itemId; }); },
              highlightText: searchText,
            );},);
      }
    }

    return Scaffold(
      appBar: AppBar( /* ... AppBar ... */
        automaticallyImplyLeading: false,
        title: Text(localizations.translate('productsTitle'), style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[850], iconTheme: const IconThemeData(color: Colors.white),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.search, color: Colors.white), tooltip: localizations.translate('searchTooltip'), onPressed: () { if(mounted) setState(() { isSearchActive = !isSearchActive; if (!isSearchActive) { searchText = ""; _applySearch(""); } }); }),
          IconButton(icon: const Icon(Icons.sort, color: Colors.white), tooltip: localizations.translate('sortTooltip'), onPressed: () => _showSortDialog(context)),
          IconButton(icon: const Icon(Icons.filter_alt_sharp, color: Colors.white), tooltip: localizations.translate('filterTooltip'), onPressed: () => _showCategoryFilterDialog(context)),
        ],
        bottom: isSearchActive ? PreferredSize( preferredSize: const Size.fromHeight(kToolbarHeight - 2), child: Padding( padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0), child: TextField( autofocus: true, decoration: InputDecoration( hintText: localizations.translate('searchForProduct'), hintStyle: const TextStyle(color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10), isDense: true, ), style: const TextStyle(color: Colors.black, fontSize: 17), onChanged: (value) => _applySearch(value), ), ), ) : null,
      ),
      body: bodyContent,
      floatingActionButton: FloatingActionButton( /* ... FAB ... */
        heroTag: 'productListScreenFAB',
        onPressed: () async {
          if (productProvider.categories.isEmpty && mounted) await productProvider.fetchCategories();
          if (!mounted) return;
          await Navigator.of(context).push<bool?>(MaterialPageRoute(builder: (context) => EditProductScreen(categories: productProvider.categories, product: null)));
        },
        backgroundColor: Colors.grey[850], tooltip: localizations.translate('addNewProduct'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}