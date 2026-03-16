import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/car_identification.dart';
import '../models/mot_history.dart';
import '../models/saved_scan.dart';
import '../models/vehicle_report.dart';
import '../models/vehicle_valuation.dart';
import '../services/saved_scan_service.dart';
import '../services/plan_service.dart';
import '../services/valuation_service.dart';
import '../services/vehicle_cache_service.dart';

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
  VehicleReport? _report;
  String? _error;
  String? _retryStatus;
  bool _reportSubmitted = false;
  bool _saved = false;
  bool _saving = false;
  late CarIdentification _identification;
  ScanAllowance? _allowance;

  CarIdentification get identification => _identification;

  @override
  void initState() {
    super.initState();
    _identification = widget.identification;
    _loadAllowance();
  }

  Future<void> _loadAllowance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final allowance = await PlanService().checkValuationAllowance(user.uid);
    if (mounted) setState(() => _allowance = allowance);
  }

  Future<void> _saveScan() async {
    if (_saved || _saving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final service = SavedScanService();
    final plate = identification.numberPlate;

    // Check for existing scan of the same plate
    SavedScan? existing;
    if (plate != null && plate.isNotEmpty) {
      existing = await service.findByPlate(user.uid, plate);
    }

    String action = 'new';
    if (existing != null && mounted) {
      final daysAgo = DateTime.now().difference(existing.savedAt).inDays;
      final dateLabel = daysAgo == 0
          ? 'today'
          : daysAgo == 1
              ? 'yesterday'
              : '$daysAgo days ago';

      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Vehicle Already Saved'),
          content: Text(
            'You saved a report for ${plate!.toUpperCase()} $dateLabel.\n\n'
            'Would you like to update that report with this new data, '
            'or save it as a separate entry?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'new'),
              child: const Text('Save New'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'overwrite'),
              child: const Text('Update Existing'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel') return;
      action = choice;
    }

    setState(() => _saving = true);

    try {
      if (action == 'overwrite' && existing != null) {
        await service.updateScan(
          uid: user.uid,
          scanId: existing.id,
          identification: identification,
          valuation: _valuation,
          report: _report,
        );
      } else {
        await service.saveScan(
          uid: user.uid,
          identification: identification,
          valuation: _valuation,
          report: _report,
        );
      }
      if (mounted) {
        setState(() {
          _saved = true;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'overwrite'
                ? 'Existing report updated'
                : 'Report saved'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save report. Please try again.')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_saved || _valuation == null || !identification.identified) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save Report?'),
        content: const Text(
          'You have valuation data that will be lost if you leave. '
          'Would you like to save this vehicle report?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveScan();
      return true;
    }
    return result == 'discard';
  }

  Future<void> _fetchValuation() async {
    final plate = identification.numberPlate;
    if (plate == null || plate.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check for existing scan of the same plate
    final existing = await SavedScanService().findByPlate(user.uid, plate);
    if (existing != null && mounted) {
      final daysAgo = DateTime.now().difference(existing.savedAt).inDays;
      final dateLabel = daysAgo == 0
          ? 'today'
          : daysAgo == 1
              ? 'yesterday'
              : '$daysAgo days ago';

      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Existing Report Found'),
          content: Text(
            'You already have a report for ${plate.toUpperCase()} '
            'saved $dateLabel.\n\n'
            'Fetching a new report will use 1 scan credit. '
            'You can update the existing report or keep both.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'new'),
              child: const Text('Fetch New Report'),
            ),
          ],
        ),
      );
      if (choice != 'new') return;
    }

    // Check plan allowance
    final allowance = await PlanService().checkValuationAllowance(user.uid);

    // Free plan — valuations disabled
    if (!allowance.valuationEnabled) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Upgrade Required'),
          content: const Text(
            'Price valuations are available on the Basic plan (\u00a35/month, 10 scans) '
            'and Trader plan (\u00a314.99/month, 75 scans).\n\n'
            'Upgrade in Settings to unlock valuation estimates.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (allowance.isOverage) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Scan Limit Reached'),
          content: Text(
            'You\u2019ve used all ${allowance.monthlyLimit} valuation scans '
            'this month.\n\nThis scan will cost ${allowance.overagePriceFormatted}. '
            'Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _retryStatus = null;
    });

    try {
      final cacheResult = await VehicleCacheService().getReport(plate);
      final report = cacheResult.report;
      if (!cacheResult.wasCacheHit) {
        await PlanService().recordValuationScan(user.uid);
      }
      setState(() {
        _report = report;
        _valuation = report.valuation;
        _loading = false;
        _retryStatus = null;
      });
      // Refresh allowance for button hint
      _loadAllowance();
    } on ValuationException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
        _retryStatus = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to fetch valuation. Please check your connection and try again.';
        _loading = false;
        _retryStatus = null;
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
              onPressed: _saved || _saving ? null : _saveScan,
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
            child: Column(
              children: [
                ElevatedButton.icon(
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
                      ? (_retryStatus ?? 'Looking up...')
                      : _report != null
                          ? 'Full report loaded'
                          : 'Get Full Vehicle Report'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                ),
                if (_allowance != null && _valuation == null && hasPlate)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      !_allowance!.valuationEnabled
                          ? 'Upgrade to Basic or Trader to unlock valuations'
                          : _allowance!.isOverage
                              ? '${_allowance!.overagePriceFormatted} per scan (allowance used)'
                              : '${_allowance!.remainingFree} of ${_allowance!.monthlyLimit} scans remaining',
                      style: TextStyle(
                        fontSize: 12,
                        color: !_allowance!.valuationEnabled ? Colors.orange[700] : Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Valuation shimmer placeholder
        if (_loading) _buildValuationShimmer(),

        // Valuation results
        if (_valuation != null) _buildValuation(_valuation!),

        // Vehicle Details section
        if (_report?.vehicleDetails != null)
          _buildVehicleDetailsSection(),

        // MOT History section
        if (_report?.motHistory != null)
          _buildMotSection(),

        // Specs section
        if (_report?.modelDetails != null)
          _buildSpecsSection(),

        // Tyre section
        if (_report?.tyreDetails != null)
          _buildTyreSection(),

        // Error banner
        if (_error != null) _buildErrorBanner(_error!),

        // Save button
        if (identification.identified) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saved || _saving ? null : _saveScan,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_saved ? Icons.check : Icons.save),
              label: Text(_saving
                  ? 'Saving...'
                  : _saved
                      ? 'Saved'
                      : 'Save Report'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(14)),
            ),
          ),
        ],

        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showEditSheet,
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

  Future<void> _showEditSheet() async {
    final makeCtl = TextEditingController(text: identification.make ?? '');
    final modelCtl = TextEditingController(text: identification.model ?? '');
    final yearMinCtl = TextEditingController(
        text: identification.yearMin?.toString() ?? '');
    final yearMaxCtl = TextEditingController(
        text: identification.yearMax?.toString() ?? '');
    final generationCtl =
        TextEditingController(text: identification.generation ?? '');
    final trimCtl = TextEditingController(text: identification.trim ?? '');
    final bodyStyleCtl =
        TextEditingController(text: identification.bodyStyle ?? '');
    final colourCtl = TextEditingController(text: identification.colour ?? '');
    final plateCtl =
        TextEditingController(text: identification.numberPlate ?? '');

    final result = await showModalBottomSheet<CarIdentification>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Edit Identification',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _editField('Make', makeCtl)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _editField('Model', modelCtl)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _editField('Year From', yearMinCtl,
                            keyboard: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _editField('Year To', yearMaxCtl,
                            keyboard: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _editField('Generation', generationCtl)),
                    const SizedBox(width: 12),
                    Expanded(child: _editField('Trim', trimCtl)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _editField('Body Style', bodyStyleCtl)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _editField('Colour', colourCtl)),
                  ],
                ),
                const SizedBox(height: 12),
                _editField('Number Plate', plateCtl,
                    capitalization: TextCapitalization.characters),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final edited = identification.copyWith(
                            identified: true,
                            make: makeCtl.text.isEmpty
                                ? null
                                : makeCtl.text.trim(),
                            model: modelCtl.text.isEmpty
                                ? null
                                : modelCtl.text.trim(),
                            yearMin: int.tryParse(yearMinCtl.text),
                            yearMax: int.tryParse(yearMaxCtl.text),
                            generation: generationCtl.text.isEmpty
                                ? null
                                : generationCtl.text.trim(),
                            trim: trimCtl.text.isEmpty
                                ? null
                                : trimCtl.text.trim(),
                            bodyStyle: bodyStyleCtl.text.isEmpty
                                ? null
                                : bodyStyleCtl.text.trim(),
                            colour: colourCtl.text.isEmpty
                                ? null
                                : colourCtl.text.trim(),
                            numberPlate: plateCtl.text.isEmpty
                                ? null
                                : plateCtl.text.trim(),
                          );
                          Navigator.pop(context, edited);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    makeCtl.dispose();
    modelCtl.dispose();
    yearMinCtl.dispose();
    yearMaxCtl.dispose();
    generationCtl.dispose();
    trimCtl.dispose();
    bodyStyleCtl.dispose();
    colourCtl.dispose();
    plateCtl.dispose();

    if (result != null && mounted) {
      setState(() {
        _identification = result;
        _valuation = null;
        _error = null;
        _saved = false;
      });
    }
  }

  Widget _editField(String label, TextEditingController controller,
      {TextInputType? keyboard,
      TextCapitalization capitalization = TextCapitalization.words}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
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

  Widget _buildVehicleDetailsSection() {
    final vd = _report!.vehicleDetails!;
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
          if (vd.isImported)
            _warningChip('Imported'),
          if (vd.isExported)
            _warningChip('Exported'),
          if (vd.isScrapped)
            _warningChip('Scrapped'),
        ],
      ],
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

  Widget _buildMotSection() {
    final mot = _report!.motHistory!;
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
          // Show defects for failed tests
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
    final md = _report!.modelDetails!;
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
    final td = _report!.tyreDetails!;
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
          const SizedBox(height: 10),
          Text(
            'Estimate generated from market data \u2014 not guaranteed.',
            style: TextStyle(fontSize: 11, color: Colors.green[400]),
            textAlign: TextAlign.center,
          ),
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
