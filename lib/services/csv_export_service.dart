import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/saved_scan.dart';

class CsvExportService {
  static const _headers = [
    'Date Saved',
    'Make',
    'Model',
    'Year (Min)',
    'Year (Max)',
    'Generation',
    'Trim',
    'Body Style',
    'Colour',
    'Number Plate',
    'Confidence (%)',
    'Features',
    'Notes',
    'Vehicle Description',
    'First Registered',
    'Mileage',
    'On The Road',
    'Dealer Forecourt',
    'Trade Retail',
    'Private Clean',
    'Private Average',
    'Part Exchange',
    'Auction',
    'Trade Average',
    'Trade Poor',
    // Vehicle Details
    'VIN',
    'Fuel Type',
    'Engine CC',
    'Previous Keepers',
    'Road Tax (12m)',
    'CO2 (g/km)',
    'Imported',
    'Scrapped',
    // MOT
    'MOT Due',
    'MOT Passes',
    'MOT Failures',
    'Last MOT Result',
    'Last MOT Mileage',
    // Specs
    'Transmission',
    'Drive Type',
    '0-60 mph (s)',
    'Top Speed (mph)',
    'Combined MPG',
    'NCAP Stars',
    'Kerb Weight (kg)',
    // Tyres
    'Front Tyre',
    'Rear Tyre',
    'Favourite',
  ];

  Future<File> generate(List<SavedScan> scans) async {
    final rows = <List<dynamic>>[
      _headers,
      for (final scan in scans) _row(scan),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp =
        '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
    final file = File('${dir.path}/autospotter_export_$stamp.csv');
    await file.writeAsString(csv);
    return file;
  }

  Future<void> share(File file) async {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'AutoSpotter Vehicle Export',
    );
  }

  List<dynamic> _row(SavedScan scan) {
    final id = scan.identification;
    final v = scan.valuation;
    final vd = scan.vehicleDetails;
    final mot = scan.motHistory;
    final md = scan.modelDetails;
    final td = scan.tyreDetails;
    final lastTest = mot != null && mot.tests.isNotEmpty ? mot.tests.first : null;

    return [
      _formatDate(scan.savedAt),
      id.make ?? '',
      id.model ?? '',
      id.yearMin ?? '',
      id.yearMax ?? '',
      id.generation ?? '',
      id.trim ?? '',
      id.bodyStyle ?? '',
      id.colour ?? '',
      id.numberPlate ?? '',
      (id.confidence * 100).round(),
      id.distinguishingFeatures.join('; '),
      id.notes ?? '',
      v?.vehicleDescription ?? '',
      v?.dateOfFirstRegistration ?? '',
      v?.valuationMileage ?? '',
      v?.onTheRoad ?? '',
      v?.dealerForecourt ?? '',
      v?.tradeRetail ?? '',
      v?.privateClean ?? '',
      v?.privateAverage ?? '',
      v?.partExchange ?? '',
      v?.auction ?? '',
      v?.tradeAverage ?? '',
      v?.tradePoor ?? '',
      // Vehicle Details
      vd?.vin ?? '',
      vd?.dvlaFuelType ?? '',
      vd?.engineCapacityCc ?? '',
      vd?.numberOfPreviousKeepers ?? '',
      vd?.vedStandard12Months != null
          ? vd!.vedStandard12Months!.toStringAsFixed(0)
          : '',
      vd?.dvlaCo2 ?? '',
      vd != null && vd.isImported ? 'Yes' : '',
      vd != null && vd.isScrapped ? 'Yes' : '',
      // MOT
      mot?.motDueDate ?? '',
      mot?.totalPasses ?? '',
      mot?.totalFailures ?? '',
      lastTest != null ? (lastTest.passed ? 'Pass' : 'Fail') : '',
      lastTest?.mileageDisplay ?? '',
      // Specs
      md?.transmissionType ?? '',
      md?.driveType ?? '',
      md?.zeroToSixtyMph?.toStringAsFixed(1) ?? '',
      md?.maxSpeedMph ?? '',
      md?.combinedMpg?.toStringAsFixed(1) ?? '',
      md?.ncapStarRating ?? '',
      md?.kerbWeightKg ?? '',
      // Tyres
      td?.standardFitment?.front?.sizeDescription ?? '',
      td?.standardFitment?.rear?.sizeDescription ?? '',
      scan.isFavourite ? 'Yes' : 'No',
    ];
  }

  String _formatDate(DateTime date) =>
      '${_pad(date.day)}/${_pad(date.month)}/${date.year}';

  String _pad(int n) => n.toString().padLeft(2, '0');
}
