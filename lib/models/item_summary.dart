//lib/models/item_summary.dart

class ItemSummary {
  String name;
  int quantity;
  double totalPrice;

  ItemSummary({required this.name, this.quantity = 0, this.totalPrice = 0.0});

  void add(int quantity, double price) {
    this.quantity += quantity;
    totalPrice += price;
  }
}
