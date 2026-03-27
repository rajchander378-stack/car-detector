import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/saved_scan.dart';

class PdfExportService {
  Future<File> generate(List<SavedScan> scans) async {
    final pdf = pw.Document();

    for (final scan in scans) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _header(scan),
          build: (context) => _buildContent(scan),
        ),
      );
    }

    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final stamp = '${now.year}-${_pad(now.month)}-${_pad(now.day)}';
    final file = File('${dir.path}/autospotter_report_$stamp.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> share(File file) async {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'AutoSpotter Vehicle Report',
    );
  }

  pw.Widget _header(SavedScan scan) {
    final id = scan.identification;
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.blue800, width: 2)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('AutoSpotter Vehicle Report',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800)),
              pw.SizedBox(height: 4),
              pw.Text(id.displayName,
                  style: const pw.TextStyle(fontSize: 14)),
            ],
          ),
          if (id.numberPlate != null)
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                color: PdfColors.yellow200,
                border: pw.Border.all(),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                id.numberPlate!.toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5),
              ),
            ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildContent(SavedScan scan) {
    final widgets = <pw.Widget>[];
    final v = scan.valuation;
    final vd = scan.vehicleDetails;
    final mot = scan.motHistory;
    final md = scan.modelDetails;
    final td = scan.tyreDetails;

    // Metadata
    widgets.add(pw.SizedBox(height: 12));
    widgets.add(_infoRow('Saved', _formatDate(scan.savedAt)));
    if (scan.source == 'gemini_estimate') {
      widgets.add(_infoRow('Source', 'Approximate (AI estimate)'));
    }
    widgets.add(pw.SizedBox(height: 8));

    // Valuation section
    if (v != null) {
      widgets.add(_sectionTitle('Valuation'));
      if (v.vehicleDescription != null) {
        widgets.add(_infoRow('Description', v.vehicleDescription!));
      }
      if (v.dateOfFirstRegistration != null) {
        widgets.add(_infoRow('First Registered', v.dateOfFirstRegistration!));
      }
      if (v.valuationMileage != null) {
        widgets.add(_infoRow('Mileage', '${v.valuationMileage} miles'));
      }

      widgets.add(pw.SizedBox(height: 8));
      final priceRows = <List<String>>[];
      if (v.dealerForecourt != null) {
        priceRows.add(['Dealer Forecourt', _gbp(v.dealerForecourt!)]);
      }
      if (v.privateClean != null) {
        priceRows.add(['Private (Clean)', _gbp(v.privateClean!)]);
      }
      if (v.privateAverage != null) {
        priceRows.add(['Private (Average)', _gbp(v.privateAverage!)]);
      }
      if (v.tradeRetail != null) {
        priceRows.add(['Trade Retail', _gbp(v.tradeRetail!)]);
      }
      if (v.partExchange != null) {
        priceRows.add(['Part Exchange', _gbp(v.partExchange!)]);
      }
      if (v.auction != null) {
        priceRows.add(['Auction', _gbp(v.auction!)]);
      }
      if (v.tradeAverage != null) {
        priceRows.add(['Trade Average', _gbp(v.tradeAverage!)]);
      }
      if (v.tradePoor != null) {
        priceRows.add(['Trade Poor', _gbp(v.tradePoor!)]);
      }
      if (v.onTheRoad != null) {
        priceRows.add(['On The Road', _gbp(v.onTheRoad!)]);
      }

      if (priceRows.isNotEmpty) {
        widgets.add(pw.TableHelper.fromTextArray(
          headers: ['Price Type', 'Value'],
          data: priceRows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        ));
      }
    }

    // Vehicle details section
    if (vd != null) {
      widgets.add(_sectionTitle('Vehicle Details'));
      if (vd.vin != null) widgets.add(_infoRow('VIN', vd.vin!));
      if (vd.dvlaFuelType != null) widgets.add(_infoRow('Fuel', vd.dvlaFuelType!));
      if (vd.engineCapacityCc != null) {
        widgets.add(_infoRow('Engine', '${vd.engineCapacityCc} cc'));
      }
      widgets.add(_infoRow('Previous Keepers', '${vd.numberOfPreviousKeepers}'));
      if (vd.dvlaCo2 != null) widgets.add(_infoRow('CO2', '${vd.dvlaCo2} g/km'));
      if (vd.isImported) widgets.add(_infoRow('Imported', 'Yes'));
      if (vd.isScrapped) widgets.add(_infoRow('Scrapped', 'Yes'));
    }

    // Model details / specs
    if (md != null) {
      widgets.add(_sectionTitle('Specifications'));
      if (md.transmissionType != null) {
        widgets.add(_infoRow('Transmission', md.transmissionType!));
      }
      if (md.driveType != null) widgets.add(_infoRow('Drive', md.driveType!));
      if (md.zeroToSixtyMph != null) {
        widgets.add(_infoRow('0-60 mph', '${md.zeroToSixtyMph!.toStringAsFixed(1)}s'));
      }
      if (md.maxSpeedMph != null) {
        widgets.add(_infoRow('Top Speed', '${md.maxSpeedMph} mph'));
      }
      if (md.combinedMpg != null) {
        widgets.add(_infoRow('Combined MPG', md.combinedMpg!.toStringAsFixed(1)));
      }
      if (md.ncapStarRating != null) {
        widgets.add(_infoRow('NCAP Stars', '${md.ncapStarRating}'));
      }
      if (md.kerbWeightKg != null) {
        widgets.add(_infoRow('Kerb Weight', '${md.kerbWeightKg} kg'));
      }
    }

    // Tyres
    if (td != null && td.standardFitment != null) {
      widgets.add(_sectionTitle('Tyres'));
      if (td.standardFitment!.front != null) {
        widgets.add(_infoRow(
            'Front', td.standardFitment!.front!.sizeDescription ?? 'N/A'));
      }
      if (td.standardFitment!.rear != null) {
        widgets.add(_infoRow(
            'Rear', td.standardFitment!.rear!.sizeDescription ?? 'N/A'));
      }
    }

    // MOT history
    if (mot != null) {
      widgets.add(_sectionTitle('MOT History'));
      if (mot.motDueDate != null) widgets.add(_infoRow('Due Date', mot.motDueDate!));
      widgets.add(_infoRow('Passes', '${mot.totalPasses}'));
      widgets.add(_infoRow('Failures', '${mot.totalFailures}'));

      if (mot.tests.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        final testData = mot.tests.take(10).map((t) => [
              t.testDate ?? '',
              t.passed ? 'Pass' : 'Fail',
              t.mileageDisplay,
            ]).toList();

        widgets.add(pw.TableHelper.fromTextArray(
          headers: ['Date', 'Result', 'Mileage'],
          data: testData,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ));
      }
    }

    return widgets;
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900)),
    );
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700)),
          ),
          pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  String _gbp(int value) {
    return '\u00A3${_formatNumber(value)}';
  }

  String _formatNumber(int n) {
    final str = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  String _formatDate(DateTime date) =>
      '${_pad(date.day)}/${_pad(date.month)}/${date.year}';

  String _pad(int n) => n.toString().padLeft(2, '0');
}
