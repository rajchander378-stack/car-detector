/// Tyre and wheel specifications from the UKVD TyreDetails data block.
class TyreDetailsData {
  final List<TyreFitment> fitments;

  TyreDetailsData({this.fitments = const []});

  /// The standard (factory) fitment, or the first available.
  TyreFitment? get standardFitment =>
      fitments.where((f) => f.isStandardFitment).firstOrNull ?? fitments.firstOrNull;

  factory TyreDetailsData.fromApiJson(Map<String, dynamic> json) {
    final list = json['TyreDetailsList'] as List<dynamic>? ?? [];
    return TyreDetailsData(
      fitments: list.map((t) => TyreFitment.fromApiJson(t as Map<String, dynamic>)).toList(),
    );
  }

  factory TyreDetailsData.fromStoredJson(Map<String, dynamic> json) {
    final list = json['fitments'] as List<dynamic>? ?? [];
    return TyreDetailsData(
      fitments: list.map((t) => TyreFitment.fromStoredJson(t as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'fitments': fitments.map((f) => f.toJson()).toList(),
  };
}

class TyreFitment {
  final bool isStandardFitment;
  final TyreSpec? front;
  final TyreSpec? rear;
  final String? hubPcd;
  final double? hubCenterBoreMm;
  final int? fixingTorqueNm;

  TyreFitment({
    this.isStandardFitment = false,
    this.front,
    this.rear,
    this.hubPcd,
    this.hubCenterBoreMm,
    this.fixingTorqueNm,
  });

  factory TyreFitment.fromApiJson(Map<String, dynamic> json) {
    final frontMap = json['Front'] as Map<String, dynamic>? ?? {};
    final rearMap = json['Rear'] as Map<String, dynamic>? ?? {};
    final hub = json['Hub'] as Map<String, dynamic>? ?? {};
    final fixing = json['Fixing'] as Map<String, dynamic>? ?? {};

    return TyreFitment(
      isStandardFitment: json['IsStandardFitmentForVehicle'] as bool? ?? false,
      front: frontMap.isNotEmpty ? TyreSpec.fromApiJson(frontMap) : null,
      rear: rearMap.isNotEmpty ? TyreSpec.fromApiJson(rearMap) : null,
      hubPcd: hub['Pcd']?.toString(),
      hubCenterBoreMm: (hub['CenterBoreMm'] as num?)?.toDouble(),
      fixingTorqueNm: fixing['TorqueNm'] as int?,
    );
  }

  factory TyreFitment.fromStoredJson(Map<String, dynamic> json) => TyreFitment(
    isStandardFitment: json['is_standard_fitment'] as bool? ?? false,
    front: json['front'] != null
        ? TyreSpec.fromStoredJson(json['front'] as Map<String, dynamic>)
        : null,
    rear: json['rear'] != null
        ? TyreSpec.fromStoredJson(json['rear'] as Map<String, dynamic>)
        : null,
    hubPcd: json['hub_pcd'],
    hubCenterBoreMm: (json['hub_center_bore_mm'] as num?)?.toDouble(),
    fixingTorqueNm: json['fixing_torque_nm'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'is_standard_fitment': isStandardFitment,
    'front': front?.toJson(),
    'rear': rear?.toJson(),
    'hub_pcd': hubPcd,
    'hub_center_bore_mm': hubCenterBoreMm,
    'fixing_torque_nm': fixingTorqueNm,
  };
}

class TyreSpec {
  final String? sizeDescription;
  final int? sectionWidthMm;
  final int? aspectRatio;
  final int? rimDiameterInches;
  final String? loadIndex;
  final String? speedIndex;
  final bool isRunFlat;
  final double? pressureBar;
  final int? pressurePsi;
  final String? rimSizeDescription;

  TyreSpec({
    this.sizeDescription,
    this.sectionWidthMm,
    this.aspectRatio,
    this.rimDiameterInches,
    this.loadIndex,
    this.speedIndex,
    this.isRunFlat = false,
    this.pressureBar,
    this.pressurePsi,
    this.rimSizeDescription,
  });

  factory TyreSpec.fromApiJson(Map<String, dynamic> json) {
    final tyre = json['Tyre'] as Map<String, dynamic>? ?? {};
    final rim = json['Rim'] as Map<String, dynamic>? ?? {};
    final pressure = tyre['Pressure'] as Map<String, dynamic>? ?? {};
    final tyrePressure = pressure['TyrePressure'] as Map<String, dynamic>? ?? {};

    return TyreSpec(
      sizeDescription: tyre['SizeDescription']?.toString(),
      sectionWidthMm: tyre['SectionWidthMm'] as int?,
      aspectRatio: tyre['AspectRatio'] as int?,
      rimDiameterInches: tyre['RimDiameterInches'] as int?,
      loadIndex: tyre['LoadIndex']?.toString(),
      speedIndex: tyre['SpeedIndex']?.toString(),
      isRunFlat: tyre['IsRunFlat'] as bool? ?? false,
      pressureBar: (tyrePressure['Bar'] as num?)?.toDouble(),
      pressurePsi: tyrePressure['Psi'] as int?,
      rimSizeDescription: rim['SizeDescription']?.toString(),
    );
  }

  factory TyreSpec.fromStoredJson(Map<String, dynamic> json) => TyreSpec(
    sizeDescription: json['size_description'],
    sectionWidthMm: json['section_width_mm'] as int?,
    aspectRatio: json['aspect_ratio'] as int?,
    rimDiameterInches: json['rim_diameter_inches'] as int?,
    loadIndex: json['load_index'],
    speedIndex: json['speed_index'],
    isRunFlat: json['is_run_flat'] as bool? ?? false,
    pressureBar: (json['pressure_bar'] as num?)?.toDouble(),
    pressurePsi: json['pressure_psi'] as int?,
    rimSizeDescription: json['rim_size_description'],
  );

  Map<String, dynamic> toJson() => {
    'size_description': sizeDescription,
    'section_width_mm': sectionWidthMm,
    'aspect_ratio': aspectRatio,
    'rim_diameter_inches': rimDiameterInches,
    'load_index': loadIndex,
    'speed_index': speedIndex,
    'is_run_flat': isRunFlat,
    'pressure_bar': pressureBar,
    'pressure_psi': pressurePsi,
    'rim_size_description': rimSizeDescription,
  };
}
