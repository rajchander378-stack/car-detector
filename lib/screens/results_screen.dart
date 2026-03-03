import 'dart:io';
import 'package:flutter/material.dart';
import '../models/car_identification.dart';

class ResultsScreen extends StatelessWidget {
  final String imagePath;
  final CarIdentification identification;

  const ResultsScreen({
    super.key,
    required this.imagePath,
    required this.identification,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Image.file(
              File(imagePath),
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

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Connect to pricing API
            },
            icon: const Icon(Icons.attach_money),
            label: const Text('Get Price Estimate'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16)),
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