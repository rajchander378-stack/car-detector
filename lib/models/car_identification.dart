class CarIdentification {
  final bool identified;
  final double confidence;
  final String? make;
  final String? model;
  final int? yearMin;
  final int? yearMax;
  final String? generation;
  final String? trim;
  final String? bodyStyle;
  final String? colour;
  final List<String> distinguishingFeatures;
  final String? notes;
  final String? error;
  final String? numberPlate;

  CarIdentification({
    required this.identified,
    required this.confidence,
    this.make,
    this.model,
    this.yearMin,
    this.yearMax,
    this.generation,
    this.trim,
    this.bodyStyle,
    this.colour,
    this.distinguishingFeatures = const [],
    this.notes,
    this.error,
    this.numberPlate,
  });

  factory CarIdentification.fromJson(Map<String, dynamic> json) {
    return CarIdentification(
      identified: json['identified'] ?? false,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      make: json['make'],
      model: json['model'],
      yearMin: json['year_min'],
      yearMax: json['year_max'],
      generation: json['generation'],
      trim: json['trim'],
      bodyStyle: json['body_style'],
      colour: json['colour'],
      distinguishingFeatures: json['distinguishing_features'] != null
          ? List<String>.from(json['distinguishing_features'])
          : [],
      notes: json['notes'],
      error: json['error'],
      numberPlate: json['number_plate'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identified': identified,
      'confidence': confidence,
      'make': make,
      'model': model,
      'year_min': yearMin,
      'year_max': yearMax,
      'generation': generation,
      'trim': trim,
      'body_style': bodyStyle,
      'colour': colour,
      'distinguishing_features': distinguishingFeatures,
      'notes': notes,
      'error': error,
      'number_plate': numberPlate,
    };
  }

  CarIdentification copyWith({
    bool? identified,
    double? confidence,
    String? make,
    String? model,
    int? yearMin,
    int? yearMax,
    String? generation,
    String? trim,
    String? bodyStyle,
    String? colour,
    List<String>? distinguishingFeatures,
    String? notes,
    String? error,
    String? numberPlate,
  }) {
    return CarIdentification(
      identified: identified ?? this.identified,
      confidence: confidence ?? this.confidence,
      make: make ?? this.make,
      model: model ?? this.model,
      yearMin: yearMin ?? this.yearMin,
      yearMax: yearMax ?? this.yearMax,
      generation: generation ?? this.generation,
      trim: trim ?? this.trim,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      colour: colour ?? this.colour,
      distinguishingFeatures: distinguishingFeatures ?? this.distinguishingFeatures,
      notes: notes ?? this.notes,
      error: error ?? this.error,
      numberPlate: numberPlate ?? this.numberPlate,
    );
  }

  String get displayName {
    final parts = <String>[];
    if (yearMin != null && yearMax != null) {
      if (yearMin == yearMax) {
        parts.add('$yearMin');
      } else {
        parts.add('$yearMin-$yearMax');
      }
    }
    if (make != null && make!.isNotEmpty) parts.add(make!);
    if (model != null && model!.isNotEmpty) parts.add(model!);
    if (trim != null && trim!.isNotEmpty) parts.add(trim!);
    if (parts.isNotEmpty) return parts.join(' ');
    return 'Unknown Vehicle';
  }

  String get pricingQuery {
    final parts = <String>[];
    if (make != null) parts.add(make!);
    if (model != null) parts.add(model!);
    return parts.join(' ');
  }

  int? get estimatedYear {
    if (yearMin != null && yearMax != null) {
      return ((yearMin! + yearMax!) / 2).round();
    }
    return yearMin ?? yearMax;
  }
}