import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/car_identification.dart';
import '../models/saved_scan.dart';
import '../services/csv_export_service.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/gemini_pricing_service.dart';
import '../services/plan_service.dart';
import '../services/saved_scan_service.dart';
import '../services/valuation_service.dart';
import '../services/vehicle_cache_service.dart';
import 'saved_scan_detail_screen.dart';

class SavedScansScreen extends StatefulWidget {
  final bool showFavouritesTab;

  const SavedScansScreen({super.key, this.showFavouritesTab = false});

  @override
  State<SavedScansScreen> createState() => _SavedScansScreenState();
}

class _SavedScansScreenState extends State<SavedScansScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = SavedScanService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.showFavouritesTab ? 1 : 0,
    );
    // GDPR: auto-purge scans older than the retention period (90 days)
    final uid = _uid;
    if (uid != null) {
      _service.purgeExpiredScans(uid);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _export(String uid, String format) async {
    final plan = await PlanService().getUserPlan(uid);
    if (plan != 'trader') {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Trader Plan Required'),
          content: const Text(
            'Export is available exclusively on the Trader plan. '
            'Upgrade to export your scans.',
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

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final scans = await _service.fetchAllScans(uid);
      if (!mounted) return;
      Navigator.pop(context);

      if (scans.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No scans to export.')),
        );
        return;
      }

      if (format == 'xlsx') {
        final service = ExcelExportService();
        final file = await service.generate(scans);
        await service.share(file);
      } else if (format == 'pdf') {
        final service = PdfExportService();
        final file = await service.generate(scans);
        await service.share(file);
      } else {
        final service = CsvExportService();
        final file = await service.generate(scans);
        await service.share(file);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved Scans')),
        body: const Center(child: Text('Please sign in to view saved scans.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Scans'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export',
            onSelected: (format) => _export(uid, format),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'csv', child: Text('Export CSV')),
              PopupMenuItem(value: 'xlsx', child: Text('Export Excel')),
              PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Favourites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ScanList(stream: _service.watchScans(uid), uid: uid),
          _ScanList(stream: _service.watchFavourites(uid), uid: uid),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddByPlate(uid),
        tooltip: 'Look up by plate',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddByPlate(String uid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddByPlateSheet(uid: uid),
    );
  }
}

class _AddByPlateSheet extends StatefulWidget {
  final String uid;
  const _AddByPlateSheet({required this.uid});

  @override
  State<_AddByPlateSheet> createState() => _AddByPlateSheetState();
}

class _AddByPlateSheetState extends State<_AddByPlateSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _status;
  bool _isError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _cleanPlate(String input) =>
      input.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  Future<void> _lookUp() async {
    final plate = _cleanPlate(_controller.text);
    if (plate.isEmpty || plate.length < 2 || plate.length > 8 ||
        !RegExp(r'^[A-Z0-9]{2,8}$').hasMatch(plate)) {
      setState(() {
        _status = 'Please enter a valid UK registration.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Looking up $plate...';
      _isError = false;
    });

    final service = SavedScanService();

    // Check if already saved
    final existing = await service.findByPlate(widget.uid, plate);
    if (existing != null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = '$plate is already in your saved scans.';
        _isError = true;
      });
      return;
    }

    // Try VDGL via cache service
    try {
      setState(() => _status = 'Fetching vehicle data...');
      final cacheResult = await VehicleCacheService().getReport(plate);
      final report = cacheResult.report;

      if (!cacheResult.wasCacheHit) {
        await PlanService().recordValuationScan(widget.uid);
      }

      // Build identification from report data
      final vehicleDetails = report.vehicleDetails;
      final identification = CarIdentification(
        identified: true,
        confidence: 1.0,
        make: vehicleDetails?.dvlaMake,
        model: vehicleDetails?.dvlaModel,
        numberPlate: plate,
      );

      setState(() => _status = 'Saving to your scans...');
      await service.saveScan(
        uid: widget.uid,
        identification: identification,
        report: report,
        source: 'vdgl',
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$plate added to your saved scans.')),
      );
    } on ValuationException catch (e) {
      // Invalid plate — show directly
      if (e.message.contains('InvalidSearchTerm') ||
          e.message.contains('not found') ||
          e.message.contains('No vehicle') ||
          e.message.contains('authentication')) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _status = e.message.contains('InvalidSearchTerm')
              ? 'Registration not recognised — check the plate and try again.'
              : e.message;
          _isError = true;
        });
        return;
      }
      // Generic API failure — try Gemini fallback
      await _tryGeminiFallback(plate);
    } catch (e) {
      await _tryGeminiFallback(plate);
    }
  }

  Future<void> _tryGeminiFallback(String plate) async {
    if (!mounted) return;
    setState(() => _status = 'Retrieving approximate values...');

    final identification = CarIdentification(
      identified: true,
      confidence: 0.5,
      numberPlate: plate,
    );

    final fallback =
        await GeminiPricingService().getApproximatePricing(identification);

    if (!mounted) return;

    if (fallback != null && fallback.hasData) {
      setState(() => _status = 'Saving approximate data...');
      await SavedScanService().saveScan(
        uid: widget.uid,
        identification: identification,
        valuation: fallback,
        source: 'gemini_estimate',
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$plate added with approximate pricing.')),
      );
    } else {
      setState(() {
        _loading = false;
        _status = 'Could not retrieve data for $plate. '
            'Check the registration and try again.';
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add Vehicle by Plate',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter a UK registration to look up and save.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_loading,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 8,
                  decoration: InputDecoration(
                    hintText: 'e.g. AB12 CDE',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  onSubmitted: (_) => _lookUp(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : _lookUp,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Look up'),
                ),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _status!,
                    style: TextStyle(
                      fontSize: 13,
                      color: _isError ? Colors.red[700] : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _SortField { date, make, valuation }
enum _SortDir { asc, desc }
enum _FilterSource { all, vdgl, gemini }

class _ScanList extends StatefulWidget {
  final Stream<List<SavedScan>> stream;
  final String uid;

  const _ScanList({required this.stream, required this.uid});

  @override
  State<_ScanList> createState() => _ScanListState();
}

class _ScanListState extends State<_ScanList> {
  _SortField _sortField = _SortField.date;
  _SortDir _sortDir = _SortDir.desc;
  _FilterSource _filterSource = _FilterSource.all;
  final Set<String> _selected = {};
  bool get _selectMode => _selected.isNotEmpty;

  List<SavedScan> _applySortAndFilter(List<SavedScan> scans) {
    var result = List<SavedScan>.from(scans);

    // Filter
    if (_filterSource == _FilterSource.vdgl) {
      result = result.where((s) => s.source != 'gemini_estimate').toList();
    } else if (_filterSource == _FilterSource.gemini) {
      result = result.where((s) => s.source == 'gemini_estimate').toList();
    }

    // Sort
    result.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case _SortField.date:
          cmp = a.savedAt.compareTo(b.savedAt);
        case _SortField.make:
          cmp = (a.identification.make ?? '')
              .compareTo(b.identification.make ?? '');
        case _SortField.valuation:
          final aVal = a.valuation?.dealerForecourt ?? 0;
          final bVal = b.valuation?.dealerForecourt ?? 0;
          cmp = aVal.compareTo(bVal);
      }
      return _sortDir == _SortDir.desc ? -cmp : cmp;
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedScan>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawScans = snapshot.data ?? [];

        if (rawScans.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_border,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No saved scans yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scan a vehicle and save the report\nto see it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        final scans = _applySortAndFilter(rawScans);

        return Column(
          children: [
            // Selection action bar
            if (_selectMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _selected.clear()),
                    ),
                    Text(
                      '${_selected.length} selected',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('All'),
                      onPressed: () => setState(() {
                        _selected.clear();
                        for (final s in scans) {
                          _selected.add(s.id);
                        }
                      }),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.file_download, size: 18),
                      label: const Text('Export'),
                      onPressed: () => _bulkExport(scans),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.delete_outline,
                          size: 18, color: Colors.red[700]),
                      label: Text('Delete',
                          style: TextStyle(color: Colors.red[700])),
                      onPressed: () => _bulkDelete(),
                    ),
                  ],
                ),
              ),
            // Sort & filter bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  // Sort dropdown
                  Expanded(
                    child: DropdownButtonFormField<_SortField>(
                      initialValue: _sortField,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Sort by',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: _SortField.date, child: Text('Date')),
                        DropdownMenuItem(
                            value: _SortField.make, child: Text('Make')),
                        DropdownMenuItem(
                            value: _SortField.valuation,
                            child: Text('Value')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _sortField = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Sort direction toggle
                  IconButton(
                    icon: Icon(_sortDir == _SortDir.desc
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                        size: 20),
                    tooltip: _sortDir == _SortDir.desc
                        ? 'Descending'
                        : 'Ascending',
                    onPressed: () => setState(() => _sortDir =
                        _sortDir == _SortDir.desc
                            ? _SortDir.asc
                            : _SortDir.desc),
                  ),
                ],
              ),
            ),
            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  _filterChip('All', _filterSource == _FilterSource.all,
                      () => setState(() => _filterSource = _FilterSource.all)),
                  const SizedBox(width: 6),
                  _filterChip(
                      'Exact',
                      _filterSource == _FilterSource.vdgl,
                      () =>
                          setState(() => _filterSource = _FilterSource.vdgl)),
                  const SizedBox(width: 6),
                  _filterChip(
                      'Approximate',
                      _filterSource == _FilterSource.gemini,
                      () => setState(
                          () => _filterSource = _FilterSource.gemini)),
                  const Spacer(),
                  Text(
                    '${scans.length} vehicle${scans.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: scans.isEmpty
                  ? Center(
                      child: Text(
                        'No scans match this filter.',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: scans.length,
                      itemBuilder: (context, index) {
                        final scan = scans[index];
                        return _ScanCard(
                          scan: scan,
                          uid: widget.uid,
                          selected: _selected.contains(scan.id),
                          selectMode: _selectMode,
                          onLongPress: () => setState(() {
                            _selected.add(scan.id);
                          }),
                          onSelectToggle: () => setState(() {
                            if (_selected.contains(scan.id)) {
                              _selected.remove(scan.id);
                            } else {
                              _selected.add(scan.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _bulkDelete() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Scans'),
        content: Text('Delete $count selected scan${count == 1 ? '' : 's'}? '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final service = SavedScanService();
    for (final id in _selected) {
      await service.deleteScan(widget.uid, id);
    }
    if (!mounted) return;
    setState(() => _selected.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted $count scan${count == 1 ? '' : 's'}.')),
    );
  }

  Future<void> _bulkExport(List<SavedScan> allScans) async {
    final plan = await PlanService().getUserPlan(widget.uid);
    if (plan != 'trader') {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Trader Plan Required'),
          content: const Text('Export is available on the Trader plan.'),
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

    final selectedScans =
        allScans.where((s) => _selected.contains(s.id)).toList();
    if (selectedScans.isEmpty) return;

    final exportService = CsvExportService();
    final file = await exportService.generate(selectedScans);
    await exportService.share(file);
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ScanCard extends StatelessWidget {
  final SavedScan scan;
  final String uid;
  final bool selected;
  final bool selectMode;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectToggle;

  const _ScanCard({
    required this.scan,
    required this.uid,
    this.selected = false,
    this.selectMode = false,
    this.onLongPress,
    this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context) {
    final id = scan.identification;
    final valuation = scan.valuation;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: selectMode
            ? onSelectToggle
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SavedScanDetailScreen(scan: scan, uid: uid),
                  ),
                );
              },
        onLongPress: selectMode ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection checkbox
              if (selectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.grey[400],
                    size: 22,
                  ),
                ),
              // Vehicle icon or plate badge
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      id.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (id.numberPlate != null &&
                            id.numberPlate!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2C10F),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(width: 0.5),
                            ),
                            child: Text(
                              id.numberPlate!.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (valuation != null)
                          Text(
                            scan.source == 'gemini_estimate'
                                ? '~${valuation.displayPrice}'
                                : valuation.displayPrice,
                            style: TextStyle(
                              fontSize: 13,
                              color: scan.source == 'gemini_estimate'
                                  ? Colors.orange[700]
                                  : Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _formatDate(scan.savedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        _freshnessBadge(
                          'Valuation',
                          scan.savedAt,
                          const Duration(days: 30),
                          const Duration(days: 60),
                        ),
                        if (scan.motHistory?.motDueDate != null)
                          _motFreshnessBadge(scan.motHistory!.motDueDate!),
                      ],
                    ),
                  ],
                ),
              ),

              // Favourite indicator
              if (scan.isFavourite)
                Icon(Icons.star, color: Colors.amber[600], size: 20),

              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _freshnessBadge(
    String label,
    DateTime dataDate,
    Duration warnThreshold,
    Duration staleThreshold,
  ) {
    final age = DateTime.now().difference(dataDate);
    Color bgColor;
    Color textColor;
    Color borderColor;
    String text;

    if (age <= warnThreshold) {
      // Fresh
      bgColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      borderColor = Colors.green[200]!;
      text = '$label: fresh';
    } else if (age <= staleThreshold) {
      // Ageing
      bgColor = Colors.amber[50]!;
      textColor = Colors.amber[800]!;
      borderColor = Colors.amber[200]!;
      text = '$label: ${age.inDays}d old';
    } else {
      // Stale
      bgColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
      borderColor = Colors.red[200]!;
      text = '$label: stale';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: textColor)),
    );
  }

  Widget _motFreshnessBadge(String motDueDateStr) {
    final due = DateTime.tryParse(motDueDateStr);
    if (due == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final daysUntilDue = due.difference(now).inDays;

    Color bgColor;
    Color textColor;
    Color borderColor;
    String text;

    if (daysUntilDue < 0) {
      bgColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
      borderColor = Colors.red[200]!;
      text = 'MOT: overdue';
    } else if (daysUntilDue <= 30) {
      bgColor = Colors.amber[50]!;
      textColor = Colors.amber[800]!;
      borderColor = Colors.amber[200]!;
      text = 'MOT: ${daysUntilDue}d left';
    } else if (daysUntilDue <= 180) {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      borderColor = Colors.green[200]!;
      text = 'MOT: ok';
    } else {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      borderColor = Colors.green[200]!;
      text = 'MOT: ok';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: textColor)),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
