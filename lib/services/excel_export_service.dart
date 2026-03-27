import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../models/saved_scan.dart';

class ExcelExportService {
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
    'Source',
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
    'VIN',
    'Fuel Type',
    'Engine CC',
    'Previous Keepers',
    'Road Tax (12m)',
    'CO2 (g/km)',
    'Imported',
    'Scrapped',
    'MOT Due',
    'MOT Passes',
    'MOT Failures',
    'Last MOT Result',
    'Last MOT Mileage',
    'Transmission',
    'Drive Type',
    '0-60 mph (s)',
    'Top Speed (mph)',
    'Combined MPG',
    'NCAP Stars',
    'Kerb Weight (kg)',
    'Front Tyre',
    'Rear Tyre',
    'Favourite',
  ];

  Future<File> generate(List<SavedScan> scans) async {
    final workbook = Workbook();
    final sheet = workbook.worksheets[0];
    sheet.name = 'Vehicles';

    // Header row with bold styling
    for (var i = 0; i < _headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(_headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#1565C0';
      cell.cellStyle.fontColor = '#FFFFFF';
    }

    // Data rows
    for (var r = 0; r < scans.length; r++) {
      final values = _row(scans[r]);
      for (var c = 0; c < values.length; c++) {
        final cell = sheet.getRangeByIndex(r + 2, c + 1);
        final val = values[c];
        if (val is int) {
          cell.setNumber(val.toDouble());
        } else if (val is double) {
          cell.setNumber(val);
        } else {
          cell.setText(val.toString());
        }
      }
    }

    // Auto-fit columns (approximate)
    for (var i = 1; i <= _headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    final bytes = workbook.saveAsStream();
    workbook.dispose();

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp = '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
    final file = File('${dir.path}/autospotter_export_$stamp.xlsx');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> share(File file) async {
    await Share.shareXFiles(
      [XFile(file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
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
    final lastTest =
        mot != null && mot.tests.isNotEmpty ? mot.tests.first : null;

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
      scan.source ?? 'vdgl',
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
      mot?.motDueDate ?? '',
      mot?.totalPasses ?? '',
      mot?.totalFailures ?? '',
      lastTest != null ? (lastTest.passed ? 'Pass' : 'Fail') : '',
      lastTest?.mileageDisplay ?? '',
      md?.transmissionType ?? '',
      md?.driveType ?? '',
      md?.zeroToSixtyMph?.toStringAsFixed(1) ?? '',
      md?.maxSpeedMph ?? '',
      md?.combinedMpg?.toStringAsFixed(1) ?? '',
      md?.ncapStarRating ?? '',
      md?.kerbWeightKg ?? '',
      td?.standardFitment?.front?.sizeDescription ?? '',
      td?.standardFitment?.rear?.sizeDescription ?? '',
      scan.isFavourite ? 'Yes' : 'No',
    ];
  }

  String _formatDate(DateTime date) =>
      '${_pad(date.day)}/${_pad(date.month)}/${date.year}';

  String _pad(int n) => n.toString().padLeft(2, '0');
}
