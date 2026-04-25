import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/garage_vehicle.dart';
import '../models/vehicle_valuation.dart';
import '../services/garage_service.dart';
import 'garage_detail_screen.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({super.key});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  final _service = GarageService();
  String _sortBy = 'added'; // added, name, value
  String _searchQuery = '';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  List<GarageVehicle> _filter(List<GarageVehicle> vehicles) {
    var list = vehicles;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((v) {
        final name = v.displayName.toLowerCase();
        final plate = (v.plate ?? '').toLowerCase();
        return name.contains(q) || plate.contains(q);
      }).toList();
    }
    switch (_sortBy) {
      case 'name':
        list.sort((a, b) => a.displayName.compareTo(b.displayName));
        break;
      case 'value':
        list.sort((a, b) {
          final av = a.valuation?.dealerForecourt ?? 0;
          final bv = b.valuation?.dealerForecourt ?? 0;
          return bv.compareTo(av);
        });
        break;
      default: // 'added' — already ordered by added_at desc from Firestore
        break;
    }
    return list;
  }

  Future<void> _deleteVehicle(GarageVehicle vehicle) async {
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
    final uid = _uid;
    if (uid == null) return;
    try {
      await _service.deleteVehicle(uid, vehicle.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${vehicle.displayName} removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove vehicle')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Garage'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              _sortItem('added', 'Date Added'),
              _sortItem('name', 'Name'),
              _sortItem('value', 'Highest Value'),
            ],
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in to view your garage.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name or plate...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<GarageVehicle>>(
                    stream: _service.watchGarage(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Error: ${snapshot.error}'),
                        );
                      }
                      final vehicles = _filter(snapshot.data ?? []);
                      if (vehicles.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.garage_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No vehicles match your search'
                                    : 'Your garage is empty',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Add vehicles from the web dashboard',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: vehicles.length,
                        itemBuilder: (context, index) =>
                            _VehicleCard(
                              vehicle: vehicles[index],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GarageDetailScreen(
                                    vehicle: vehicles[index],
                                    uid: uid,
                                  ),
                                ),
                              ),
                              onDelete: () =>
                                  _deleteVehicle(vehicles[index]),
                            ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  PopupMenuItem<String> _sortItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortBy == value)
            const Icon(Icons.check, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final GarageVehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final id = vehicle.identification;
    final val = vehicle.valuation;
    final hasPlate = vehicle.plate != null && vehicle.plate!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: name + plate
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (id.colour != null || id.bodyStyle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            [id.colour, id.bodyStyle]
                                .where((s) => s != null)
                                .join(' \u2022 '),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasPlate) _UkPlateMini(plate: vehicle.plate!),
                ],
              ),

              // Valuation row
              if (val != null && val.hasData) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: vehicle.source == 'gemini_estimate'
                        ? Colors.orange[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        vehicle.source == 'gemini_estimate'
                            ? Icons.auto_awesome
                            : Icons.attach_money,
                        size: 16,
                        color: vehicle.source == 'gemini_estimate'
                            ? Colors.orange[700]
                            : Colors.green[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(
                          children: [
                            if (val.dealerForecourt != null)
                              _priceChip('Dealer',
                                  VehicleValuation.formatGbp(
                                      val.dealerForecourt!)),
                            if (val.privateAverage != null) ...[
                              const SizedBox(width: 12),
                              _priceChip('Private',
                                  VehicleValuation.formatGbp(
                                      val.privateAverage!)),
                            ],
                            if (val.tradeRetail != null) ...[
                              const SizedBox(width: 12),
                              _priceChip('Trade',
                                  VehicleValuation.formatGbp(
                                      val.tradeRetail!)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Bottom row: badges + delete
              const SizedBox(height: 8),
              Row(
                children: [
                  _valuationAgeBadge(vehicle),
                  if (vehicle.motHistory?.motDueDate != null) ...[
                    const SizedBox(width: 6),
                    _motBadge(vehicle.motHistory!.motDueDate!),
                  ],
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    width: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(Icons.delete_outline,
                          color: Colors.grey[400]),
                      tooltip: 'Remove',
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceChip(String label, String price) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(price,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _valuationAgeBadge(GarageVehicle v) {
    final age = v.valuationAge;
    Color bg, text, border;
    String label;
    if (age.inDays <= 1) {
      bg = Colors.green[50]!;
      text = Colors.green[700]!;
      border = Colors.green[200]!;
      label = 'Fresh';
    } else if (age.inDays <= 7) {
      bg = Colors.green[50]!;
      text = Colors.green[700]!;
      border = Colors.green[200]!;
      label = '${age.inDays}d old';
    } else if (age.inDays <= 30) {
      bg = Colors.amber[50]!;
      text = Colors.amber[800]!;
      border = Colors.amber[200]!;
      label = '${age.inDays}d old';
    } else {
      bg = Colors.red[50]!;
      text = Colors.red[700]!;
      border = Colors.red[200]!;
      label = 'Stale';
    }
    return _badge(label, bg, text, border);
  }

  Widget _motBadge(String motDueDateStr) {
    final due = DateTime.tryParse(motDueDateStr);
    if (due == null) return const SizedBox.shrink();
    final daysLeft = due.difference(DateTime.now()).inDays;
    Color bg, text, border;
    String label;
    if (daysLeft < 0) {
      bg = Colors.red[50]!;
      text = Colors.red[700]!;
      border = Colors.red[200]!;
      label = 'MOT overdue';
    } else if (daysLeft <= 30) {
      bg = Colors.amber[50]!;
      text = Colors.amber[800]!;
      border = Colors.amber[200]!;
      label = 'MOT ${daysLeft}d';
    } else {
      bg = Colors.green[50]!;
      text = Colors.green[700]!;
      border = Colors.green[200]!;
      label = 'MOT ok';
    }
    return _badge(label, bg, text, border);
  }

  Widget _badge(String label, Color bg, Color text, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: text)),
    );
  }
}

class _UkPlateMini extends StatelessWidget {
  final String plate;
  const _UkPlateMini({required this.plate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF2C10F),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Text(
        plate.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.black,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
