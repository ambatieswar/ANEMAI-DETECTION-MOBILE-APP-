import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/tflite_local_datasource.dart';
import '../core/security/encrypted_history_store.dart';
import '../features/reports/pdf_report_service.dart';
import '../features/screening/domain/screening_result.dart';
import '../services/image_validator.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;

  bool _isUsingFrontCamera = false;
  List<CameraDescription> _cameras = [];

  bool _isInitializing = true;
  bool _isCapturing = false;

  String? _errorMessage;
  Uint8List? _capturedImage;
  AnemiaPrediction? _prediction;

  final TFLiteLocalDataSource _dataSource = TFLiteLocalDataSource();
  final ImagePicker _imagePicker = ImagePicker();
  final ImageValidator _imageValidator = ImageValidator();
  final EncryptedHistoryStore _historyStore = EncryptedHistoryStore();
  final PdfReportService _reportService = PdfReportService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No camera was found on this device.');
      }

      CameraDescription selectedCamera = _cameras.first;

      for (final camera in _cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isUsingFrontCamera =
            selectedCamera.lensDirection == CameraLensDirection.front;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _errorMessage = 'Unable to initialize camera.\n\n$e';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isCapturing || _isInitializing) {
      return;
    }

    final targetFront = !_isUsingFrontCamera;

    final matchingCameras = _cameras.where(
      (camera) => targetFront
          ? camera.lensDirection == CameraLensDirection.front
          : camera.lensDirection == CameraLensDirection.back,
    );

    if (matchingCameras.isEmpty) {
      setState(() {
        _errorMessage = targetFront
            ? 'No front-facing camera is available.'
            : 'No rear-facing camera is available.';
      });
      return;
    }

    final selectedCamera = matchingCameras.first;
    final oldController = _cameraController;

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    CameraController? newController;

    try {
      // Release the current camera before opening the other one.
      await oldController?.dispose();

      newController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await newController.initialize();

      if (!mounted) {
        await newController.dispose();
        return;
      }

      setState(() {
        _cameraController = newController;
        _isUsingFrontCamera =
            selectedCamera.lensDirection == CameraLensDirection.front;
        _isInitializing = false;
      });
    } catch (e) {
      await newController?.dispose();

      if (!mounted) return;

      setState(() {
        _cameraController = null;
        _isInitializing = false;
        _errorMessage = 'Unable to switch camera.\n\n$e';
      });
    }
  }

  Future<void> _pickTestImage() async {
    if (_isCapturing) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      setState(() {
        _capturedImage = bytes;
        _prediction = null;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to select image.\n\n$e';
      });
    }
  }

  Future<void> _captureImage() async {
    final controller = _cameraController;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        _isInitializing) {
      return;
    }

    try {
      setState(() {
        _isCapturing = true;
        _errorMessage = null;
      });

      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _capturedImage = bytes;
        _prediction = null;
        _isCapturing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _errorMessage = 'Unable to capture image.\n\n$e';
      });
    }
  }

  void _retakeImage() {
    setState(() {
      _capturedImage = null;
      _prediction = null;
      _errorMessage = null;
    });
  }

  Future<void> _analyzeImage() async {
    final imageBytes = _capturedImage;

    if (imageBytes == null || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
      _prediction = null;
    });

    try {
      // First: check blur, brightness and the current eye validator.
      final validation = await _imageValidator.validate(imageBytes);

      if (!mounted) return;

      if (!validation.passed) {
        setState(() {
          _isCapturing = false;
          _errorMessage = validation.message;
        });

        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.image_not_supported_outlined,
              color: Colors.deepOrange,
              size: 42,
            ),
            title: const Text('Image Quality Check Failed'),
            content: Text(validation.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Try Again'),
              ),
            ],
          ),
        );

        return;
      }

      // Second: run the existing TFLite anemia model.
      final prediction = await _dataSource.predict(imageBytes);

      if (!mounted) return;

      setState(() {
        _prediction = prediction;
        _isCapturing = false;
        _errorMessage = null;
      });

      await _historyStore.append(
        ScreeningResult(
          label: prediction.label,
          riskProbability: prediction.riskProbability,
          qualityScore: 1,
          createdAt: DateTime.now(),
          heatmap: null,
          disclaimer: 'This application is an AI-assisted screening tool. '
              'It cannot diagnose anemia. Consult a qualified healthcare '
              'professional for laboratory confirmation.',
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _errorMessage = 'Image analysis failed. Please try again.\n\n$e';
      });
    }
  }

  Future<void> _exportReport() async {
    final image = _capturedImage;
    final prediction = _prediction;
    if (image == null || prediction == null) return;

    final patientIdController = TextEditingController(
      text: 'anonymous-${DateTime.now().millisecondsSinceEpoch}',
    );
    final patientId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report identifier'),
        content: TextField(
          controller: patientIdController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Patient ID',
            helperText: 'Use a non-identifying local ID.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, patientIdController.text.trim()),
            child: const Text('Create PDF'),
          ),
        ],
      ),
    );
    patientIdController.dispose();
    if (!mounted || patientId == null || patientId.isEmpty) return;

    final result = ScreeningResult(
      label: prediction.label,
      riskProbability: prediction.riskProbability,
      qualityScore: 1,
      createdAt: DateTime.now(),
      heatmap: null,
      disclaimer: 'This application is an AI-assisted screening tool. '
          'It cannot diagnose anemia. Consult a qualified healthcare '
          'professional for laboratory confirmation.',
    );
    await _reportService.shareReport(
      patientId: patientId,
      result: result,
      eyeImage: image,
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _dataSource.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FC),
      appBar: AppBar(
        title: const Text(
          'AI Anemia Screening',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(child: _buildMainContent()),
              const SizedBox(height: 16),
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isInitializing) {
      return _buildLoadingView();
    }

    if (_capturedImage != null) {
      return _buildCapturedImageView();
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return _buildCameraPreview();
  }

  Widget _buildLoadingView() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(25),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Starting camera...',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return _buildErrorView();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
          _buildCameraOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraOverlay() {
    return Stack(
      children: [
        IgnorePointer(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Position the eye/conjunctiva area clearly',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const Spacer(),
              Container(
                width: 220,
                height: 140,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Use clear focus and even lighting',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const SizedBox(height: 20),
            ],
          ),
        ),
        if (_cameras.length > 1)
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Switch camera',
                onPressed:
                    _isInitializing || _isCapturing ? null : _switchCamera,
                icon: const Icon(
                  Icons.flip_camera_android,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCapturedImageView() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Image.memory(
                _capturedImage!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text(
                      'Unable to display this image.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _buildMessageCard(
            _errorMessage!,
            Icons.warning_amber_rounded,
            Colors.deepOrange,
          ),
        ],
        if (_prediction != null) ...[
          const SizedBox(height: 12),
          _buildPredictionCard(),
        ],
      ],
    );
  }

  Widget _buildMessageCard(
    String message,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  Widget _buildPredictionCard() {
    final prediction = _prediction!;
    final isIncreasedRisk = prediction.suggestsIncreasedRisk;
    final color = isIncreasedRisk ? Colors.deepOrange : Colors.teal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isIncreasedRisk
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: color,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  prediction.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Risk score: '
            '${(prediction.riskProbability * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'This experimental result is not a medical diagnosis. '
            'It cannot confirm or rule out anemia. Consult a '
            'qualified healthcare professional for assessment and '
            'appropriate blood testing.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 48,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera unavailable',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'An unexpected error occurred.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isInitializing = true;
                  });
                  _initializeCamera();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry camera'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    if (_capturedImage != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isCapturing ? null : _retakeImage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isCapturing ? null : _analyzeImage,
                  icon: _isCapturing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: Text(
                    _isCapturing ? 'Checking...' : 'Analyze',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCapturing ? null : _exportReport,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export encrypted local report as PDF'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isCapturing ? null : _pickTestImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose another image'),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isInitializing || _isCapturing ? null : _captureImage,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Capture Image'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isInitializing || _isCapturing ? null : _pickTestImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Test Image from Gallery'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
