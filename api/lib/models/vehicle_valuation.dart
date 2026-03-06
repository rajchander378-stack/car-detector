class VehicleValuation {
  final double? retailPrice;
  final double? tradePrice;
  final double? privatePrice;
  final int? mileage;
  final String? registrationYear;
  final String? fuelType;
  final String? engineSize;

  VehicleValuation({
    this.retailPrice,
    this.tradePrice,
    this.privatePrice,
    this.mileage,
    this.registrationYear,
    this.fuelType,
    this.engineSize,
  });

  factory VehicleValuation.fromJson(Map<String, dynamic> json) {
    final response = json['Response'] as Map<String, dynamic>?;
    final dataItems = response?['DataItems'] as Map<String, dynamic>?;
    final valuation =
        dataItems?['ValuationList'] as Map<String, dynamic>?;
    final vehicleData =
        dataItems?['TechnicalDetails'] as Map<String, dynamic>?;
    final general = vehicleData?['General'] as Map<String, dynamic>?;
    final engine = vehicleData?['Engine'] as Map<String, dynamic>?;

    return VehicleValuation(
      retailPrice: _parseDouble(valuation?['DealerForecourt']),
      tradePrice: _parseDouble(valuation?['TradeRetail']),
      privatePrice: _parseDouble(valuation?['PrivateClean']),
      mileage: _parseInt(valuation?['Mileage']),
      registrationYear: general?['RegistrationYear']?.toString(),
      fuelType: engine?['FuelType']?.toString(),
      engineSize: engine?['EngineSize']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'retail_price': retailPrice,
      'trade_price': tradePrice,
      'private_price': privatePrice,
      'mileage': mileage,
      'registration_year': registrationYear,
      'fuel_type': fuelType,
      'engine_size': engineSize,
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool get hasData =>
      retailPrice != null || tradePrice != null || privatePrice != null;
}
