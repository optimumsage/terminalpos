import '../core/enums.dart';

/// A single line on an invoice. May reference a catalog [productId] or be a
/// free-form entry (productId == null).
class InvoiceItem {
  InvoiceItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountKind = DiscountKind.none,
    this.discountValue = 0,
    this.productId,
  });

  final String id;
  String name;
  double quantity;
  double unitPrice;
  DiscountKind discountKind;
  double discountValue;
  String? productId;

  double get gross => quantity * unitPrice;

  double get discount {
    switch (discountKind) {
      case DiscountKind.none:
        return 0;
      case DiscountKind.percent:
        return gross * (discountValue / 100);
      case DiscountKind.fixed:
        return discountValue;
    }
  }

  /// Line total after its own discount, never negative.
  double get net {
    final value = gross - discount;
    return value < 0 ? 0 : value;
  }

  InvoiceItem copyWith({
    String? id,
    String? name,
    double? quantity,
    double? unitPrice,
    DiscountKind? discountKind,
    double? discountValue,
    String? productId,
    bool clearProduct = false,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      discountKind: discountKind ?? this.discountKind,
      discountValue: discountValue ?? this.discountValue,
      productId: clearProduct ? null : (productId ?? this.productId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'discountKind': discountKind.name,
        'discountValue': discountValue,
        'productId': productId,
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        id: json['id'] as String,
        name: json['name'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        discountKind: DiscountKind.values.byName(
          json['discountKind'] as String? ?? 'none',
        ),
        discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
        productId: json['productId'] as String?,
      );
}

/// A full invoice document. The line items and header fields are edited in the
/// UI; totals are derived on demand by [InvoiceCalculator].
class Invoice {
  Invoice({
    required this.id,
    required this.name,
    required this.number,
    required this.templateId,
    required this.createdAt,
    required this.updatedAt,
    this.status = InvoiceStatus.draft,
    this.billToName = '',
    this.billToPhone = '',
    this.billToAddress = '',
    this.notes = '',
    this.discountKind = DiscountKind.none,
    this.discountValue = 0,
    this.taxEnabled = false,
    this.taxRate = 0,
    List<InvoiceItem>? items,
  }) : items = items ?? [];

  final String id;
  String name;
  String number;
  String templateId;
  final DateTime createdAt;
  DateTime updatedAt;
  InvoiceStatus status;
  String billToName;
  String billToPhone;
  String billToAddress;
  String notes;
  DiscountKind discountKind;
  double discountValue;
  bool taxEnabled;
  double taxRate;
  List<InvoiceItem> items;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'number': number,
        'templateId': templateId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'status': status.name,
        'billToName': billToName,
        'billToPhone': billToPhone,
        'billToAddress': billToAddress,
        'notes': notes,
        'discountKind': discountKind.name,
        'discountValue': discountValue,
        'taxEnabled': taxEnabled,
        'taxRate': taxRate,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        id: json['id'] as String,
        name: json['name'] as String,
        number: json['number'] as String? ?? '',
        templateId: json['templateId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        status: InvoiceStatus.values.byName(
          json['status'] as String? ?? 'draft',
        ),
        billToName: json['billToName'] as String? ?? '',
        billToPhone: json['billToPhone'] as String? ?? '',
        billToAddress: json['billToAddress'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        discountKind: DiscountKind.values.byName(
          json['discountKind'] as String? ?? 'none',
        ),
        discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0,
        taxEnabled: json['taxEnabled'] as bool? ?? false,
        taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
