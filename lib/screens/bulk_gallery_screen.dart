import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/bulk_scan_item.dart';
import '../services/gemini_service.dart';
import '../services/image_processor.dart';
import '../services/plan_service.dart';
import '../services/saved_scan_service.dart';
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

        setState(() {
          item.identification = identification;
          item.status = BulkScanStatus.completed;
          _completedCount++;
        });

        // Record usage for successful identifications
        if (identification.identified && user != null) {
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

    if (mounted) setState(() => _processing = false);
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

      setState(() {
        item.identification = identification;
        item.status = BulkScanStatus.completed;
        _completedCount++;
      });

      if (identification.identified && user != null) {
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
        await SavedScanService().saveScan(
          uid: user.uid,
          identification: item.identification!,
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

  void _cancel() {
    setState(() => _cancelled = true);
  }

  void _viewDetails(BulkScanItem item) {
    if (item.identification == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          imagePath: item.imagePath,
          identification: item.identification!,
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
                        '$identifiedCount identified'
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
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (context, index) =>
            _buildItemCard(_items[index], index),
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
                    if (item.identification!.numberPlate != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDC00),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          item.identification!.numberPlate!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            color: Colors.black,
                          ),
                        ),
                      ),
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
              if (item.saved)
                Icon(Icons.check_circle, size: 22, color: Colors.green[600])
              else
                const Icon(Icons.check_circle_outline,
                    size: 22, color: Colors.green),
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
