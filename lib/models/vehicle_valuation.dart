class VehicleValuation {
  final String? vehicleDescription;
  final String? dateOfFirstRegistration;
  final int? valuationMileage;
  final int? onTheRoad;
  final int? dealerForecourt;
  final int? tradeRetail;
  final int? privateClean;
  final int? privateAverage;
  final int? partExchange;
  final int? auction;
  final int? tradeAverage;
  final int? tradePoor;

  VehicleValuation({
    this.vehicleDescription,
    this.dateOfFirstRegistration,
    this.valuationMileage,
    this.onTheRoad,
    this.dealerForecourt,
    this.tradeRetail,
    this.privateClean,
    this.privateAverage,
    this.partExchange,
    this.auction,
    this.tradeAverage,
    this.tradePoor,
  });

  factory VehicleValuation.fromJson(Map<String, dynamic> json) {
    final results = json['Results'] as Map<String, dynamic>? ?? {};
    final details =
        results['ValuationDetails'] as Map<String, dynamic>? ?? {};
    final figures =
        details['ValuationFigures'] as Map<String, dynamic>? ?? {};

    return VehicleValuation(
      vehicleDescription: details['VehicleDescription']?.toString(),
      dateOfFirstRegistration:
          details['DateOfFirstRegistration']?.toString(),
      valuationMileage: _parseInt(details['ValuationMileage']),
      onTheRoad: _parseInt(figures['OnTheRoad']),
      dealerForecourt: _parseInt(figures['DealerForecourt']),
      tradeRetail: _parseInt(figures['TradeRetail']),
      privateClean: _parseInt(figures['PrivateClean']),
      privateAverage: _parseInt(figures['PrivateAverage']),
      partExchange: _parseInt(figures['PartExchange']),
      auction: _parseInt(figures['Auction']),
      tradeAverage: _parseInt(figures['TradeAverage']),
      tradePoor: _parseInt(figures['TradePoor']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  bool get hasData =>
      dealerForecourt != null ||
      tradeRetail != null ||
      privateClean != null ||
      privateAverage != null;

  static String formatGbp(int value) {
    final str = value.toString();
    final buf = StringBuffer('\u00a3');
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  /// Price range from private average to dealer forecourt.
  String get displayPrice {
    final prices = <int>[
      ?privateAverage,
      ?privateClean,
      ?tradeRetail,
      ?dealerForecourt,
    ];

    if (prices.isEmpty) return 'No valuation available';

    prices.sort();
    if (prices.length == 1) return formatGbp(prices.first);
    return '${formatGbp(prices.first)} \u2013 ${formatGbp(prices.last)}';
  }
}
