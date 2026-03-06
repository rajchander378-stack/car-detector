import 'dart:io';
import 'package:flutter/material.dart';
import '../models/car_identification.dart';
import '../models/vehicle_valuation.dart';
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

  CarIdentification get identification => widget.identification;

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
        _error = 'Something went wrong: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: identification.identified
                  ? _buildResult()
                  : _buildNotFound(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final pct =
        (identification.confidence * 100).toStringAsFixed(0);
    final hasPlate = identification.numberPlate != null &&
        identification.numberPlate!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          identification.displayName,
          style: const TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        Row(children: [
          const Text('Confidence: '),
          Expanded(
            child: LinearProgressIndicator(
              value: identification.confidence,
              color: identification.confidence > 0.8
                  ? Colors.green
                  : identification.confidence > 0.6
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Text('$pct%'),
        ]),
        const SizedBox(height: 16),

        if (identification.numberPlate != null)
          _row('Reg', identification.numberPlate!),
        if (identification.colour != null)
          _row('Colour', identification.colour!),
        if (identification.bodyStyle != null)
          _row('Body', identification.bodyStyle!),
        if (identification.generation != null)
          _row('Generation', identification.generation!),
        if (identification.trim != null)
          _row('Trim', identification.trim!),

        if (identification
            .distinguishingFeatures.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Features:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ...identification.distinguishingFeatures
              .map((f) => Padding(
                    padding: const EdgeInsets.only(
                        left: 8, top: 2),
                    child: Text('- $f'),
                  )),
        ],

        if (identification.notes != null) ...[
          const SizedBox(height: 12),
          Text(identification.notes!,
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              )),
        ],

        const SizedBox(height: 20),

        // Price estimate button
        SizedBox(
          width: double.infinity,
          child: Tooltip(
            message: hasPlate
                ? 'Look up valuation by registration'
                : 'Number plate required for price estimate',
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
                padding: const EdgeInsets.all(16)),
            ),
          ),
        ),

        // Valuation results
        if (_valuation != null) _buildValuation(_valuation!),

        // Error message
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),

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
      ],
    );
  }

  Widget _buildValuation(VehicleValuation valuation) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valuation.displayPrice,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          if (valuation.retailPrice != null)
            _row('Dealer', VehicleValuation.formatGbp(valuation.retailPrice!)),
          if (valuation.privatePrice != null)
            _row('Private', VehicleValuation.formatGbp(valuation.privatePrice!)),
          if (valuation.tradePrice != null)
            _row('Trade', VehicleValuation.formatGbp(valuation.tradePrice!)),
          if (valuation.mileage != null)
            _row('Mileage', '${valuation.mileage} miles'),
          if (valuation.fuelType != null)
            _row('Fuel', valuation.fuelType!),
          if (valuation.engineSize != null)
            _row('Engine', valuation.engineSize!),
        ],
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.help_outline,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Could not identify this car',
              style: TextStyle(fontSize: 20)),
          if (identification.error != null) ...[
            const SizedBox(height: 8),
            Text(identification.error!,
                style: TextStyle(color: Colors.grey[600])),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey)),
        ),
        Expanded(child: Text(value)),
      ]),
    );
  }
}
