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
  final List<Map<String, dynamic>> categories; // Potřebujeme pro EditProductScreen
  final double? stockQuantity;
  final bool isExpanded;
  final VoidCallback onExpand;
  final String? highlightText;
  // Parametr isInCategoryView byl ODSTRANĚN

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
    final color = productColors[widget.product.color] ?? Colors.grey;

    return GestureDetector(
      onTap: widget.onExpand,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(30),
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
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8.0),
                          bottomLeft: Radius.circular(8.0)
                      )
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0).copyWith(left: 13.0),
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
                                  color: widget.product.onSale ? Colors.black : Colors.grey[600],
                                ),
                                maxLines: 2,
                              ),
                              // ŘÁDEK S KATEGORIÍ BYL ODSTRANĚN
                              const SizedBox(height: 4),
                              ExpandableText(
                                text: '${localizations.translate("price")}: ${Utility.formatCurrency(widget.product.sellingPrice)}',
                                highlight: widget.highlightText,
                                defaultTextStyle: const TextStyle(fontSize: 15, color: Colors.black, fontWeight: FontWeight.w500),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        if (widget.product.sku != null && widget.product.sku!.isNotEmpty)
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
                                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.normal, fontSize: 14 ),
                                    ),
                                    TextSpan(
                                      text: Utility.formatNumber(widget.stockQuantity ?? 0, decimals: 0),
                                      style: TextStyle(
                                        color: ((widget.stockQuantity ?? 0) <= 0) ? Colors.red.shade700 : Colors.green.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
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
                      crossFadeState: widget.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: const SizedBox.shrink(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), tooltip: localizations.translate("edit"), onPressed: () {
                                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => EditProductScreen(categories: widget.categories, product: widget.product)));
                                  }),
                                  IconButton(icon: const Icon(Icons.copy, color: Colors.green), tooltip: localizations.translate("copy"), onPressed: () {
                                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => EditProductScreen(categories: widget.categories, product: widget.product, isCopy: true)));
                                  }),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), tooltip: localizations.translate("delete"), onPressed: () {
                                    _showDeleteConfirmation(context);
                                  }),
                                ],
                              ),
                            ),
                            if (widget.product.sku != null && widget.product.sku!.isNotEmpty)
                              Expanded(
                                flex: 1,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(icon: const Icon(Icons.exposure, color: Colors.orange), tooltip: localizations.translate("changeStock"), onPressed: () {
                                      _showStockChangeDialog(context, title: localizations.translate("changeStockTitle"));
                                    }),
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
    int currentValue = widget.stockQuantity?.toInt() ?? 0;
    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setStateSB) {
        return AlertDialog(
          title: Text(title),
          content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.remove), onPressed: () => setStateSB(() => currentValue--)),
            SizedBox(width: 60, child: TextField(textAlign: TextAlign.center, controller: TextEditingController(text: currentValue.toString()), keyboardType: TextInputType.number, onChanged: (value) { final parsed = int.tryParse(value); if (parsed != null) currentValue = parsed; },)),
            IconButton(icon: const Icon(Icons.add), onPressed: () => setStateSB(() => currentValue++)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations.translate("cancel"))),
            TextButton(onPressed: () { print('Stock change: ${widget.product.itemName}: $currentValue'); Navigator.of(context).pop(); }, child: Text(localizations.translate("confirm"))),
          ],
        );
      });
    });
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(context: context, builder: (context) {
      return AlertDialog(
        title: Text(localizations.translate("deleteProduct")),
        content: Text('${localizations.translate("confirmDelete")} "${widget.product.itemName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(localizations.translate("cancel"))),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final productProvider = Provider.of<ProductProvider>(context, listen: false);
              try {
                await productProvider.deleteProduct(widget.product.itemId);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${localizations.translate("productDeleted")}: ${widget.product.itemName}')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${localizations.translate("deleteError")}: $e')));
              }
            },
            child: Text(localizations.translate("delete")),
          ),
        ],
      );
    });
  }
}

class ExpandableText extends StatelessWidget {
  final String text;
  final String? highlight;
  final TextStyle defaultTextStyle;
  final int maxLines;

  const ExpandableText({
    super.key,
    required this.text,
    this.highlight,
    required this.defaultTextStyle,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (highlight == null || highlight!.isEmpty) {
      return Text(text, style: defaultTextStyle, overflow: TextOverflow.ellipsis, maxLines: maxLines);
    }
    final normalizedText = Utility.normalizeString(text.toLowerCase());
    final normalizedHighlight = Utility.normalizeString(highlight!.toLowerCase());
    List<TextSpan> spans = [];
    int start = 0;
    while (true) {
      final index = normalizedText.indexOf(normalizedHighlight, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: defaultTextStyle.copyWith(backgroundColor: Colors.transparent)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: defaultTextStyle.copyWith(backgroundColor: Colors.transparent)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + highlight!.length),
        style: defaultTextStyle.copyWith(backgroundColor: Colors.yellow),
      ));
      start = index + highlight!.length;
    }
    return RichText(
      text: TextSpan(children: spans),
      overflow: TextOverflow.ellipsis,
      maxLines: maxLines,
    );
  }
}