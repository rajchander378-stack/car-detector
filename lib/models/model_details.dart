/// Vehicle model specifications from the UKVD ModelDetails data block.
class ModelDetailsData {
  // Identification
  final String? make;
  final String? range;
  final String? model;
  final String? modelVariant;
  final String? series;
  final String? countryOfOrigin;

  // Body
  final String? bodyStyle;
  final int? numberOfDoors;
  final int? numberOfSeats;
  final int? fuelTankCapacityLitres;

  // Dimensions (mm)
  final int? heightMm;
  final int? lengthMm;
  final int? widthMm;
  final int? wheelbaseLengthMm;

  // Weights (kg)
  final int? kerbWeightKg;
  final int? grossVehicleWeightKg;
  final int? unladenWeightKg;

  // Engine / Powertrain
  final String? powertrainType;
  final String? fuelType;
  final String? engineDescription;
  final String? aspiration;
  final String? cylinderArrangement;
  final int? numberOfCylinders;
  final int? engineCapacityCc;
  final double? engineCapacityLitres;
  final String? fuelDelivery;

  // Transmission
  final String? transmissionType;
  final int? numberOfGears;
  final String? driveType;

  // Performance
  final double? bhp;
  final double? torqueNm;
  final double? zeroToSixtyMph;
  final int? maxSpeedMph;

  // Fuel economy
  final double? combinedMpg;
  final double? urbanColdMpg;
  final double? extraUrbanMpg;

  // Emissions
  final String? euroStatus;
  final int? manufacturerCo2;

  // Safety
  final int? ncapStarRating;
  final int? ncapAdultPercent;
  final int? ncapChildPercent;

  // EV details
  final double? batteryCapacityKwh;
  final double? batteryUsableKwh;
  final int? evRealRangeMiles;
  final int? maxChargeInputPowerKw;

  // Warranty
  final int? warrantyMonths;
  final int? warrantyMiles;

  ModelDetailsData({
    this.make,
    this.range,
    this.model,
    this.modelVariant,
    this.series,
    this.countryOfOrigin,
    this.bodyStyle,
    this.numberOfDoors,
    this.numberOfSeats,
    this.fuelTankCapacityLitres,
    this.heightMm,
    this.lengthMm,
    this.widthMm,
    this.wheelbaseLengthMm,
    this.kerbWeightKg,
    this.grossVehicleWeightKg,
    this.unladenWeightKg,
    this.powertrainType,
    this.fuelType,
    this.engineDescription,
    this.aspiration,
    this.cylinderArrangement,
    this.numberOfCylinders,
    this.engineCapacityCc,
    this.engineCapacityLitres,
    this.fuelDelivery,
    this.transmissionType,
    this.numberOfGears,
    this.driveType,
    this.bhp,
    this.torqueNm,
    this.zeroToSixtyMph,
    this.maxSpeedMph,
    this.combinedMpg,
    this.urbanColdMpg,
    this.extraUrbanMpg,
    this.euroStatus,
    this.manufacturerCo2,
    this.ncapStarRating,
    this.ncapAdultPercent,
    this.ncapChildPercent,
    this.batteryCapacityKwh,
    this.batteryUsableKwh,
    this.evRealRangeMiles,
    this.maxChargeInputPowerKw,
    this.warrantyMonths,
    this.warrantyMiles,
  });

  bool get isEv => powertrainType == 'BEV' || powertrainType == 'PHEV' || powertrainType == 'REEV';

  String get engineSummary {
    final parts = <String>[];
    if (engineCapacityLitres != null) parts.add('${engineCapacityLitres}L');
    if (aspiration != null && aspiration != 'Naturally Aspirated') parts.add(aspiration!);
    if (fuelType != null) parts.add(fuelType!);
    if (bhp != null) parts.add('${bhp!.round()} BHP');
    return parts.isEmpty ? 'N/A' : parts.join(' ');
  }

  factory ModelDetailsData.fromApiJson(Map<String, dynamic> json) {
    final id = json['ModelIdentification'] as Map<String, dynamic>? ?? {};
    final body = json['BodyDetails'] as Map<String, dynamic>? ?? {};
    final dims = json['Dimensions'] as Map<String, dynamic>? ?? {};
    final weights = json['Weights'] as Map<String, dynamic>? ?? {};
    final powertrain = json['Powertrain'] as Map<String, dynamic>? ?? {};
    final ice = powertrain['IceDetails'] as Map<String, dynamic>? ?? {};
    final transmission = powertrain['Transmission'] as Map<String, dynamic>? ?? {};
    final safety = json['Safety'] as Map<String, dynamic>? ?? {};
    final ncap = safety['EuroNcap'] as Map<String, dynamic>? ?? {};
    final emissions = json['Emissions'] as Map<String, dynamic>? ?? {};
    final perf = json['Performance'] as Map<String, dynamic>? ?? {};
    final power = perf['Power'] as Map<String, dynamic>? ?? {};
    final torque = perf['Torque'] as Map<String, dynamic>? ?? {};
    final stats = perf['Statistics'] as Map<String, dynamic>? ?? {};
    final economy = perf['FuelEconomy'] as Map<String, dynamic>? ?? {};
    final addl = json['AdditionalInformation'] as Map<String, dynamic>? ?? {};
    final warranty = addl['VehicleWarrantyInformation'] as Map<String, dynamic>? ?? {};

    // EV details
    final ev = powertrain['EvDetails'] as Map<String, dynamic>? ?? {};
    final evTech = ev['TechnicalDetails'] as Map<String, dynamic>? ?? {};
    final evPerf = ev['Performance'] as Map<String, dynamic>? ?? {};
    final evRange = evPerf['RangeFigures'] as Map<String, dynamic>? ?? {};
    final batteryList = evTech['BatteryDetailsList'] as List<dynamic>? ?? [];
    final firstBattery = batteryList.isNotEmpty
        ? batteryList.first as Map<String, dynamic>
        : <String, dynamic>{};

    return ModelDetailsData(
      make: id['Make']?.toString(),
      range: id['Range']?.toString(),
      model: id['Model']?.toString(),
      modelVariant: id['ModelVariant']?.toString(),
      series: id['Series']?.toString(),
      countryOfOrigin: id['CountryOfOrigin']?.toString(),
      bodyStyle: body['BodyStyle']?.toString(),
      numberOfDoors: body['NumberOfDoors'] as int?,
      numberOfSeats: body['NumberOfSeats'] as int?,
      fuelTankCapacityLitres: body['FuelTankCapacityLitres'] as int?,
      heightMm: dims['HeightMm'] as int?,
      lengthMm: dims['LengthMm'] as int?,
      widthMm: dims['WidthMm'] as int?,
      wheelbaseLengthMm: dims['WheelbaseLengthMm'] as int?,
      kerbWeightKg: weights['KerbWeightKg'] as int?,
      grossVehicleWeightKg: weights['GrossVehicleWeightKg'] as int?,
      unladenWeightKg: weights['UnladenWeightKg'] as int?,
      powertrainType: powertrain['PowertrainType']?.toString(),
      fuelType: powertrain['FuelType']?.toString(),
      engineDescription: ice['EngineDescription']?.toString(),
      aspiration: ice['Aspiration']?.toString(),
      cylinderArrangement: ice['CylinderArrangement']?.toString(),
      numberOfCylinders: ice['NumberOfCylinders'] as int?,
      engineCapacityCc: ice['EngineCapacityCc'] as int?,
      engineCapacityLitres: (ice['EngineCapacityLitres'] as num?)?.toDouble(),
      fuelDelivery: ice['FuelDelivery']?.toString(),
      transmissionType: transmission['TransmissionType']?.toString(),
      numberOfGears: transmission['NumberOfGears'] as int?,
      driveType: transmission['DriveType']?.toString(),
      bhp: (power['Bhp'] as num?)?.toDouble(),
      torqueNm: (torque['Nm'] as num?)?.toDouble(),
      zeroToSixtyMph: (stats['ZeroToSixtyMph'] as num?)?.toDouble(),
      maxSpeedMph: stats['MaxSpeedMph'] as int?,
      combinedMpg: (economy['CombinedMpg'] as num?)?.toDouble(),
      urbanColdMpg: (economy['UrbanColdMpg'] as num?)?.toDouble(),
      extraUrbanMpg: (economy['ExtraUrbanMpg'] as num?)?.toDouble(),
      euroStatus: emissions['EuroStatus']?.toString(),
      manufacturerCo2: emissions['ManufacturerCo2'] as int?,
      ncapStarRating: ncap['NcapStarRating'] as int?,
      ncapAdultPercent: ncap['NcapAdultPercent'] as int?,
      ncapChildPercent: ncap['NcapChildPercent'] as int?,
      batteryCapacityKwh: (firstBattery['TotalCapacityKwh'] as num?)?.toDouble(),
      batteryUsableKwh: (firstBattery['UsableCapacityKwh'] as num?)?.toDouble(),
      evRealRangeMiles: evRange['RealRangeMiles'] as int?,
      maxChargeInputPowerKw: evPerf['MaxChargeInputPowerKw'] as int?,
      warrantyMonths: warranty['ManufacturerWarrantyMonths'] as int?,
      warrantyMiles: warranty['ManufacturerWarrantyMiles'] as int?,
    );
  }

  factory ModelDetailsData.fromStoredJson(Map<String, dynamic> j) => ModelDetailsData(
    make: j['make'], range: j['range'], model: j['model'],
    modelVariant: j['model_variant'], series: j['series'],
    countryOfOrigin: j['country_of_origin'], bodyStyle: j['body_style'],
    numberOfDoors: j['number_of_doors'] as int?,
    numberOfSeats: j['number_of_seats'] as int?,
    fuelTankCapacityLitres: j['fuel_tank_capacity_litres'] as int?,
    heightMm: j['height_mm'] as int?, lengthMm: j['length_mm'] as int?,
    widthMm: j['width_mm'] as int?, wheelbaseLengthMm: j['wheelbase_length_mm'] as int?,
    kerbWeightKg: j['kerb_weight_kg'] as int?,
    grossVehicleWeightKg: j['gross_vehicle_weight_kg'] as int?,
    unladenWeightKg: j['unladen_weight_kg'] as int?,
    powertrainType: j['powertrain_type'], fuelType: j['fuel_type'],
    engineDescription: j['engine_description'], aspiration: j['aspiration'],
    cylinderArrangement: j['cylinder_arrangement'],
    numberOfCylinders: j['number_of_cylinders'] as int?,
    engineCapacityCc: j['engine_capacity_cc'] as int?,
    engineCapacityLitres: (j['engine_capacity_litres'] as num?)?.toDouble(),
    fuelDelivery: j['fuel_delivery'],
    transmissionType: j['transmission_type'],
    numberOfGears: j['number_of_gears'] as int?,
    driveType: j['drive_type'],
    bhp: (j['bhp'] as num?)?.toDouble(),
    torqueNm: (j['torque_nm'] as num?)?.toDouble(),
    zeroToSixtyMph: (j['zero_to_sixty_mph'] as num?)?.toDouble(),
    maxSpeedMph: j['max_speed_mph'] as int?,
    combinedMpg: (j['combined_mpg'] as num?)?.toDouble(),
    urbanColdMpg: (j['urban_cold_mpg'] as num?)?.toDouble(),
    extraUrbanMpg: (j['extra_urban_mpg'] as num?)?.toDouble(),
    euroStatus: j['euro_status'],
    manufacturerCo2: j['manufacturer_co2'] as int?,
    ncapStarRating: j['ncap_star_rating'] as int?,
    ncapAdultPercent: j['ncap_adult_percent'] as int?,
    ncapChildPercent: j['ncap_child_percent'] as int?,
    batteryCapacityKwh: (j['battery_capacity_kwh'] as num?)?.toDouble(),
    batteryUsableKwh: (j['battery_usable_kwh'] as num?)?.toDouble(),
    evRealRangeMiles: j['ev_real_range_miles'] as int?,
    maxChargeInputPowerKw: j['max_charge_input_power_kw'] as int?,
    warrantyMonths: j['warranty_months'] as int?,
    warrantyMiles: j['warranty_miles'] as int?,
  );

  Map<String, dynamic> toJson() => {
    'make': make, 'range': range, 'model': model,
    'model_variant': modelVariant, 'series': series,
    'country_of_origin': countryOfOrigin, 'body_style': bodyStyle,
    'number_of_doors': numberOfDoors, 'number_of_seats': numberOfSeats,
    'fuel_tank_capacity_litres': fuelTankCapacityLitres,
    'height_mm': heightMm, 'length_mm': lengthMm,
    'width_mm': widthMm, 'wheelbase_length_mm': wheelbaseLengthMm,
    'kerb_weight_kg': kerbWeightKg,
    'gross_vehicle_weight_kg': grossVehicleWeightKg,
    'unladen_weight_kg': unladenWeightKg,
    'powertrain_type': powertrainType, 'fuel_type': fuelType,
    'engine_description': engineDescription, 'aspiration': aspiration,
    'cylinder_arrangement': cylinderArrangement,
    'number_of_cylinders': numberOfCylinders,
    'engine_capacity_cc': engineCapacityCc,
    'engine_capacity_litres': engineCapacityLitres,
    'fuel_delivery': fuelDelivery,
    'transmission_type': transmissionType,
    'number_of_gears': numberOfGears, 'drive_type': driveType,
    'bhp': bhp, 'torque_nm': torqueNm,
    'zero_to_sixty_mph': zeroToSixtyMph, 'max_speed_mph': maxSpeedMph,
    'combined_mpg': combinedMpg, 'urban_cold_mpg': urbanColdMpg,
    'extra_urban_mpg': extraUrbanMpg,
    'euro_status': euroStatus, 'manufacturer_co2': manufacturerCo2,
    'ncap_star_rating': ncapStarRating,
    'ncap_adult_percent': ncapAdultPercent,
    'ncap_child_percent': ncapChildPercent,
    'battery_capacity_kwh': batteryCapacityKwh,
    'battery_usable_kwh': batteryUsableKwh,
    'ev_real_range_miles': evRealRangeMiles,
    'max_charge_input_power_kw': maxChargeInputPowerKw,
    'warranty_months': warrantyMonths, 'warranty_miles': warrantyMiles,
  };
}
