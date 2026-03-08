import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/saved_scan.dart';
import '../services/saved_scan_service.dart';
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    );
  }
}

class _ScanList extends StatelessWidget {
  final Stream<List<SavedScan>> stream;
  final String uid;

  const _ScanList({required this.stream, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedScan>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final scans = snapshot.data ?? [];

        if (scans.isEmpty) {
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

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: scans.length,
          itemBuilder: (context, index) =>
              _ScanCard(scan: scans[index], uid: uid),
        );
      },
    );
  }
}

class _ScanCard extends StatelessWidget {
  final SavedScan scan;
  final String uid;

  const _ScanCard({required this.scan, required this.uid});

  @override
  Widget build(BuildContext context) {
    final id = scan.identification;
    final valuation = scan.valuation;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SavedScanDetailScreen(scan: scan, uid: uid),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
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
                            valuation.displayPrice,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _formatDate(scan.savedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (scan.isExpired) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Text(
                              'Prices may be stale',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
