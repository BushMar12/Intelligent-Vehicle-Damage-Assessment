/// Home Screen - Main entry point of the app

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/assessment_state.dart';
import '../models/damage_models.dart';
import 'results_screen.dart';
import 'video_results_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isConnected = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _checkConnection();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _checkConnection() async {
    final api = context.read<ApiService>();
    final connected = await api.healthCheck();
    if (mounted) {
      setState(() {
        _isConnected = connected;
      });
    }
  }
  
  Future<void> _saveToHistory(AssessmentState state) async {
    if (!state.hasResults) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('assessment_history') ?? [];
      
      final historyItem = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'thumbnail_name': state.imageName,
        'damage_count': state.damageCount,
        'damage_types': state.detectionResult?.detections
            .map((d) => d.className)
            .toSet()
            .toList() ?? [],
        'total_cost': state.totalCost,
        'severity': state.overallSeverity,
      };
      
      historyJson.insert(0, jsonEncode(historyItem));
      
      // Keep only last 50 items
      if (historyJson.length > 50) {
        historyJson.removeRange(50, historyJson.length);
      }
      
      await prefs.setStringList('assessment_history', historyJson);
    } catch (e) {
      debugPrint('Error saving to history: $e');
    }
  }
  
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      
      if (pickedFile != null) {
        // Read bytes for web compatibility
        final bytes = await pickedFile.readAsBytes();
        final filename = pickedFile.name;
        if (mounted) {
          context.read<AssessmentState>().setImageBytes(bytes, filename);
          _analyzeImageBytes(bytes, filename);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }
  
  Future<void> _analyzeImageBytes(Uint8List bytes, String filename) async {
    final api = context.read<ApiService>();
    final state = context.read<AssessmentState>();
    
    // Load settings
    final prefs = await SharedPreferences.getInstance();
    final confThreshold = prefs.getDouble('confidence_threshold') ?? 0.25;
    final returnAnnotated = prefs.getBool('return_annotated') ?? true;
    final includeLabor = prefs.getBool('include_labor') ?? true;
    final currency = prefs.getString('currency') ?? 'AUD';
    
    try {
      // Step 1: Detect damage
      state.setStatus(AssessmentStatus.analyzing, message: 'Analyzing image...');
      
      final detectionResult = await api.detectDamageBytes(
        bytes: bytes, 
        filename: filename,
        confThreshold: confThreshold,
        returnAnnotated: returnAnnotated,
      );
      state.setDetectionResult(detectionResult);
      
      if (detectionResult.numDetections > 0) {
        // Step 2: Estimate cost
        state.setStatus(AssessmentStatus.estimatingCost, message: 'Estimating costs...');
        
        final costResult = await api.estimateCost(
          detections: detectionResult.detections,
          includeLabor: includeLabor,
          currency: currency,
        );
        state.setCostEstimation(costResult);
        debugPrint('✓ Cost estimated: ${costResult.totalCost}');
        
        // Step 3: Generate report
        state.setStatus(AssessmentStatus.generatingReport, message: 'Generating report...');
        
        final reportResult = await api.generateReport(
          detections: detectionResult.detections,
          costEstimation: costResult,
        );
        debugPrint('✓ Report generated: ${reportResult.reportId}');
        state.setReport(reportResult);
        debugPrint('✓ state.report is now set: ${state.report?.reportId}');
      } else {
        // No damage—still generate report so Ask AI is available
        state.setStatus(AssessmentStatus.generatingReport, message: 'Generating report...');
        final reportResult = await api.generateReport(
          detections: [],
        );
        debugPrint('✓ No-damage report generated: ${reportResult.reportId}');
        state.setReport(reportResult);
      }
      
      // Save to history
      await _saveToHistory(state);
      
      // Navigate to results
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ResultsScreen()),
        );
      }
    } catch (e) {
      state.setError('Analysis failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          _analyzeVideo(file.bytes!, file.name);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }
  
  Future<void> _analyzeVideo(Uint8List bytes, String filename) async {
    final api = context.read<ApiService>();
    final state = context.read<AssessmentState>();
    
    // Load settings
    final prefs = await SharedPreferences.getInstance();
    final confThreshold = prefs.getDouble('confidence_threshold') ?? 0.25;
    final includeLabor = prefs.getBool('include_labor') ?? true;
    final currency = prefs.getString('currency') ?? 'AUD';
    
    try {
      state.setStatus(AssessmentStatus.analyzing, message: 'Processing video...');
      
      final videoResult = await api.detectDamageVideoBytes(
        bytes: bytes,
        filename: filename,
        confThreshold: confThreshold,
        frameInterval: 30,
        maxFrames: 50,
      );
      
      if (videoResult.uniqueDetections > 0) {
        // Estimate cost for aggregated detections
        state.setStatus(AssessmentStatus.estimatingCost, message: 'Estimating costs...');
        
        final costResult = await api.estimateCost(
          detections: videoResult.aggregatedDetections,
          includeLabor: includeLabor,
          currency: currency,
        );
        state.setCostEstimation(costResult);

        // Generate report so Ask AI is available
        state.setStatus(AssessmentStatus.generatingReport, message: 'Generating report...');
        final reportResult = await api.generateReport(
          detections: videoResult.aggregatedDetections,
          costEstimation: costResult,
        );
        state.setReport(reportResult);
        debugPrint('✓ Video report generated: \${reportResult.reportId}');
        
        state.setStatus(AssessmentStatus.complete, message: 'Analysis complete');
        
        // Navigate to video results
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VideoResultsScreen(
                videoResult: videoResult,
                costResult: costResult,
                reportResult: reportResult,
              ),
            ),
          );
        }
      } else {
        // No damage — still generate a report so Ask AI works
        state.setStatus(AssessmentStatus.generatingReport, message: 'Generating report...');
        final reportResult = await api.generateReport(
          detections: [],
        );
        state.setReport(reportResult);

        state.setStatus(AssessmentStatus.complete, message: 'No damage detected in video');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No damage detected in video')),
          );
        }
      }
    } catch (e) {
      state.setError('Video analysis failed: \$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: \$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AssessmentState>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
              const SizedBox(height: 40),
              Icon(
                Icons.car_crash_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Vehicle Damage\nAssessment',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI-powered damage detection and\nrepair cost estimation',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              
              // Connection status
              const SizedBox(height: 24),
              _ConnectionIndicator(isConnected: _isConnected, onRefresh: _checkConnection),
              
              const Spacer(),
              
              // Processing indicator
              if (state.isProcessing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  state.progressMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
              ],
              
              // Action buttons
              _ActionButton(
                icon: Icons.camera_alt,
                label: 'Take Photo',
                onPressed: state.isProcessing || !_isConnected
                    ? null
                    : () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.photo_library,
                label: 'Choose from Gallery',
                isPrimary: false,
                onPressed: state.isProcessing || !_isConnected
                    ? null
                    : () => _pickImage(ImageSource.gallery),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.videocam,
                label: 'Upload Video',
                isPrimary: false,
                onPressed: state.isProcessing || !_isConnected
                    ? null
                    : _pickVideo,
              ),
              
              const SizedBox(height: 24),
              
              // Feature list
              const _FeatureItem(
                icon: Icons.search,
                text: 'Detects 6 types of damage',
              ),
              const _FeatureItem(
                icon: Icons.attach_money,
                text: 'Estimates repair costs (AUD)',
              ),
              const _FeatureItem(
                icon: Icons.videocam,
                text: 'Supports images and videos',
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onRefresh;
  
  const _ConnectionIndicator({
    required this.isConnected,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.cloud_done : Icons.cloud_off,
            size: 16,
            color: isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'Connected to server' : 'Server unavailable',
            style: TextStyle(
              fontSize: 12,
              color: isConnected ? Colors.green[700] : Colors.red[700],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRefresh,
            child: Icon(
              Icons.refresh,
              size: 16,
              color: isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isPrimary = true,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
      );
    }
    
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
