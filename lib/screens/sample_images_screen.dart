import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../services/gemini_service.dart';
import '../services/image_processor.dart';
import 'results_screen.dart';

class SampleImagesScreen extends StatefulWidget {
  const SampleImagesScreen({super.key});

  @override
  State<SampleImagesScreen> createState() => _SampleImagesScreenState();
}

class _SampleImagesScreenState extends State<SampleImagesScreen> {
  static const _samples = [
    _SampleCar(
      asset: 'assets/sample_cars/sample_red_hatchback.jpg',
      label: 'Red Hatchback',
    ),
    _SampleCar(
      asset: 'assets/sample_cars/sample_blue_saloon.jpg',
      label: 'Blue Saloon',
    ),
    _SampleCar(
      asset: 'assets/sample_cars/sample_white_suv.jpg',
      label: 'White SUV',
    ),
    _SampleCar(
      asset: 'assets/sample_cars/sample_black_estate.jpg',
      label: 'Black Estate',
    ),
  ];

  bool _processing = false;
  String _status = '';

  Future<void> _processSample(_SampleCar sample) async {
    if (_processing) return;

    setState(() {
      _processing = true;
      _status = 'Optimising image...';
    });

    try {
      // Copy asset to temp file
      final byteData = await rootBundle.load(sample.asset);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/sample_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());

      // Optimise
      final processor = ImageProcessor();
      final result = await processor.optimise(tempFile);

      if (!result.quality.isAcceptable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.quality.issues.join('. '))),
          );
        }
        return;
      }

      // Send to Gemini
      setState(() => _status = 'Asking AI to identify...');
      final identification = await GeminiService().identifyCar(result.file);

      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ResultsScreen(
              imagePath: tempFile.path,
              identification: identification,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Failed to identify. Please check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _status = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sample Images')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tap a sample image to identify it with AI.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Replace these placeholders with real car photos for best results.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 4 / 3,
                    ),
                    itemCount: _samples.length,
                    itemBuilder: (context, index) {
                      final sample = _samples[index];
                      return _SampleCard(
                        sample: sample,
                        enabled: !_processing,
                        onTap: () => _processSample(sample),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_processing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 16),
                      Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SampleCar {
  final String asset;
  final String label;

  const _SampleCar({required this.asset, required this.label});
}

class _SampleCard extends StatelessWidget {
  final _SampleCar sample;
  final bool enabled;
  final VoidCallback onTap;

  const _SampleCard({
    required this.sample,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              sample.asset,
              fit: BoxFit.cover,
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(
                  sample.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (!enabled)
              Container(color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
