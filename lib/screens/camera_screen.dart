import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/detector_service.dart';
import '../services/gemini_service.dart';
import '../services/image_processor.dart';
import 'results_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  final DetectorService _detector = DetectorService();
  final GeminiService _gemini = GeminiService();
  final ImageProcessor _processor = ImageProcessor();

  bool _isProcessing = false;
  String _status = 'Point at a car and tap capture';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = 'No camera found');
        return;
      }
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
      );
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _status = 'Camera error: $e');
    }
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing || _controller == null) return;
    setState(() {
      _isProcessing = true;
      _status = 'Detecting vehicle...';
    });

    try {
      final xFile = await _controller!.takePicture();
      final imageFile = File(xFile.path);

      // Skip ML Kit for now - send directly to Gemini
      setState(() => _status = 'Identifying car...');

      // Optimise the image before sending
      final optimised = await _processor.optimise(imageFile);

      // Stage 2: Gemini via Firebase AI Logic
      setState(() => _status = 'Asking Gemini...');
      final identification = await _gemini.identifyCar(
        optimised
      );

      // Navigate to results
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultsScreen(
              imagePath: xFile.path,
              identification: identification,
            ),
          ),
        );
        setState(() => _status = 'Point at a car and tap capture');
      }

    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null ||
        !_controller!.value.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),

          // Status bar at top
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(12),
                child: Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Capture button
          Positioned(
            bottom: 40, left: 0, right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isProcessing
                    ? null : _captureAndProcess,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isProcessing
                        ? Colors.grey : Colors.white,
                    border: Border.all(
                      color: Colors.white, width: 4,
                    ),
                  ),
                  child: _isProcessing
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(Icons.camera_alt,
                          size: 40,
                          color: Colors.black87),
                ),
              ),
            ),
          ),

          // History button
          Positioned(
            bottom: 50, right: 30,
            child: IconButton(
              onPressed: () {
                // TODO: Navigate to history screen
              },
              icon: const Icon(
                Icons.history,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _detector.dispose();
    super.dispose();
  }
}