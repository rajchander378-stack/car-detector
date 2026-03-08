import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/car_identification.dart';
import '../models/vehicle_valuation.dart';
import '../services/saved_scan_service.dart';
import '../services/valuation_service.dart';

class ResultsScreen extends StatefulWidget {
  final String imagePath;
  final CarIdentification identification;

  const ResultsScreen({
    super.key,
    required this.imagePath,
    required this.identification,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _loading = false;
  VehicleValuation? _valuation;
  String? _error;
  bool _reportSubmitted = false;
  bool _saved = false;

  CarIdentification get identification => widget.identification;

  Future<void> _saveScan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await SavedScanService().saveScan(
        uid: user.uid,
        identification: identification,
        valuation: _valuation,
      );
      if (mounted) {
        setState(() => _saved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save report. Please try again.')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_saved || _valuation == null || !identification.identified) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Report?'),
        content: const Text(
          'You have valuation data that will be lost if you leave. '
          'Would you like to save this vehicle report?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () async {
              await _saveScan();
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _fetchValuation() async {
    final plate = identification.numberPlate;
    if (plate == null || plate.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final valuation =
          await ValuationService().getValuation(plate);
      setState(() {
        _valuation = valuation;
        _loading = false;
      });
    } on ValuationException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to fetch valuation. Please check your connection and try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (identification.identified)
            IconButton(
              icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
              tooltip: _saved ? 'Saved' : 'Save report',
              onPressed: _saved ? null : _saveScan,
            ),
        ],
      ),
      body: Column(
        children: [
          // Image hero with gradient overlay
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'captured_image',
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
                // Gradient fade into content below
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: 80,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Theme.of(context).scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: identification.identified
                  ? _buildResult()
                  : _buildNotFound(context),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildResult() {
    final pct = (identification.confidence * 100).toStringAsFixed(0);
    final hasPlate = identification.numberPlate != null &&
        identification.numberPlate!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vehicle name and confidence gauge row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                label: 'Identified vehicle: ${identification.displayName}',
                child: Text(
                  identification.displayName,
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Circular confidence gauge
            Semantics(
              label: 'Confidence: $pct percent',
              child: SizedBox(
                width: 56,
                height: 56,
                child: _ConfidenceGauge(
                  value: identification.confidence,
                  label: '$pct%',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // UK number plate display
        if (hasPlate) ...[
          _UkPlate(registration: identification.numberPlate!),
          const SizedBox(height: 12),
        ],

        // Spec chips
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (identification.colour != null)
              _specChip(Icons.palette_outlined, identification.colour!),
            if (identification.bodyStyle != null)
              _specChip(Icons.directions_car_outlined, identification.bodyStyle!),
            if (identification.generation != null)
              _specChip(Icons.history, identification.generation!),
            if (identification.trim != null)
              _specChip(Icons.auto_awesome_outlined, identification.trim!),
          ],
        ),

        if (identification.distinguishingFeatures.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Features',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          ...identification.distinguishingFeatures
              .map((f) => Padding(
                    padding: const EdgeInsets.only(left: 4, top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('\u2022 ', style: TextStyle(fontSize: 14)),
                        Expanded(child: Text(f, style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  )),
        ],

        if (identification.notes != null) ...[
          const SizedBox(height: 10),
          Text(identification.notes!,
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                fontSize: 13,
              )),
        ],

        const SizedBox(height: 18),

        // Price estimate button
        SizedBox(
          width: double.infinity,
          child: Tooltip(
            message: hasPlate
                ? 'Look up UK valuation by registration'
                : 'UK number plate required for price estimate',
            child: ElevatedButton.icon(
              onPressed: hasPlate && !_loading && _valuation == null
                  ? _fetchValuation
                  : null,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.attach_money),
              label: Text(_loading
                  ? 'Looking up...'
                  : _valuation != null
                      ? 'Price loaded'
                      : 'Get Price Estimate'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(14)),
            ),
          ),
        ),

        // Valuation shimmer placeholder
        if (_loading) _buildValuationShimmer(),

        // Valuation results
        if (_valuation != null) _buildValuation(_valuation!),

        // Error banner
        if (_error != null) _buildErrorBanner(_error!),

        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Manual search screen
            },
            icon: const Icon(Icons.edit),
            label: const Text('Not correct? Edit'),
          ),
        ),

        const SizedBox(height: 8),

        // Report AI result button
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _reportSubmitted ? null : _showReportDialog,
            icon: Icon(_reportSubmitted ? Icons.check : Icons.flag_outlined,
                size: 18),
            label: Text(_reportSubmitted
                ? 'Report submitted'
                : 'Report inaccurate result'),
            style: TextButton.styleFrom(
              foregroundColor: _reportSubmitted ? Colors.grey : Colors.red[400],
            ),
          ),
        ),
      ],
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

  Future<void> _showReportDialog() async {
    final reasons = [
      'Wrong make or model',
      'Wrong year or generation',
      'Wrong colour or body style',
      'Number plate read incorrectly',
      'Offensive or inappropriate content',
      'Other',
    ];

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        String? chosen;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Report Result'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What is wrong with this result?'),
                const SizedBox(height: 12),
                ...reasons.map((reason) => RadioListTile<String>(
                      title: Text(reason, style: const TextStyle(fontSize: 14)),
                      value: reason,
                      groupValue: chosen,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) =>
                          setDialogState(() => chosen = value),
                    )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: chosen != null
                    ? () => Navigator.pop(context, chosen)
                    : null,
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('ai_reports').add({
        'user_id': user?.uid,
        'user_email': user?.email,
        'reason': result,
        'identification': identification.toJson(),
        'timestamp': FieldValue.serverTimestamp(),
        'resolved': false,
      });
      if (mounted) {
        setState(() => _reportSubmitted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your report')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit report. Please try again.')),
        );
      }
    }
  }

  Widget _buildValuationShimmer() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBar(width: 160, height: 24),
          const SizedBox(height: 14),
          _ShimmerBar(width: double.infinity, height: 14),
          const SizedBox(height: 8),
          _ShimmerBar(width: double.infinity, height: 14),
          const SizedBox(height: 8),
          _ShimmerBar(width: 200, height: 14),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red[700], fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: Colors.red[400],
            onPressed: _fetchValuation,
            tooltip: 'Try again',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildValuation(VehicleValuation valuation) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
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
          // Hero price range
          _AnimatedPrice(
            text: valuation.displayPrice,
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

          // Price tiers grid
          Row(
            children: [
              if (valuation.dealerForecourt != null)
                Expanded(child: _priceTier(
                  'Dealer',
                  VehicleValuation.formatGbp(valuation.dealerForecourt!),
                )),
              if (valuation.privateAverage != null)
                Expanded(child: _priceTier(
                  'Private',
                  VehicleValuation.formatGbp(valuation.privateAverage!),
                )),
              if (valuation.tradeRetail != null)
                Expanded(child: _priceTier(
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

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_car_outlined,
                size: 48, color: Colors.orange[300]),
          ),
          const SizedBox(height: 20),
          const Text('Vehicle not recognised',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              identification.error ??
                  'Try getting closer or photographing from a different angle.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

// --- Supporting widgets ---

/// Circular confidence gauge with colour gradient arc
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

    // Background arc
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

    // Value arc
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

/// UK-style number plate display
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

/// Animated price text that counts up on first build
class _AnimatedPrice extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _AnimatedPrice({required this.text, required this.style});

  @override
  State<_AnimatedPrice> createState() => _AnimatedPriceState();
}

class _AnimatedPriceState extends State<_AnimatedPrice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(_animation),
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}

/// Pulsing shimmer bar for loading placeholders
class _ShimmerBar extends StatefulWidget {
  final double width;
  final double height;

  const _ShimmerBar({required this.width, required this.height});

  @override
  State<_ShimmerBar> createState() => _ShimmerBarState();
}

class _ShimmerBarState extends State<_ShimmerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
