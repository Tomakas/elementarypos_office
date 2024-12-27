//lib/models/customer.dart

class Customer {
  final String customerId;
  final String name;
  final String email;
  final String? phone; // Telefon je nepovinný

  Customer({
    required this.customerId,
    required this.name,
    required this.email,
    this.phone,
  });

  // Factory metoda pro vytvoření instance z JSON
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      customerId: json['customerId'] ?? '',
      name: json['name'] ?? 'Neznámý zákazník',
      email: json['email'] ?? 'Neznámý email',
      phone: json['phone'],
    );
  }

  // Metoda pro převod instance na JSON
  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'name': name,
      'email': email,
      'phone': phone,
    };
  }
}
