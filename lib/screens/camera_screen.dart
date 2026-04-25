import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/detector_service.dart';
import '../services/gemini_service.dart';
import '../services/image_processor.dart';
import '../services/lockout_service.dart';
import '../services/plan_service.dart';
import 'bulk_gallery_screen.dart';
import 'messages_screen.dart';
import 'pricing_screen.dart';
import 'results_screen.dart';
import 'sample_images_screen.dart';
import 'garage_screen.dart';
import 'saved_scans_screen.dart';
import 'settings_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  final DetectorService _detector = DetectorService();
  final GeminiService _gemini = GeminiService();
  final ImageProcessor _processor = ImageProcessor();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isProcessing = false;
  String _status = 'Point at a UK car and tap capture';
  int _consecutiveFailures = 0;
  bool _lockedOut = false;
  bool _cameraPermissionGranted = false;
  bool _showFlash = false;
  final List<String> _recentErrors = [];

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const _disclosureShownKey = 'camera_disclosure_shown';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      _cameraPermissionGranted = true;
      _initCamera();
    } else {
      _showDisclosureThenRequest();
    }
  }

  Future<void> _showDisclosureThenRequest() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool(_disclosureShownKey) ?? false;

    if (!alreadyShown && mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.camera_alt, size: 40),
          title: const Text('Camera Access'),
          content: const Text(
            'AutoSpotter uses your camera to capture vehicle images '
            'for AI identification and valuation.\n\n'
            'Your photos are sent securely for AI-assisted '
            'analysis. Images are processed transiently and are '
            'not stored on our servers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      await prefs.setBool(_disclosureShownKey, true);
    }

    if (!mounted) return;

    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _cameraPermissionGranted = true);
      _initCamera();
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        setState(() => _status = 'Camera permission denied');
        _showPermissionDeniedDialog();
      }
    } else {
      if (mounted) {
        setState(() => _status = 'Camera permission is required');
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'AutoSpotter needs camera access to identify vehicles. '
          'Please enable camera permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
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
      setState(() => _status = 'Unable to start camera. Please restart the app.');
    }
  }

  Future<bool> _hasConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing || _controller == null || _lockedOut) return;

    // Shutter flash + haptic feedback on capture
    HapticFeedback.mediumImpact();
    setState(() => _showFlash = true);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _showFlash = false);

    // Check connectivity before proceeding
    if (!await _hasConnectivity()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No internet connection. Please check your connection and try again.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Optimising image...';
    });

    try {
      final xFile = await _controller!.takePicture();
      final imageFile = File(xFile.path);

      // Optimise the image
      final result = await _processor.optimise(imageFile);

      // Quality gate — warn user and abort if image is unacceptable
      if (!result.quality.isAcceptable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.quality.issues.join('. ')),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() => _status = 'Please retake the photo');
        }
        return;
      }

      // TODO: Re-enable vehicle detection gate once a custom
      // COCO-trained .tflite model is bundled. The default ML Kit
      // model cannot detect vehicles, so we skip straight to Gemini.

      // Send to Gemini via Firebase AI
      setState(() => _status = 'Asking AI to identify...');
      final identification = await _gemini.identifyCar(result.file);

      if (!identification.identified) {
        // Failed recognition counts toward lockout
        _consecutiveFailures++;
        _recentErrors.add(identification.error ?? 'Vehicle not recognised');
        if (_consecutiveFailures >= 3) {
          _logLockout();
          setState(() {
            _lockedOut = true;
            _status = '';
          });
        } else {
          // Show result screen so user sees the reason, but track the failure
          if (mounted) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, _, _) => ResultsScreen(
                  imagePath: xFile.path,
                  identification: identification,
                ),
                transitionsBuilder: (_, animation, _, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
            setState(() => _status =
                'Recognition failed. Please try again. '
                '($_consecutiveFailures/3)');
          }
        }
      } else {
        // Success — reset failure counter
        _consecutiveFailures = 0;
        _recentErrors.clear();

        // Record AI scan usage
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          PlanService().recordAiOnlyScan(user.uid);
        }

        // Navigate to results with hero transition
        if (mounted) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, _, _) => ResultsScreen(
                imagePath: xFile.path,
                identification: identification,
                trackSuccessfulIdentification: true,
              ),
              transitionsBuilder: (_, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
          setState(() => _status = 'Point at a UK car and tap capture');
        }
      }

    } on GeminiTimeoutException {
      _consecutiveFailures++;
      _recentErrors.add('GeminiTimeoutException');
      if (_consecutiveFailures >= 3) {
        _logLockout();
        setState(() {
          _lockedOut = true;
          _status = '';
        });
      } else {
        setState(() => _status =
            'Request timed out. Please try again. '
            '($_consecutiveFailures/3)');
      }
    } catch (e) {
      _consecutiveFailures++;
      _recentErrors.add(e.runtimeType.toString());
      if (_consecutiveFailures >= 3) {
        _logLockout();
        setState(() {
          _lockedOut = true;
          _status = '';
        });
      } else {
        setState(() => _status =
            'Something went wrong. Please try again. '
            '($_consecutiveFailures/3)');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing || _lockedOut) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
    );
    if (picked == null) return;

    if (!await _hasConnectivity()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please check your connection and try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Optimising image...';
    });

    try {
      final imageFile = File(picked.path);
      final result = await _processor.optimise(imageFile);

      if (!result.quality.isAcceptable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.quality.issues.join('. ')),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() => _status = 'Please choose a clearer photo');
        }
        return;
      }

      setState(() => _status = 'Asking AI to identify...');
      final identification = await _gemini.identifyCar(result.file);

      if (!identification.identified) {
        _consecutiveFailures++;
        _recentErrors.add(identification.error ?? 'Vehicle not recognised');
        if (_consecutiveFailures >= 3) {
          _logLockout();
          setState(() { _lockedOut = true; _status = ''; });
        } else {
          if (mounted) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, _, _) => ResultsScreen(
                  imagePath: picked.path,
                  identification: identification,
                ),
                transitionsBuilder: (_, animation, _, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
            setState(() => _status =
                'Recognition failed. Please try again. '
                '($_consecutiveFailures/3)');
          }
        }
      } else {
        _consecutiveFailures = 0;
        _recentErrors.clear();

        // Record AI scan usage
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          PlanService().recordAiOnlyScan(user.uid);
        }

        if (mounted) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, _, _) => ResultsScreen(
                imagePath: picked.path,
                identification: identification,
                trackSuccessfulIdentification: true,
              ),
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
          setState(() => _status = 'Point at a UK car and tap capture');
        }
      }
    } on GeminiTimeoutException {
      _consecutiveFailures++;
      _recentErrors.add('GeminiTimeoutException');
      if (_consecutiveFailures >= 3) {
        _logLockout();
        setState(() { _lockedOut = true; _status = ''; });
      } else {
        setState(() => _status =
            'Request timed out. Please try again. '
            '($_consecutiveFailures/3)');
      }
    } catch (e) {
      _consecutiveFailures++;
      _recentErrors.add(e.runtimeType.toString());
      if (_consecutiveFailures >= 3) {
        _logLockout();
        setState(() { _lockedOut = true; _status = ''; });
      } else {
        setState(() => _status =
            'Something went wrong. Please try again. '
            '($_consecutiveFailures/3)');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lockedOut) {
      return _buildLockoutScreen();
    }

    if (!_cameraPermissionGranted ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_status),
              if (!_cameraPermissionGranted &&
                  _status == 'Camera permission is required') ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _showDisclosureThenRequest,
                  child: const Text('Grant Camera Access'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),

          // Viewfinder guide
          if (!_isProcessing)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.width * 0.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Align vehicle within frame',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
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

          // Shutter flash overlay
          if (_showFlash)
            Positioned.fill(
              child: Container(color: Colors.white),
            ),

          // Processing overlay with pulsing indicator and stage text
          if (_isProcessing)
            Positioned.fill(
              child: Semantics(
                label: 'Identifying your car. Please wait.',
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FadeTransition(
                          opacity: _pulseAnimation,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            child: const Icon(
                              Icons.directions_car,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please wait and do not close the app.',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(
                          width: 160,
                          child: LinearProgressIndicator(
                            color: Colors.white70,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Capture button
          if (!_isProcessing)
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Center(
                child: Semantics(
                  button: true,
                  label: 'Capture photo to identify vehicle',
                  child: GestureDetector(
                    onTap: _captureAndProcess,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.white, width: 4,
                        ),
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 40,
                          color: Colors.black87),
                    ),
                  ),
                ),
              ),
            ),

          // Gallery button (left of capture)
          // Tap: pick one photo. Long-press: bulk gallery scan.
          if (!_isProcessing)
            Positioned(
              bottom: 55, left: 40,
              child: Semantics(
                button: true,
                label: 'Pick photo from gallery. Long press for bulk scan.',
                child: GestureDetector(
                  onTap: _pickFromGallery,
                  onLongPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BulkGalleryScreen(),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),

          // Saved scans button (right of capture)
          if (!_isProcessing)
            Positioned(
              bottom: 55, right: 40,
              child: Semantics(
                button: true,
                label: 'View saved scans',
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SavedScansScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.bookmark_outline,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),

          // Menu button (top left)
          if (!_isProcessing)
            Positioned(
              top: 0, left: 0,
              child: SafeArea(
                child: Semantics(
                  button: true,
                  label: 'Open menu',
                  child: IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(
                      Icons.menu,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _logLockout() {
    LockoutService().logLockout(failureErrors: List.from(_recentErrors));
    _recentErrors.clear();
  }

  Widget _buildDrawer(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            accountName: Text(user?.displayName ?? 'User'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person, size: 36)
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Camera'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Pick from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickFromGallery();
            },
          ),
          ListTile(
            leading: const Icon(Icons.burst_mode_outlined),
            title: const Text('Bulk Gallery Scan'),
            subtitle: const Text('Trader plan only'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BulkGalleryScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Sample Images'),
            subtitle: const Text('Try without a car nearby'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SampleImagesScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('Saved Scans'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SavedScansScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Favourites'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SavedScansScreen(showFavouritesTab: true),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.garage_outlined),
            title: const Text('My Garage'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GarageScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.message_outlined),
            title: const Text('Messages'),
            subtitle: const Text('Contact admin'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MessagesScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Plans & Pricing'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PricingScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLockoutScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 72, color: Colors.red[400]),
              const SizedBox(height: 20),
              const Text(
                'We\'re sorry',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'We are experiencing a technical issue and '
                'cannot process your request right now.\n\n'
                'Please try again later. You have not been charged.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _lockedOut = false;
                    _consecutiveFailures = 0;
                    _recentErrors.clear();
                    _status = 'Point at a UK car and tap capture';
                  });
                },
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller?.dispose();
    _detector.dispose();
    super.dispose();
  }
}
