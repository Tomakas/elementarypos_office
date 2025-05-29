// lib/screens/customers_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/customer_model.dart';
import '../services/utility_services.dart';

class CustomersScreen extends StatefulWidget {
  final bool isSelected;

  const CustomersScreen({
    super.key,
    this.isSelected = false,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String? expandedCustomerEmail;
  bool isSearchActive = false;
  String searchText = "";
  List<Customer> filteredCustomers = []; // Lokální "cache" pro zobrazení
  bool _initialDataLoaded = false;

  @override
  void initState() {
    super.initState();
    print("CustomersScreen: initState, isSelected: ${widget.isSelected}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isSelected) {
        print("CustomersScreen: initState - obrazovka je aktivní, načítám zákazníky.");
        _loadCustomerDataAndApplySearch();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CustomersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("CustomersScreen: didUpdateWidget, isSelected: ${widget.isSelected}, oldWidget.isSelected: ${oldWidget.isSelected}, _initialDataLoaded: $_initialDataLoaded");
    if (widget.isSelected && (!oldWidget.isSelected || !_initialDataLoaded)) {
      print("CustomersScreen: Obrazovka se stala aktivní nebo data vyžadují obnovu, načítám zákazníky.");
      _loadCustomerDataAndApplySearch();
    } else if (!widget.isSelected) {
      _initialDataLoaded = false;
      print("CustomersScreen: Obrazovka již není aktivní.");
    }
  }

  Future<void> _loadCustomerDataAndApplySearch() async {
    if (!mounted) return;

    // Provider sám o sobě nastavuje isLoading
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    print("CustomersScreen: _loadCustomerDataAndApplySearch - Zahajuji customerProvider.fetchCustomers.");
    try {
      // Provider nastaví isLoading = true a notifikuje. Build metoda níže na to zareaguje.
      await customerProvider.fetchCustomers();
      if (mounted) {
        _applySearchInternal(searchText, customerProvider.customers);
        _initialDataLoaded = true;
        print("CustomersScreen: _loadCustomerDataAndApplySearch - Zákazníci načteni a filtr aplikován.");
      }
    } catch (e) {
      print("CustomersScreen: _loadCustomerDataAndApplySearch - Chyba při načítání zákazníků: $e");
      if(mounted) {
        final localizations = AppLocalizations.of(context);
        if (localizations != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('errorLoadingData'))),
          );
        }
      }
    } finally {
      // Provider nastaví isLoading = false a notifikuje. Build metoda na to zareaguje.
      // Pokud bychom chtěli explicitně překreslit i po chybě nebo pokud fetchCustomers neudělal notify:
      if(mounted) setState((){});
    }
  }

  void _applySearchInternal(String query, List<Customer> allCustomers) {
    if (!mounted) return;
    print("CustomersScreen: _applySearchInternal - Aplikuji hledání: '$query' na ${allCustomers.length} zákazníků.");

    List<Customer> tempFiltered;
    if (query.isEmpty) {
      tempFiltered = List.from(allCustomers);
    } else {
      tempFiltered = allCustomers.where((customer) {
        final normalizedQuery = Utility.normalizeString(query.toLowerCase());
        final normalizedName = Utility.normalizeString(customer.name.toLowerCase());
        final normalizedEmail = Utility.normalizeString(customer.email.toLowerCase());
        final normalizedPhone = customer.phone != null ? Utility.normalizeString(customer.phone!.toLowerCase()) : '';
        return normalizedName.contains(normalizedQuery) ||
            normalizedEmail.contains(normalizedQuery) ||
            normalizedPhone.contains(normalizedQuery);
      }).toList();
    }

    // Aktualizujeme stav pouze pokud se seznam skutečně změnil,
    // abychom předešli zbytečným rebuildům, pokud např. applySearch je voláno vícekrát se stejným výsledkem.
    // Pro jednoduchost teď voláme setState vždy.
    setState(() {
      filteredCustomers = tempFiltered;
    });
    print("CustomersScreen: _applySearchInternal - filteredCustomers má ${filteredCustomers.length} položek.");
  }

  void _onSearchTextChanged(String query) {
    if (!mounted) return;
    // Získáme customerProvider zde, protože _applySearchInternal ho potřebuje.
    // listen: false, protože změna textu by neměla sama o sobě vyvolat rebuild kvůli provideru.
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    setState(() {
      searchText = query;
    });
    _applySearchInternal(query, customerProvider.customers);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // Sledujeme providera pro jeho isLoading stav
    final customerProvider = context.watch<CustomerProvider>();

    // Zobrazit celoobrazovkový loader POUZE pokud:
    // 1. Provider načítá (customerProvider.isLoading)
    // 2. Tato obrazovka je aktivní (widget.isSelected)
    // 3. A ZÁROVEŇ nemáme žádná data k zobrazení v naší lokální cache (filteredCustomers.isEmpty)
    //    (to znamená, že je to pravděpodobně první načítání pro tuto aktivní obrazovku)
    final bool showFullScreenLoader = customerProvider.isLoading &&
        widget.isSelected &&
        filteredCustomers.isEmpty;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.grey[850],
        title: Text(
          localizations.translate('customersTitle'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: localizations.translate('searchTooltip'),
            onPressed: () {
              if(mounted){
                setState(() {
                  isSearchActive = !isSearchActive;
                  if (!isSearchActive) {
                    searchText = "";
                    // Při deaktivaci vyhledávání znovu aplikujeme prázdný filtr
                    // na data, která jsou aktuálně v customerProvider.customers
                    _onSearchTextChanged("");
                  }
                });
              }
            },
          ),
        ],
        bottom: isSearchActive
            ? PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0.0,0.0,0.0,0.0),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: localizations.translate('searchForCustomer'),
                hintStyle: TextStyle(color: Colors.grey),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
              style: TextStyle(color: Colors.black),
              onChanged: _onSearchTextChanged,
            ),
          ),
        )
            : null,
      ),
      body: Builder( // Použijeme Builder pro kontext, pokud by byl potřeba níže
          builder: (context) {
            if (showFullScreenLoader) {
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

            // Pokud není celoobrazovkový loader, ale filteredCustomers je prázdný,
            // zobrazíme příslušnou zprávu ("no customers" nebo "no results for filter").
            if (filteredCustomers.isEmpty) {
              String messageKey;
              // Provider.customers je náš "master list" ze serveru.
              // filteredCustomers je to, co se aktuálně zobrazuje po aplikaci searchText.
              if (searchText.isNotEmpty) {
                messageKey = 'noCustomersMatchFilter'; // Přidej tento klíč do lokalizace
              } else if (customerProvider.customers.isEmpty && !customerProvider.isLoading) {
                // Pokud je providerův seznam prázdný A ZÁROVEŇ se nenačítá
                messageKey = 'noCustomersAvailable';
              } else if (customerProvider.isLoading && widget.isSelected) {
                // Pokud se stále načítá, ale showFullScreenLoader nebyl true (což by nemělo nastat, pokud je filteredCustomers empty)
                // Ale pro jistotu zobrazíme loader.
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const CircularProgressIndicator(), const SizedBox(height: 10),
                  Text(localizations.translate('loadingData')),
                ]));
              }
              else {
                // Fallback, pokud je filteredCustomers prázdný, ale provider má data a nehledá se
                // (např. nějaký nečekaný stav)
                messageKey = 'noCustomersAvailable';
              }

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    localizations.translate(messageKey),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Zobrazení seznamu zákazníků, pokud filteredCustomers není prázdný
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
              itemCount: filteredCustomers.length,
              itemBuilder: (context, index) {
                final Customer customer = filteredCustomers[index];
                return GestureDetector(
                  onTap: () {
                    if(mounted){
                      setState(() {
                        if (expandedCustomerEmail == customer.email) {
                          expandedCustomerEmail = null;
                        } else {
                          expandedCustomerEmail = customer.email;
                        }
                      });
                    }
                  },
                  child: AnimatedSize( /* ... zbytek itemBuilderu pro zobrazení zákazníka zůstává stejný ... */
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blueGrey[700],
                                  child: Text(
                                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 16.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildHighlightedText(customer.name, searchText, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.grey[850])),
                                      if (customer.email.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        _buildHighlightedText(
                                          '${localizations.translate('email')}: ${customer.email}',
                                          searchText,
                                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                        ),
                                      ],
                                      if (customer.phone != null && customer.phone!.isNotEmpty) ... [
                                        const SizedBox(height: 4),
                                        _buildHighlightedText(
                                          '${localizations.translate('phone')}: ${customer.phone}',
                                          searchText,
                                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 300),
                              crossFadeState:
                              expandedCustomerEmail == customer.email
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: localizations.translate('edit'), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${localizations.translate('edit')} ${customer.name}'))); }),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: localizations.translate('delete'), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${localizations.translate('delete')} ${customer.name}'))); }),
                                    IconButton(icon: const Icon(Icons.point_of_sale, color: Colors.green), tooltip: localizations.translate('customerSales'), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${localizations.translate('customerSales')} ${customer.name}'))); }),
                                    IconButton(icon: const Icon(Icons.merge_type, color: Colors.orange), tooltip: localizations.translate('merge'), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${localizations.translate('merge')} ${customer.name}'))); }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }
      ),
      floatingActionButton: FloatingActionButton( /* ... FAB zůstává stejný ... */
        heroTag: 'customersScreenFAB',
        onPressed: () { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(localizations.translate('addNewCustomer')))); },
        backgroundColor: Colors.grey[850],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String highlight, {TextStyle? style}) {
    // ... (metoda _buildHighlightedText zůstává stejná)
    final defaultStyle = style ?? const TextStyle(fontSize: 16, color: Colors.black);
    if (highlight.isEmpty) {
      return Text(text, style: defaultStyle);
    }

    final normalizedText = Utility.normalizeString(text.toLowerCase());
    final normalizedHighlight = Utility.normalizeString(highlight.toLowerCase());

    List<TextSpan> spans = [];
    int start = 0;
    while (true) {
      final index = normalizedText.indexOf(normalizedHighlight, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: defaultStyle));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: defaultStyle));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + highlight.length),
        style: defaultStyle.copyWith(backgroundColor: Colors.yellow[400], fontWeight: FontWeight.bold),
      ));
      start = index + highlight.length;
    }
    return RichText(text: TextSpan(children: spans));
  }
}