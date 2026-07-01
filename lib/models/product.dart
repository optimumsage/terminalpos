/// A reusable catalog product that can be dropped onto invoices.
class Product {
  Product({
    required this.id,
    required this.name,
    this.price = 0,
    this.sku = '',
    this.unit = '',
    required this.createdAt,
  });

  final String id;
  String name;
  double price;
  String sku;
  String unit;
  final DateTime createdAt;

  Product copyWith({String? name, double? price, String? sku, String? unit}) {
    return Product(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'sku': sku,
        'unit': unit,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        sku: json['sku'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
