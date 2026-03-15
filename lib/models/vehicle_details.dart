/// Vehicle identification, status, history and technical details
/// from the UKVD VehicleDetails data block.
class VehicleDetailsData {
  // Identification
  final String? vrm;
  final String? vin;
  final String? vinLast5;
  final String? dvlaMake;
  final String? dvlaModel;
  final String? dvlaBodyType;
  final String? dvlaFuelType;
  final String? dateFirstRegistered;
  final String? dateFirstRegisteredInUk;
  final String? dateOfManufacture;
  final int? yearOfManufacture;
  final String? engineNumber;

  // Status
  final bool isImported;
  final bool isExported;
  final bool isScrapped;
  final String? dateImported;
  final String? dateExported;
  final String? dateScrapped;
  final bool certificateOfDestructionIssued;

  // History
  final String? currentColour;
  final String? originalColour;
  final String? previousColour;
  final int? numberOfColourChanges;
  final List<KeeperChange> keeperChanges;
  final List<String> v5cIssueDates;

  // Technical
  final int? numberOfSeats;
  final int? engineCapacityCc;
  final int? grossWeightKg;
  final int? maxNetPowerKw;

  // Tax / VED
  final int? dvlaCo2;
  final String? dvlaCo2Band;
  final double? vedStandard12Months;
  final double? vedFirstYear12Months;

  VehicleDetailsData({
    this.vrm,
    this.vin,
    this.vinLast5,
    this.dvlaMake,
    this.dvlaModel,
    this.dvlaBodyType,
    this.dvlaFuelType,
    this.dateFirstRegistered,
    this.dateFirstRegisteredInUk,
    this.dateOfManufacture,
    this.yearOfManufacture,
    this.engineNumber,
    this.isImported = false,
    this.isExported = false,
    this.isScrapped = false,
    this.dateImported,
    this.dateExported,
    this.dateScrapped,
    this.certificateOfDestructionIssued = false,
    this.currentColour,
    this.originalColour,
    this.previousColour,
    this.numberOfColourChanges,
    this.keeperChanges = const [],
    this.v5cIssueDates = const [],
    this.numberOfSeats,
    this.engineCapacityCc,
    this.grossWeightKg,
    this.maxNetPowerKw,
    this.dvlaCo2,
    this.dvlaCo2Band,
    this.vedStandard12Months,
    this.vedFirstYear12Months,
  });

  int get numberOfPreviousKeepers {
    if (keeperChanges.isEmpty) return 0;
    return keeperChanges.first.numberOfPreviousKeepers ?? 0;
  }

  bool get hasWarnings => isImported || isExported || isScrapped || certificateOfDestructionIssued;

  factory VehicleDetailsData.fromApiJson(Map<String, dynamic> json) {
    final id = json['VehicleIdentification'] as Map<String, dynamic>? ?? {};
    final status = json['VehicleStatus'] as Map<String, dynamic>? ?? {};
    final history = json['VehicleHistory'] as Map<String, dynamic>? ?? {};
    final tech = json['DvlaTechnicalDetails'] as Map<String, dynamic>? ?? {};
    final colour = history['ColourDetails'] as Map<String, dynamic>? ?? {};
    final ved = status['VehicleExciseDutyDetails'] as Map<String, dynamic>? ?? {};
    final vedRate = ved['VedRate'] as Map<String, dynamic>? ?? {};
    final vedStandard = vedRate['Standard'] as Map<String, dynamic>? ?? {};
    final vedFirstYear = vedRate['FirstYear'] as Map<String, dynamic>? ?? {};

    final keeperList = history['KeeperChangeList'] as List<dynamic>? ?? [];
    final v5cList = history['V5cCertificateList'] as List<dynamic>? ?? [];

    return VehicleDetailsData(
      vrm: id['Vrm']?.toString(),
      vin: id['Vin']?.toString(),
      vinLast5: id['VinLast5']?.toString(),
      dvlaMake: id['DvlaMake']?.toString(),
      dvlaModel: id['DvlaModel']?.toString(),
      dvlaBodyType: id['DvlaBodyType']?.toString(),
      dvlaFuelType: id['DvlaFuelType']?.toString(),
      dateFirstRegistered: id['DateFirstRegistered']?.toString(),
      dateFirstRegisteredInUk: id['DateFirstRegisteredInUk']?.toString(),
      dateOfManufacture: id['DateOfManufacture']?.toString(),
      yearOfManufacture: id['YearOfManufacture'] as int?,
      engineNumber: id['EngineNumber']?.toString(),
      isImported: status['IsImported'] as bool? ?? false,
      isExported: status['IsExported'] as bool? ?? false,
      isScrapped: status['IsScrapped'] as bool? ?? false,
      dateImported: status['DateImported']?.toString(),
      dateExported: status['DateExported']?.toString(),
      dateScrapped: status['DateScrapped']?.toString(),
      certificateOfDestructionIssued: status['CertificateOfDestructionIssued'] as bool? ?? false,
      currentColour: colour['CurrentColour']?.toString(),
      originalColour: colour['OriginalColour']?.toString(),
      previousColour: colour['PreviousColour']?.toString(),
      numberOfColourChanges: colour['NumberOfColourChanges'] as int?,
      keeperChanges: keeperList.map((k) => KeeperChange.fromApiJson(k as Map<String, dynamic>)).toList(),
      v5cIssueDates: v5cList
          .map((v) => (v as Map<String, dynamic>)['IssueDate']?.toString())
          .where((d) => d != null)
          .cast<String>()
          .toList(),
      numberOfSeats: tech['NumberOfSeats'] as int?,
      engineCapacityCc: tech['EngineCapacityCc'] as int?,
      grossWeightKg: tech['GrossWeightKg'] as int?,
      maxNetPowerKw: tech['MaxNetPowerKw'] as int?,
      dvlaCo2: ved['DvlaCo2'] as int?,
      dvlaCo2Band: ved['DvlaCo2Band']?.toString(),
      vedStandard12Months: (vedStandard['TwelveMonths'] as num?)?.toDouble(),
      vedFirstYear12Months: (vedFirstYear['TwelveMonths'] as num?)?.toDouble(),
    );
  }

  factory VehicleDetailsData.fromStoredJson(Map<String, dynamic> json) {
    final keeperList = json['keeper_changes'] as List<dynamic>? ?? [];
    final v5cList = json['v5c_issue_dates'] as List<dynamic>? ?? [];

    return VehicleDetailsData(
      vrm: json['vrm'],
      vin: json['vin'],
      vinLast5: json['vin_last5'],
      dvlaMake: json['dvla_make'],
      dvlaModel: json['dvla_model'],
      dvlaBodyType: json['dvla_body_type'],
      dvlaFuelType: json['dvla_fuel_type'],
      dateFirstRegistered: json['date_first_registered'],
      dateFirstRegisteredInUk: json['date_first_registered_in_uk'],
      dateOfManufacture: json['date_of_manufacture'],
      yearOfManufacture: json['year_of_manufacture'] as int?,
      engineNumber: json['engine_number'],
      isImported: json['is_imported'] as bool? ?? false,
      isExported: json['is_exported'] as bool? ?? false,
      isScrapped: json['is_scrapped'] as bool? ?? false,
      dateImported: json['date_imported'],
      dateExported: json['date_exported'],
      dateScrapped: json['date_scrapped'],
      certificateOfDestructionIssued: json['certificate_of_destruction_issued'] as bool? ?? false,
      currentColour: json['current_colour'],
      originalColour: json['original_colour'],
      previousColour: json['previous_colour'],
      numberOfColourChanges: json['number_of_colour_changes'] as int?,
      keeperChanges: keeperList.map((k) => KeeperChange.fromStoredJson(k as Map<String, dynamic>)).toList(),
      v5cIssueDates: List<String>.from(v5cList),
      numberOfSeats: json['number_of_seats'] as int?,
      engineCapacityCc: json['engine_capacity_cc'] as int?,
      grossWeightKg: json['gross_weight_kg'] as int?,
      maxNetPowerKw: json['max_net_power_kw'] as int?,
      dvlaCo2: json['dvla_co2'] as int?,
      dvlaCo2Band: json['dvla_co2_band'],
      vedStandard12Months: (json['ved_standard_12_months'] as num?)?.toDouble(),
      vedFirstYear12Months: (json['ved_first_year_12_months'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'vrm': vrm,
    'vin': vin,
    'vin_last5': vinLast5,
    'dvla_make': dvlaMake,
    'dvla_model': dvlaModel,
    'dvla_body_type': dvlaBodyType,
    'dvla_fuel_type': dvlaFuelType,
    'date_first_registered': dateFirstRegistered,
    'date_first_registered_in_uk': dateFirstRegisteredInUk,
    'date_of_manufacture': dateOfManufacture,
    'year_of_manufacture': yearOfManufacture,
    'engine_number': engineNumber,
    'is_imported': isImported,
    'is_exported': isExported,
    'is_scrapped': isScrapped,
    'date_imported': dateImported,
    'date_exported': dateExported,
    'date_scrapped': dateScrapped,
    'certificate_of_destruction_issued': certificateOfDestructionIssued,
    'current_colour': currentColour,
    'original_colour': originalColour,
    'previous_colour': previousColour,
    'number_of_colour_changes': numberOfColourChanges,
    'keeper_changes': keeperChanges.map((k) => k.toJson()).toList(),
    'v5c_issue_dates': v5cIssueDates,
    'number_of_seats': numberOfSeats,
    'engine_capacity_cc': engineCapacityCc,
    'gross_weight_kg': grossWeightKg,
    'max_net_power_kw': maxNetPowerKw,
    'dvla_co2': dvlaCo2,
    'dvla_co2_band': dvlaCo2Band,
    'ved_standard_12_months': vedStandard12Months,
    'ved_first_year_12_months': vedFirstYear12Months,
  };
}

class KeeperChange {
  final int? numberOfPreviousKeepers;
  final String? keeperStartDate;
  final String? previousKeeperDisposalDate;

  KeeperChange({
    this.numberOfPreviousKeepers,
    this.keeperStartDate,
    this.previousKeeperDisposalDate,
  });

  factory KeeperChange.fromApiJson(Map<String, dynamic> json) => KeeperChange(
    numberOfPreviousKeepers: json['NumberOfPreviousKeepers'] as int?,
    keeperStartDate: json['KeeperStartDate']?.toString(),
    previousKeeperDisposalDate: json['PreviousKeeperDisposalDate']?.toString(),
  );

  factory KeeperChange.fromStoredJson(Map<String, dynamic> json) => KeeperChange(
    numberOfPreviousKeepers: json['number_of_previous_keepers'] as int?,
    keeperStartDate: json['keeper_start_date'],
    previousKeeperDisposalDate: json['previous_keeper_disposal_date'],
  );

  Map<String, dynamic> toJson() => {
    'number_of_previous_keepers': numberOfPreviousKeepers,
    'keeper_start_date': keeperStartDate,
    'previous_keeper_disposal_date': previousKeeperDisposalDate,
  };
}
