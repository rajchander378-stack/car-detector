import 'package:flutter/material.dart';
import '../models/garage_vehicle.dart';
import '../models/mot_history.dart';
import '../models/vehicle_valuation.dart';
import '../services/garage_service.dart';

class GarageDetailScreen extends StatelessWidget {
  final GarageVehicle vehicle;
  final String uid;

  const GarageDetailScreen({
    super.key,
    required this.vehicle,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final id = vehicle.identification;
    final val = vehicle.valuation;
    final hasPlate = vehicle.plate != null && vehicle.plate!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove from garage',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle name
            Text(
              vehicle.displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Plate
            if (hasPlate) ...[
              _UkPlate(registration: vehicle.plate!),
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

            // Freshness badges
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _freshnessBadge(
                  'Valuation',
                  vehicle.valuationUpdated ?? vehicle.addedAt,
                  const Duration(days: 7),
                  const Duration(days: 30),
                ),
                if (vehicle.motHistory?.motDueDate != null)
                  _motFreshnessBadge(vehicle.motHistory!.motDueDate!),
              ],
            ),

            // Source indicator
            if (vehicle.source == 'gemini_estimate') ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Approximate values — estimated by AI when live pricing was unavailable.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Valuation
            if (val != null && val.hasData) ...[
              const SizedBox(height: 18),
              _buildValuation(val,
                  approximate: vehicle.source == 'gemini_estimate'),
            ],

            // Vehicle Details
            if (vehicle.vehicleDetails != null) _buildVehicleDetailsSection(),

            // MOT History
            if (vehicle.motHistory != null) _buildMotSection(),

            // Specs
            if (vehicle.modelDetails != null) _buildSpecsSection(),

            // Tyres
            if (vehicle.tyreDetails != null) _buildTyreSection(),

            // Added date
            const SizedBox(height: 18),
            Text(
              'Added on ${_formatFullDate(vehicle.addedAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Vehicle'),
        content: Text('Remove ${vehicle.displayName} from your garage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await GarageService().deleteVehicle(uid, vehicle.id);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove vehicle')),
        );
      }
    }
  }

  // ─── shared helpers (mirroring saved_scan_detail_screen) ───

  Widget _specChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _freshnessBadge(
    String label,
    DateTime dataDate,
    Duration warnThreshold,
    Duration staleThreshold,
  ) {
    final age = DateTime.now().difference(dataDate);
    Color bgColor, textColor, borderColor;
    IconData icon;
    String text;

    if (age <= warnThreshold) {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      borderColor = Colors.green[200]!;
      icon = Icons.check_circle_outline;
      text = '$label: fresh';
    } else if (age <= staleThreshold) {
      bgColor = Colors.amber[50]!;
      textColor = Colors.amber[800]!;
      borderColor = Colors.amber[200]!;
      icon = Icons.access_time;
      text = '$label: ${age.inDays} days old';
    } else {
      bgColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
      borderColor = Colors.red[200]!;
      icon = Icons.warning_amber_rounded;
      text = '$label: stale';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _motFreshnessBadge(String motDueDateStr) {
    final due = DateTime.tryParse(motDueDateStr);
    if (due == null) return const SizedBox.shrink();
    final daysUntilDue = due.difference(DateTime.now()).inDays;

    Color bgColor, textColor, borderColor;
    IconData icon;
    String text;

    if (daysUntilDue < 0) {
      bgColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
      borderColor = Colors.red[200]!;
      icon = Icons.warning_amber_rounded;
      text = 'MOT: overdue';
    } else if (daysUntilDue <= 30) {
      bgColor = Colors.amber[50]!;
      textColor = Colors.amber[800]!;
      borderColor = Colors.amber[200]!;
      icon = Icons.access_time;
      text = 'MOT: ${daysUntilDue}d left';
    } else {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      borderColor = Colors.green[200]!;
      icon = Icons.check_circle_outline;
      text = 'MOT: ok';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildValuation(VehicleValuation valuation,
      {bool approximate = false}) {
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
            approximate
                ? '~${valuation.displayPrice}'
                : valuation.displayPrice,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            approximate
                ? 'Approximate UK valuation'
                : 'Estimated UK valuation',
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
          if (valuation.partExchange != null ||
              valuation.auction != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (valuation.partExchange != null)
                  Expanded(
                      child: _priceTier(
                    'Part Exchange',
                    VehicleValuation.formatGbp(valuation.partExchange!),
                  )),
                if (valuation.auction != null)
                  Expanded(
                      child: _priceTier(
                    'Auction',
                    VehicleValuation.formatGbp(valuation.auction!),
                  )),
                // spacer to keep alignment if only one is present
                if (valuation.partExchange == null ||
                    valuation.auction == null)
                  const Expanded(child: SizedBox()),
              ],
            ),
          ],
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
        Text(price,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[800])),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.green[600])),
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
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
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
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildVehicleDetailsSection() {
    final vd = vehicle.vehicleDetails!;
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
    final mot = vehicle.motHistory!;
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
                    color:
                        mot.isOverdue ? Colors.red[700] : Colors.teal[700],
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
                Text(
                    '$advisories advisory${advisories == 1 ? '' : 'ies'}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange[700])),
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
                        style:
                            TextStyle(fontSize: 11, color: Colors.red[600])),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecsSection() {
    final md = vehicle.modelDetails!;
    return _reportSection(
      title: 'Specifications',
      icon: Icons.build_outlined,
      color: Colors.indigo,
      children: [
        _infoRow(
            'Make / Model', '${md.make ?? ""} ${md.model ?? ""}'.trim()),
        if (md.bodyStyle != null)
          _infoRow('Body',
              '${md.bodyStyle}${md.numberOfDoors != null ? ', ${md.numberOfDoors} door' : ''}'),
        if (md.numberOfSeats != null)
          _infoRow('Seats', md.numberOfSeats.toString()),
        _infoRow('Engine', md.engineSummary),
        _infoRow(
            'Transmission',
            md.transmissionType != null
                ? '${md.transmissionType}${md.numberOfGears != null ? ', ${md.numberOfGears} speed' : ''}'
                : null),
        _infoRow('Drive', md.driveType),
        if (md.zeroToSixtyMph != null)
          _infoRow(
              '0-60 mph', '${md.zeroToSixtyMph!.toStringAsFixed(1)}s'),
        if (md.maxSpeedMph != null)
          _infoRow('Top Speed', '${md.maxSpeedMph} mph'),
        if (md.combinedMpg != null)
          _infoRow('Fuel Economy',
              '${md.combinedMpg!.toStringAsFixed(1)} mpg combined'),
        if (md.manufacturerCo2 != null)
          _infoRow('CO2', '${md.manufacturerCo2} g/km'),
        _infoRow('Euro Status', md.euroStatus),
        if (md.ncapStarRating != null)
          _infoRow('NCAP Rating',
              '${'★' * md.ncapStarRating!}${'☆' * (5 - md.ncapStarRating!)}'),
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
            _infoRow('Battery',
                '${md.batteryCapacityKwh} kWh (${md.batteryUsableKwh ?? "?"} usable)'),
          if (md.evRealRangeMiles != null)
            _infoRow('Real Range', '${md.evRealRangeMiles} miles'),
          if (md.maxChargeInputPowerKw != null)
            _infoRow('Max Charge', '${md.maxChargeInputPowerKw} kW'),
        ],
      ],
    );
  }

  Widget _buildTyreSection() {
    final td = vehicle.tyreDetails!;
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
        if (fitment.hubPcd != null) _infoRow('PCD', fitment.hubPcd),
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
