import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/customer_model.dart';
import '../services/utility_services.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String? expandedCustomerEmail;
  bool isSearchActive = false;
  String searchText = "";
  List<Customer> filteredCustomers = [];


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customerProvider =
      Provider.of<CustomerProvider>(context, listen: false);

      customerProvider.fetchCustomers().then((_) {
        _applySearch('', customerProvider);
      });
    });
  }


  void _applySearch(String query, CustomerProvider customerProvider) {
    if (query.isEmpty) {
      setState(() {
        filteredCustomers = customerProvider.customers;
      });
      return;
    }

    setState(() {
      filteredCustomers = customerProvider.customers.where((customer) {
        final normalizedQuery = Utility.normalizeString(query.toLowerCase());
        final normalizedName = Utility.normalizeString(customer.name.toLowerCase());
        final normalizedEmail = Utility.normalizeString(customer.email.toLowerCase());
        final normalizedPhone = customer.phone != null ? Utility.normalizeString(customer.phone!.toLowerCase()) : '';

        return normalizedName.contains(normalizedQuery) ||
            normalizedEmail.contains(normalizedQuery) ||
            normalizedPhone.contains(normalizedQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('customersTitle'),
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
                  filteredCustomers = customerProvider.customers;
                }
              });
            },
          ),
        ],
        bottom: isSearchActive
            ? PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Padding(
            padding: const EdgeInsets.all(0.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: localizations.translate('searchForCustomer'), // Placeholder text
                hintStyle: TextStyle(
                  color: Colors.grey, // Nastavení barvy placeholder textu na šedou
                ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              ),
              style: TextStyle(
                color: Colors.black, // Nastavení barvy vstupního textu na černou
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value;
                  _applySearch(value, customerProvider);
                });
              },
            ),
          ),
        )
            : null,
      ),
      body: customerProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredCustomers.isEmpty
          ? Center(
        child: Text(
          localizations.translate('noCustomersAvailable'),
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: filteredCustomers.length,
        itemBuilder: (context, index) {
          final Customer customer = filteredCustomers[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                if (expandedCustomerEmail == customer.email) {
                  expandedCustomerEmail = null;
                } else {
                  expandedCustomerEmail = customer.email;
                }
              });
            },
            child: AnimatedSize(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: Card(
                margin: const EdgeInsets.only(bottom: 12.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Text(
                              customer.name.isNotEmpty
                                  ? customer.name[0]
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _buildHighlightedText(customer.name, searchText),
                                const SizedBox(height: 4),
                                _buildHighlightedText(
                                  '${localizations.translate('email')}: ${customer.email.isNotEmpty ? customer.email : localizations.translate('notAvailable')}',
                                  searchText,
                                ),
                                const SizedBox(height: 4),
                                _buildHighlightedText(
                                  '${localizations.translate('phone')}: ${customer.phone != null && customer.phone!.isNotEmpty ? customer.phone : localizations.translate('notAvailable')}',
                                  searchText,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Rozbalovací část
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        crossFadeState:
                        expandedCustomerEmail == customer.email
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.blue),
                                tooltip:
                                localizations.translate('edit'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${localizations.translate('edit')} ${customer.name}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                tooltip:
                                localizations.translate('delete'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${localizations.translate('delete')} ${customer.name}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.point_of_sale,
                                    color: Colors.green),
                                tooltip: localizations
                                    .translate('customerSales'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${localizations.translate('customerSales')} ${customer.name}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.merge_type,
                                    color: Colors.orange),
                                tooltip:
                                localizations.translate('merge'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${localizations.translate('merge')} ${customer.name}',
                                      ),
                                    ),
                                  );
                                },
                              ),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.translate('addNewCustomer'))),
          );
        },
        backgroundColor: Colors.grey[850],
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String highlight) {
    if (highlight.isEmpty) {
      return Text(text, style: const TextStyle(fontSize: 16));
    }

    final normalizedText = Utility.normalizeString(text.toLowerCase());
    final normalizedHighlight = Utility.normalizeString(highlight.toLowerCase());

    List<TextSpan> spans = [];
    int start = 0;
    while (true) {
      final index = normalizedText.indexOf(normalizedHighlight, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + highlight.length),
        style: const TextStyle(backgroundColor: Colors.yellow),
      ));
      start = index + highlight.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, color: Colors.black),
        children: spans,
      ),
    );
  }
}