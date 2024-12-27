import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/customer_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/customer.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String? expandedCustomerEmail;

  @override
  void initState() {
    super.initState();
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    customerProvider.fetchCustomers();
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
      ),
      body: customerProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : customerProvider.customers.isEmpty
          ? Center(
        child: Text(
          localizations.translate('noCustomersAvailable'),
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: customerProvider.customers.length,
        itemBuilder: (context, index) {
          final Customer customer = customerProvider.customers[index];
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
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${localizations.translate('email')}: ${customer.email.isNotEmpty ? customer.email : localizations.translate('notAvailable')}',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${localizations.translate('phone')}: ${customer.phone != null && customer.phone!.isNotEmpty ? customer.phone : localizations.translate('notAvailable')}',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Rozbalovací část (tlačítka)
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
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                tooltip: localizations.translate('edit'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${localizations.translate('edit')} ${customer.name}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: localizations.translate('delete'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${localizations.translate('delete')} ${customer.name}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.point_of_sale, color: Colors.green),
                                tooltip: localizations.translate('customerSales'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${localizations.translate('customerSales')} ${customer.name}',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.merge_type, color: Colors.orange),
                                tooltip: localizations.translate('merge'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
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
}
