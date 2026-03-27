import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/bulk_scan_item.dart';
import '../services/freshness_analysis_service.dart';
import '../services/gemini_service.dart';
import '../services/image_processor.dart';
import '../services/plan_service.dart';
import '../services/saved_scan_service.dart';
import '../services/vehicle_cache_service.dart';
import 'results_screen.dart';

class BulkGalleryScreen extends StatefulWidget {
  const BulkGalleryScreen({super.key});

  @override
  State<BulkGalleryScreen> createState() => _BulkGalleryScreenState();
}

class _BulkGalleryScreenState extends State<BulkGalleryScreen> {
  final GeminiService _gemini = GeminiService();
  final ImageProcessor _processor = ImageProcessor();
  final List<BulkScanItem> _items = [];
  bool _processing = false;
  bool _cancelled = false;
  bool _pickingImages = true;
  bool _savingAll = false;
  int _completedCount = 0;
  final List<File> _tempFiles = [];
  FreshnessAnalysisResult? _freshnessResult;
  bool _analyzingFreshness = false;
  bool _fetchingAll = false;
  int _fetchedCount = 0;

  @override
  void initState() {
    super.initState();
    _checkPlanAndPick();
  }

  Future<void> _checkPlanAndPick() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final plan = await PlanService().getUserPlan(user.uid);
    if (plan != 'trader') {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Trader Plan Required'),
          content: const Text(
            'Bulk gallery scanning is available exclusively '
            'on the Trader plan. Upgrade to scan multiple '
            'vehicles at once.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
      return;
    }

    _pickImages();
  }

  @override
  void dispose() {
    // Clean up temp files
    for (final f in _tempFiles) {
      f.deleteSync(recursive: false);
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 1024,
      imageQuality: 85,
      limit: 20,
    );

    if (!mounted) return;

    if (picked.isEmpty) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _pickingImages = false;
      _items.addAll(picked.map((xf) => BulkScanItem(imagePath: xf.path)));
    });

    _processAll();
  }

  Future<void> _processAll() async {
    setState(() => _processing = true);
    final user = FirebaseAuth.instance.currentUser;

    for (int i = 0; i < _items.length; i++) {
      if (_cancelled) break;
      final item = _items[i];

      setState(() => item.status = BulkScanStatus.optimising);

      try {
        final result = await _processor.optimise(File(item.imagePath));
        _tempFiles.add(result.file);

        if (!result.quality.isAcceptable) {
          setState(() {
            item.status = BulkScanStatus.failed;
            item.error = result.quality.issues.join('. ');
            _completedCount++;
          });
          continue;
        }

        if (_cancelled) break;

        setState(() => item.status = BulkScanStatus.identifying);

        final identification = await _gemini.identifyCar(result.file);

        // Clean the number plate if present
        final cleaned = identification.numberPlate != null &&
                identification.numberPlate!.trim().isNotEmpty
            ? identification.copyWith(
                numberPlate:
                    BulkScanItem.cleanPlate(identification.numberPlate!))
            : identification;

        setState(() {
          item.identification = cleaned;
          item.status = BulkScanStatus.completed;
          _completedCount++;
        });

        // Record usage for successful identifications
        if (cleaned.identified && user != null) {
          PlanService().recordAiOnlyScan(user.uid);
        }
      } on GeminiTimeoutException {
        setState(() {
          item.status = BulkScanStatus.failed;
          item.error = 'Request timed out';
          _completedCount++;
        });
      } catch (e) {
        setState(() {
          item.status = BulkScanStatus.failed;
          item.error = 'Processing failed';
          _completedCount++;
        });
      }
    }

    if (mounted) {
      setState(() => _processing = false);
      _showProcessingSummary();
      _runFreshnessAnalysis();
    }
  }

  Future<void> _retryItem(int index) async {
    final item = _items[index];
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      item.status = BulkScanStatus.optimising;
      item.error = null;
      item.identification = null;
      _completedCount--;
    });

    try {
      final result = await _processor.optimise(File(item.imagePath));
      _tempFiles.add(result.file);

      if (!result.quality.isAcceptable) {
        setState(() {
          item.status = BulkScanStatus.failed;
          item.error = result.quality.issues.join('. ');
          _completedCount++;
        });
        return;
      }

      setState(() => item.status = BulkScanStatus.identifying);
      final identification = await _gemini.identifyCar(result.file);

      final cleaned = identification.numberPlate != null &&
              identification.numberPlate!.trim().isNotEmpty
          ? identification.copyWith(
              numberPlate:
                  BulkScanItem.cleanPlate(identification.numberPlate!))
          : identification;

      setState(() {
        item.identification = cleaned;
        item.status = BulkScanStatus.completed;
        _completedCount++;
      });

      if (cleaned.identified && user != null) {
        PlanService().recordAiOnlyScan(user.uid);
      }
    } on GeminiTimeoutException {
      setState(() {
        item.status = BulkScanStatus.failed;
        item.error = 'Request timed out';
        _completedCount++;
      });
    } catch (e) {
      setState(() {
        item.status = BulkScanStatus.failed;
        item.error = 'Processing failed';
        _completedCount++;
      });
    }
  }

  Future<void> _saveAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final identifiedItems =
        _items.where((item) => item.isIdentified && !item.saved).toList();
    if (identifiedItems.isEmpty) return;

    setState(() => _savingAll = true);

    int savedCount = 0;
    for (final item in identifiedItems) {
      try {
        // Use manual plate if entered, otherwise use AI-detected plate
        final id = item.manualNumberPlate != null &&
                item.manualNumberPlate!.isNotEmpty
            ? item.identification!
                .copyWith(numberPlate: item.manualNumberPlate)
            : item.identification!;

        await SavedScanService().saveScan(
          uid: user.uid,
          identification: id,
        );
        setState(() => item.saved = true);
        savedCount++;
      } catch (_) {
        // Skip failed saves silently
      }
    }

    if (mounted) {
      setState(() => _savingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$savedCount vehicle(s) saved')),
      );
    }
  }

  Future<void> _runFreshnessAnalysis() async {
    final vehiclesWithPlates = _items
        .where((i) => i.hasPlate && i.isIdentified)
        .map((i) {
          final plate = i.effectivePlate!;
          return (plate: plate, identification: i.identification!);
        })
        .toList();

    if (vehiclesWithPlates.isEmpty) return;

    setState(() => _analyzingFreshness = true);

    try {
      final result =
          await FreshnessAnalysisService().analyze(vehiclesWithPlates);
      if (mounted) {
        setState(() {
          _freshnessResult = result;
          _analyzingFreshness = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _analyzingFreshness = false);
    }
  }

  Future<void> _fetchAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _freshnessResult == null) return;

    final toFetch = _freshnessResult!.vehicles
        .where((v) =>
            v.category == FreshnessCategory.newLookup ||
            v.category == FreshnessCategory.stale)
        .toList();

    if (toFetch.isEmpty) return;

    setState(() {
      _fetchingAll = true;
      _fetchedCount = 0;
    });

    for (final vehicle in toFetch) {
      try {
        final cacheResult =
            await VehicleCacheService().getReport(vehicle.plate);
        if (!cacheResult.wasCacheHit) {
          await PlanService().recordValuationScan(user.uid);
        }
      } catch (_) {
        // Continue with other vehicles
      }
      if (mounted) setState(() => _fetchedCount++);
    }

    if (mounted) {
      setState(() => _fetchingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Fetched data for $_fetchedCount of ${toFetch.length} vehicles.'),
        ),
      );
      // Re-run analysis to update counts
      _runFreshnessAnalysis();
    }
  }

  void _cancel() {
    setState(() => _cancelled = true);
  }

  void _showProcessingSummary() {
    final withPlate = _items.where((i) => i.hasPlate).length;
    final identifiedNoPlate = _items
        .where((i) => i.isIdentified && !i.hasPlate)
        .length;
    final failed =
        _items.where((i) => i.status == BulkScanStatus.failed).length;
    final noPlateTotal = identifiedNoPlate + failed;

    if (_items.isEmpty || _cancelled) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan Complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (withPlate > 0)
              _summaryRow(
                Icons.check_circle,
                Colors.green,
                '$withPlate image${withPlate == 1 ? '' : 's'} suitable for pricing',
              ),
            if (noPlateTotal > 0) ...[
              const SizedBox(height: 8),
              _summaryRow(
                Icons.warning_amber_rounded,
                Colors.orange,
                '$noPlateTotal image${noPlateTotal == 1 ? '' : 's'} failed to '
                    'recognise a number plate',
              ),
              const SizedBox(height: 12),
              Text(
                'Please recapture these images or enter the '
                'number plates manually.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  Future<void> _enterPlateManually(BulkScanItem item) async {
    final controller = TextEditingController(
      text: item.manualNumberPlate ?? '',
    );

    final plate = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Number Plate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.identification != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  item.identification!.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. AB12 CDE',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (plate != null && plate.trim().isNotEmpty) {
      setState(() {
        item.manualNumberPlate = BulkScanItem.cleanPlate(plate);
      });
    }
  }

  void _viewDetails(BulkScanItem item) {
    if (item.identification == null) return;

    // If a manual plate was entered, pass an updated identification
    final id = item.manualNumberPlate != null &&
            item.manualNumberPlate!.isNotEmpty
        ? item.identification!.copyWith(numberPlate: item.manualNumberPlate)
        : item.identification!;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          imagePath: item.imagePath,
          identification: id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pickingImages) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bulk Gallery Scan')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Opening gallery...'),
            ],
          ),
        ),
      );
    }

    final identifiedCount = _items.where((i) => i.isIdentified).length;
    final unsavedCount =
        _items.where((i) => i.isIdentified && !i.saved).length;
    final failedCount =
        _items.where((i) => i.status == BulkScanStatus.failed).length;
    final readyForPricing = _items.where((i) => i.hasPlate).length;
    final needsPlate =
        _items.where((i) => i.isIdentified && !i.hasPlate).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Gallery Scan'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_completedCount of ${_items.length} processed',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.85),
                      ),
                    ),
                    if (identifiedCount > 0)
                      Text(
                        '$readyForPricing ready'
                        '${needsPlate > 0 ? ', $needsPlate need plate' : ''}'
                        '${failedCount > 0 ? ', $failedCount failed' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: _items.isEmpty
                    ? 0
                    : _completedCount / _items.length,
                minHeight: 3,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .onPrimary
                    .withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Freshness analysis card
          if (!_processing && _freshnessResult != null)
            _buildFreshnessCard(_freshnessResult!),
          if (_analyzingFreshness)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Analyzing data freshness...',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          // Vehicle list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (context, index) =>
                  _buildItemCard(_items[index], index),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(unsavedCount),
    );
  }

  Widget _buildItemCard(BulkScanItem item, int index) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: item.status == BulkScanStatus.failed
            ? const BorderSide(color: Colors.red, width: 1.5)
            : (item.isIdentified && !item.hasPlate)
                ? BorderSide(color: Colors.orange[600]!, width: 1.5)
                : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(item.imagePath),
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                cacheWidth: 128,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  if (item.isIdentified) ...[
                    Text(
                      item.identification!.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (item.effectivePlate != null &&
                        item.effectivePlate!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDC00),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          item.effectivePlate!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: Colors.black,
                          ),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _enterPlateManually(item),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit,
                                size: 14, color: Colors.orange[700]),
                            const SizedBox(width: 4),
                            Text(
                              'No plate — tap to enter',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else if (item.status == BulkScanStatus.completed &&
                      !item.identification!.identified) ...[
                    Text(
                      'Vehicle not recognised',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[700],
                      ),
                    ),
                    if (item.identification!.error != null)
                      Text(
                        item.identification!.error!,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ] else if (item.status == BulkScanStatus.failed) ...[
                    Text(
                      item.error ?? 'Processing failed',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.red,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    Text(
                      _statusLabel(item.status),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Status icon / actions
            _buildStatusWidget(item, index),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusWidget(BulkScanItem item, int index) {
    switch (item.status) {
      case BulkScanStatus.pending:
        return Icon(Icons.hourglass_empty,
            size: 22, color: Colors.grey[400]);
      case BulkScanStatus.optimising:
      case BulkScanStatus.identifying:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case BulkScanStatus.completed:
        if (item.isIdentified) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.hasPlate) ...[
                if (item.saved)
                  Icon(Icons.check_circle,
                      size: 22, color: Colors.green[600])
                else
                  const Icon(Icons.check_circle_outline,
                      size: 22, color: Colors.green),
              ] else
                InkWell(
                  onTap: () => _enterPlateManually(item),
                  child: Icon(Icons.edit_note,
                      size: 24, color: Colors.orange[600]),
                ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _viewDetails(item),
                child: Icon(Icons.chevron_right,
                    size: 22, color: Colors.grey[500]),
              ),
            ],
          );
        } else {
          return Icon(Icons.warning_amber_rounded,
              size: 22, color: Colors.orange[600]);
        }
      case BulkScanStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh, size: 22, color: Colors.red),
          onPressed: () => _retryItem(index),
          tooltip: 'Retry',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
    }
  }

  String _statusLabel(BulkScanStatus status) {
    switch (status) {
      case BulkScanStatus.pending:
        return 'Waiting...';
      case BulkScanStatus.optimising:
        return 'Optimising image...';
      case BulkScanStatus.identifying:
        return 'Identifying vehicle...';
      case BulkScanStatus.completed:
        return 'Complete';
      case BulkScanStatus.failed:
        return 'Failed';
    }
  }

  Widget _buildFreshnessCard(FreshnessAnalysisResult result) {
    final needsFetch = result.staleCount + result.newCount;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
        ),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 18, color: Colors.blue[800]),
              const SizedBox(width: 6),
              Text('Data Freshness Analysis',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blue[900])),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _freshnessChip(
                  Icons.check_circle, Colors.green, '${result.freshCount} Fresh'),
              const SizedBox(width: 8),
              _freshnessChip(Icons.access_time, Colors.amber[700]!,
                  '${result.staleCount} Stale'),
              const SizedBox(width: 8),
              _freshnessChip(
                  Icons.fiber_new, Colors.blue, '${result.newCount} New'),
            ],
          ),
          if (needsFetch > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Estimated cost to refresh: \u00A3${result.totalEstimatedCost.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 13, color: Colors.blue[900]),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _fetchingAll ? null : _fetchAllData,
                icon: _fetchingAll
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue[100]),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_fetchingAll
                    ? 'Fetching ($_fetchedCount/$needsFetch)...'
                    : 'Fetch All Data ($needsFetch vehicles)'),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'All vehicle data is up to date.',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _freshnessChip(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildBottomBar(int unsavedCount) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: Row(
          children: [
            if (_processing) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _cancel,
                  child: const Text('Cancel'),
                ),
              ),
            ] else ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
              if (unsavedCount > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _savingAll ? null : _saveAll,
                    icon: _savingAll
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _savingAll
                          ? 'Saving...'
                          : 'Save All ($unsavedCount)',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
