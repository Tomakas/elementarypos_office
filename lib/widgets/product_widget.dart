// lib/widgets/product_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/product_provider.dart';
import '../screens/edit_product_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/utility_services.dart';

class ProductWidget extends StatefulWidget {
  final Product product;
  final List<Map<String, dynamic>> categories;
  final double? stockQuantity;
  final bool isExpanded;
  final VoidCallback onExpand;
  final String? highlightText;

  const ProductWidget({
    super.key,
    required this.product,
    required this.categories,
    this.stockQuantity,
    required this.isExpanded,
    required this.onExpand,
    this.highlightText,
  });

  @override
  State<ProductWidget> createState() => _ProductWidgetState();
}

class _ProductWidgetState extends State<ProductWidget> {
  late AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    localizations = AppLocalizations.of(context)!;
    final categoryName = widget.categories.firstWhere(
          (cat) => cat['categoryId'] == widget.product.categoryId,
      orElse: () => {'name': localizations.translate("unknownCategory")},
    )['name'];

    final color = productColors[widget.product.color] ?? Colors.grey;

    return GestureDetector(
      onTap: widget.onExpand,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                child: Container(
                  width: 5,
                  color: color,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0).copyWith(left: 13.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExpandableText(
                                text: widget.product.itemName,
                                highlight: widget.highlightText,
                                defaultTextStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: widget.product.onSale ? TextDecoration.none : TextDecoration.lineThrough,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ExpandableText(
                                text: '${localizations.translate("category")}: $categoryName',
                                highlight: widget.highlightText,
                                defaultTextStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              ExpandableText(
                                text: '${localizations.translate("price")}: ${Utility.formatCurrency(widget.product.sellingPrice)}', // Použita sellingPrice
                                highlight: widget.highlightText,
                                defaultTextStyle: const TextStyle(fontSize: 16, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                        if (widget.stockQuantity != null)
                          Expanded(
                            flex: 1,
                            child: Container(
                              alignment: Alignment.center,
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${localizations.translate("stock")}:\n',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.normal,
                                        fontSize: 16,
                                      ),
                                    ),
                                    TextSpan(
                                      text: Utility.formatNumber(widget.stockQuantity!),
                                      style: TextStyle(
                                        color: (widget.stockQuantity! <= 0)
                                            ? Colors.red
                                            : Colors.black,
                                        fontWeight: (widget.stockQuantity! < 0)
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState:
                      widget.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: localizations.translate("edit"),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => EditProductScreen(
                                            categories: widget.categories,
                                            product: widget.product,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy, color: Colors.green),
                                    tooltip: localizations.translate("copy"),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => EditProductScreen(
                                            categories: widget.categories,
                                            product: widget.product,
                                            isCopy: true,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: localizations.translate("delete"),
                                    onPressed: () {
                                      _showDeleteConfirmation(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.exposure, color: Colors.orange),
                                    tooltip: localizations.translate("changeStock"),
                                    onPressed: () {
                                      _showStockChangeDialog(
                                        context,
                                        title: localizations.translate("changeStockTitle"),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStockChangeDialog(BuildContext context, {required String title}) {
    int currentValue = widget.stockQuantity?.toInt() ?? 0; // Initialize with current stock
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: Text(title),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      setStateSB(() => currentValue--);
                    },
                  ),
                  SizedBox(
                    width: 60, // Increased width for better display
                    child: TextField(
                      textAlign: TextAlign.center,
                      controller: TextEditingController(text: currentValue.toString()),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null) {
                          currentValue = parsed;
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setStateSB(() => currentValue++);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(localizations.translate("cancel")),
                ),
                TextButton(
                  onPressed: () {
                    // Zde by měla být logika pro aktualizaci stavu skladu přes ProductProvider
                    print('Stock change confirmed for ${widget.product.itemName}: $currentValue');
                    // productProvider.updateStock(widget.product.itemId, currentValue); // Příklad
                    Navigator.of(context).pop();
                  },
                  child: Text(localizations.translate("confirm")),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.translate("deleteProduct")),
          content: Text(
            '${localizations.translate("confirmDelete")} "${widget.product.itemName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(localizations.translate("cancel")),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog first
                final productProvider = Provider.of<ProductProvider>(context, listen: false);
                try {
                  await productProvider.deleteProduct(widget.product.itemId);
                  if (mounted) { // Check if the widget is still in the tree
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${localizations.translate("productDeleted")}: ${widget.product.itemName}',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${localizations.translate("deleteError")}: $e', // Přidat "deleteError" do lokalizace
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(localizations.translate("delete")),
            ),
          ],
        );
      },
    );
  }
}

class ExpandableText extends StatelessWidget {
  final String text;
  final String? highlight;
  final TextStyle defaultTextStyle;

  const ExpandableText({
    super.key,
    required this.text,
    this.highlight,
    required this.defaultTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (highlight == null || highlight!.isEmpty) {
      return Text(text, style: defaultTextStyle);
    }

    final normalizedText = Utility.normalizeString(text.toLowerCase());
    final normalizedHighlight = Utility.normalizeString(highlight!.toLowerCase());

    List<TextSpan> spans = [];
    int start = 0;
    while (true) {
      final index = normalizedText.indexOf(normalizedHighlight, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: defaultTextStyle.copyWith(backgroundColor: Colors.transparent))); // Ensure default style
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: defaultTextStyle.copyWith(backgroundColor: Colors.transparent)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + highlight!.length),
        style: defaultTextStyle.copyWith(backgroundColor: Colors.yellow), // Apply highlight to default style
      ));
      start = index + highlight!.length;
    }

    return RichText(
      text: TextSpan(
        // style: defaultTextStyle, // Celkový styl pro RichText není nutný, pokud ho mají TextSpans
        children: spans,
      ),
    );
  }
}