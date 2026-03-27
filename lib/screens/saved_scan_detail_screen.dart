import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/mot_history.dart';
import '../models/saved_scan.dart';
import '../models/vehicle_valuation.dart';
import '../services/saved_scan_service.dart';

class SavedScanDetailScreen extends StatefulWidget {
  final SavedScan scan;
  final String uid;

  const SavedScanDetailScreen({
    super.key,
    required this.scan,
    required this.uid,
  });

  @override
  State<SavedScanDetailScreen> createState() => _SavedScanDetailScreenState();
}

class _SavedScanDetailScreenState extends State<SavedScanDetailScreen> {
  late bool _isFavourite;
  final _service = SavedScanService();

  @override
  void initState() {
    super.initState();
    _isFavourite = widget.scan.isFavourite;
  }

  Future<void> _toggleFavourite() async {
    final newValue = !_isFavourite;
    setState(() => _isFavourite = newValue);
    try {
      await _service.toggleFavourite(widget.uid, widget.scan.id, newValue);
    } catch (e) {
      if (mounted) {
        setState(() => _isFavourite = !newValue);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favourite.')),
        );
      }
    }
  }

  Future<void> _deleteScan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Scan'),
        content: const Text('Remove this saved scan? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteScan(widget.uid, widget.scan.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete scan.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.scan.identification;
    final valuation = widget.scan.valuation;
    final pct = (id.confidence * 100).toStringAsFixed(0);
    final hasPlate = id.numberPlate != null && id.numberPlate!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Report'),
        actions: [
          IconButton(
            icon: Icon(
              _isFavourite ? Icons.star : Icons.star_border,
              color: _isFavourite ? Colors.amber[600] : null,
            ),
            tooltip: _isFavourite ? 'Remove from favourites' : 'Add to favourites',
            onPressed: _toggleFavourite,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete scan',
            onPressed: _deleteScan,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle name and confidence
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    id.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: _ConfidenceGauge(
                    value: id.confidence,
                    label: '$pct%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Number plate
            if (hasPlate) ...[
              _UkPlate(registration: id.numberPlate!),
              const SizedBox(height: 12),
            ],

            // Spec chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (id.colour != null)
                  _specChip(Icons.palette_outlined, id.colour!),
                if (id.bodyStyle != null)
                  _specChip(Icons.directions_car_outlined, id.bodyStyle!),
                if (id.generation != null)
                  _specChip(Icons.history, id.generation!),
                if (id.trim != null)
                  _specChip(Icons.auto_awesome_outlined, id.trim!),
              ],
            ),

            if (id.distinguishingFeatures.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Features',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              ...id.distinguishingFeatures.map((f) => Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('\u2022 ',
                            style: TextStyle(fontSize: 14)),
                        Expanded(
                            child:
                                Text(f, style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  )),
            ],

            if (id.notes != null) ...[
              const SizedBox(height: 10),
              Text(
                id.notes!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],

            // Valuation card
            if (valuation != null) ...[
              const SizedBox(height: 18),
              if (widget.scan.source == 'gemini_estimate')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Approximate values — estimated by AI when live pricing was unavailable.',
                            style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              _buildValuation(valuation, approximate: widget.scan.source == 'gemini_estimate'),
              if (widget.scan.isExpired)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.orange[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This valuation is over ${SavedScan.retentionDays} days old and may no longer be accurate.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // Vehicle Details section
            if (widget.scan.vehicleDetails != null)
              _buildVehicleDetailsSection(),

            // MOT History section
            if (widget.scan.motHistory != null)
              _buildMotSection(),

            // Specs section
            if (widget.scan.modelDetails != null)
              _buildSpecsSection(),

            // Tyre section
            if (widget.scan.tyreDetails != null)
              _buildTyreSection(),

            // Saved date
            const SizedBox(height: 18),
            Text(
              'Saved on ${_formatFullDate(widget.scan.savedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildValuation(VehicleValuation valuation, {bool approximate = false}) {
    final baseColor = approximate ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor[50]!, baseColor[100]!],
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            approximate ? '~${valuation.displayPrice}' : valuation.displayPrice,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            approximate ? 'Approximate UK valuation' : 'Estimated UK valuation',
            style: TextStyle(fontSize: 12, color: baseColor[700]),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (valuation.dealerForecourt != null)
                Expanded(
                    child: _priceTier(
                  'Dealer',
                  VehicleValuation.formatGbp(valuation.dealerForecourt!),
                )),
              if (valuation.privateAverage != null)
                Expanded(
                    child: _priceTier(
                  'Private',
                  VehicleValuation.formatGbp(valuation.privateAverage!),
                )),
              if (valuation.tradeRetail != null)
                Expanded(
                    child: _priceTier(
                  'Trade',
                  VehicleValuation.formatGbp(valuation.tradeRetail!),
                )),
            ],
          ),
          if (valuation.valuationMileage != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.speed, size: 16, color: baseColor[700]),
                const SizedBox(width: 6),
                Text(
                  '${valuation.valuationMileage} miles',
                  style: TextStyle(fontSize: 13, color: baseColor[800]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceTier(String label, String price) {
    return Column(
      children: [
        Text(
          price,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.green[600]),
        ),
      ],
    );
  }

  Widget _reportSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(title,
            style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _warningChip(String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 14, color: Colors.red[700]),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.red[700],
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailsSection() {
    final vd = widget.scan.vehicleDetails!;
    return _reportSection(
      title: 'Vehicle Details',
      icon: Icons.info_outline,
      color: Colors.blue,
      children: [
        _infoRow('VRM', vd.vrm),
        _infoRow('VIN', vd.vin),
        _infoRow('Make', vd.dvlaMake),
        _infoRow('Model', vd.dvlaModel),
        _infoRow('Fuel Type', vd.dvlaFuelType),
        _infoRow('Body Type', vd.dvlaBodyType),
        _infoRow('Colour', vd.currentColour),
        if (vd.yearOfManufacture != null)
          _infoRow('Year', vd.yearOfManufacture.toString()),
        _infoRow('First Registered', _formatApiDate(vd.dateFirstRegistered)),
        if (vd.engineCapacityCc != null)
          _infoRow('Engine', '${vd.engineCapacityCc} cc'),
        _infoRow('Keepers', vd.numberOfPreviousKeepers.toString()),
        if (vd.vedStandard12Months != null)
          _infoRow('Road Tax (12m)',
              '\u00a3${vd.vedStandard12Months!.toStringAsFixed(0)}'),
        if (vd.dvlaCo2 != null)
          _infoRow('CO2', '${vd.dvlaCo2} g/km'),
        if (vd.hasWarnings) ...[
          const SizedBox(height: 6),
          if (vd.isImported) _warningChip('Imported'),
          if (vd.isExported) _warningChip('Exported'),
          if (vd.isScrapped) _warningChip('Scrapped'),
        ],
      ],
    );
  }

  Widget _buildMotSection() {
    final mot = widget.scan.motHistory!;
    return _reportSection(
      title: 'MOT History',
      icon: Icons.verified_user_outlined,
      color: mot.isOverdue ? Colors.red : Colors.teal,
      children: [
        if (mot.motDueDate != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: mot.isOverdue ? Colors.red[50] : Colors.teal[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  mot.isOverdue ? Icons.warning : Icons.check_circle,
                  size: 18,
                  color: mot.isOverdue ? Colors.red[700] : Colors.teal[700],
                ),
                const SizedBox(width: 8),
                Text(
                  'MOT due: ${_formatApiDate(mot.motDueDate)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: mot.isOverdue ? Colors.red[700] : Colors.teal[700],
                  ),
                ),
              ],
            ),
          ),
        Text('${mot.totalPasses} passes, ${mot.totalFailures} failures',
            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 8),
        ...mot.tests.take(10).map((test) => _buildMotTestRow(test)),
      ],
    );
  }

  Widget _buildMotTestRow(MotTest test) {
    final advisories = test.defects.where((d) => d.isAdvisory).length;
    final failures = test.defects.where((d) => d.isFailure).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: test.passed ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: test.passed ? Colors.green[200]! : Colors.red[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                test.passed ? Icons.check_circle : Icons.cancel,
                size: 16,
                color: test.passed ? Colors.green[700] : Colors.red[700],
              ),
              const SizedBox(width: 6),
              Text(
                test.passed ? 'PASS' : 'FAIL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: test.passed ? Colors.green[700] : Colors.red[700],
                ),
              ),
              const Spacer(),
              Text(_formatApiDate(test.testDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 22),
              Text(test.mileageDisplay,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              if (advisories > 0) ...[
                const SizedBox(width: 12),
                Text('$advisories advisory${advisories == 1 ? '' : 'ies'}',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700])),
              ],
              if (failures > 0) ...[
                const SizedBox(width: 12),
                Text('$failures failure${failures == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: Colors.red[700])),
              ],
            ],
          ),
          if (!test.passed && test.defects.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...test.defects.where((d) => d.isFailure).take(5).map(
              (d) => Padding(
                padding: const EdgeInsets.only(left: 22, top: 2),
                child: Text('\u2022 ${d.text ?? ""}',
                    style: TextStyle(fontSize: 11, color: Colors.red[600])),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecsSection() {
    final md = widget.scan.modelDetails!;
    return _reportSection(
      title: 'Specifications',
      icon: Icons.build_outlined,
      color: Colors.indigo,
      children: [
        _infoRow('Make / Model', '${md.make ?? ""} ${md.model ?? ""}'.trim()),
        if (md.bodyStyle != null)
          _infoRow('Body', '${md.bodyStyle}${md.numberOfDoors != null ? ', ${md.numberOfDoors} door' : ''}'),
        if (md.numberOfSeats != null)
          _infoRow('Seats', md.numberOfSeats.toString()),
        _infoRow('Engine', md.engineSummary),
        _infoRow('Transmission',
            md.transmissionType != null
                ? '${md.transmissionType}${md.numberOfGears != null ? ', ${md.numberOfGears} speed' : ''}'
                : null),
        _infoRow('Drive', md.driveType),
        if (md.zeroToSixtyMph != null)
          _infoRow('0-60 mph', '${md.zeroToSixtyMph!.toStringAsFixed(1)}s'),
        if (md.maxSpeedMph != null)
          _infoRow('Top Speed', '${md.maxSpeedMph} mph'),
        if (md.combinedMpg != null)
          _infoRow('Fuel Economy', '${md.combinedMpg!.toStringAsFixed(1)} mpg combined'),
        if (md.manufacturerCo2 != null)
          _infoRow('CO2', '${md.manufacturerCo2} g/km'),
        _infoRow('Euro Status', md.euroStatus),
        if (md.ncapStarRating != null)
          _infoRow('NCAP Rating', '${'★' * md.ncapStarRating!}${'☆' * (5 - md.ncapStarRating!)}'),
        if (md.kerbWeightKg != null)
          _infoRow('Kerb Weight', '${md.kerbWeightKg} kg'),
        if (md.lengthMm != null)
          _infoRow('Dimensions',
              '${md.lengthMm}L x ${md.widthMm ?? "?"}W x ${md.heightMm ?? "?"}H mm'),
        _infoRow('Country', md.countryOfOrigin),
        if (md.isEv) ...[
          const SizedBox(height: 6),
          const Text('EV Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (md.batteryCapacityKwh != null)
            _infoRow('Battery', '${md.batteryCapacityKwh} kWh (${md.batteryUsableKwh ?? "?"} usable)'),
          if (md.evRealRangeMiles != null)
            _infoRow('Real Range', '${md.evRealRangeMiles} miles'),
          if (md.maxChargeInputPowerKw != null)
            _infoRow('Max Charge', '${md.maxChargeInputPowerKw} kW'),
        ],
      ],
    );
  }

  Widget _buildTyreSection() {
    final td = widget.scan.tyreDetails!;
    final fitment = td.standardFitment;
    if (fitment == null) return const SizedBox.shrink();

    return _reportSection(
      title: 'Tyres & Wheels',
      icon: Icons.tire_repair,
      color: Colors.brown,
      children: [
        if (fitment.front != null) ...[
          const Text('Front',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          _infoRow('Size', fitment.front!.sizeDescription),
          if (fitment.front!.pressurePsi != null)
            _infoRow('Pressure', '${fitment.front!.pressurePsi} PSI'),
          _infoRow('Run Flat', fitment.front!.isRunFlat ? 'Yes' : 'No'),
        ],
        if (fitment.rear != null) ...[
          const SizedBox(height: 6),
          const Text('Rear',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          _infoRow('Size', fitment.rear!.sizeDescription),
          if (fitment.rear!.pressurePsi != null)
            _infoRow('Pressure', '${fitment.rear!.pressurePsi} PSI'),
          _infoRow('Run Flat', fitment.rear!.isRunFlat ? 'Yes' : 'No'),
        ],
        if (fitment.hubPcd != null)
          _infoRow('PCD', fitment.hubPcd),
        if (fitment.fixingTorqueNm != null)
          _infoRow('Wheel Torque', '${fitment.fixingTorqueNm} Nm'),
      ],
    );
  }

  String _formatApiDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatFullDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// Reused widgets (same as results_screen.dart)

class _ConfidenceGauge extends StatelessWidget {
  final double value;
  final String label;

  const _ConfidenceGauge({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = value > 0.8
        ? Colors.green
        : value > 0.6
            ? Colors.orange
            : Colors.red;

    return CustomPaint(
      painter: _GaugePainter(value: value, color: color),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value;
  final Color color;

  _GaugePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      Paint()
        ..color = Colors.grey[300]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75,
      math.pi * 1.5 * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      value != oldDelegate.value || color != oldDelegate.color;
}

class _UkPlate extends StatelessWidget {
  final String registration;

  const _UkPlate({required this.registration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2C10F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Text(
        registration.toUpperCase(),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: Colors.black,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
