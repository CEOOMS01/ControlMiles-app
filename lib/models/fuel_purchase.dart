// Olympus Mont Systems LLC - ControlMiles
// lib/models/fuel_purchase.dart

class FuelPurchase {
  final String id;
  final String vehicleId;
  final DateTime purchaseDate;
  final String? stateCode;
  final double gallons;
  final double? pricePerGallonUsd;
  final double? totalCostUsd;
  final String fuelType;
  final String receiptImageUrl;
  final DateTime createdAt;

  const FuelPurchase({
    required this.id,
    required this.vehicleId,
    required this.purchaseDate,
    this.stateCode,
    required this.gallons,
    this.pricePerGallonUsd,
    this.totalCostUsd,
    required this.fuelType,
    required this.receiptImageUrl,
    required this.createdAt,
  });

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  factory FuelPurchase.fromMap(Map<String, dynamic> map) {
    return FuelPurchase(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      stateCode: map['state_code'] as String?,
      gallons: _toDoubleOrNull(map['gallons']) ?? 0.0,
      pricePerGallonUsd: _toDoubleOrNull(map['price_per_gallon_usd']),
      totalCostUsd: _toDoubleOrNull(map['total_cost_usd']),
      fuelType: map['fuel_type'] as String? ?? 'diesel',
      receiptImageUrl: map['receipt_image_url'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
