import 'dart:math' as math;
import 'package:flutter/material.dart';
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
              _buildValuation(valuation),
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

  Widget _buildValuation(VehicleValuation valuation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green[50]!, Colors.green[100]!],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valuation.displayPrice,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated UK valuation',
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
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
                Icon(Icons.speed, size: 16, color: Colors.green[700]),
                const SizedBox(width: 6),
                Text(
                  '${valuation.valuationMileage} miles',
                  style: TextStyle(fontSize: 13, color: Colors.green[800]),
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
