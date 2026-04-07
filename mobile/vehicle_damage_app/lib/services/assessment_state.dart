/// State management for the assessment workflow

import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import '../models/damage_models.dart';

enum AssessmentStatus {
  idle,
  capturing,
  uploading,
  analyzing,
  estimatingCost,
  generatingReport,
  complete,
  error,
}

class AssessmentState extends ChangeNotifier {
  // Current status
  AssessmentStatus _status = AssessmentStatus.idle;
  AssessmentStatus get status => _status;
  
  // Image bytes (web-compatible)
  Uint8List? _imageBytes;
  Uint8List? get imageBytes => _imageBytes;
  String? _imageName;
  String? get imageName => _imageName;
  
  // Detection results
  DamageDetectionResponse? _detectionResult;
  DamageDetectionResponse? get detectionResult => _detectionResult;
  
  // Cost estimation
  CostEstimationResponse? _costEstimation;
  CostEstimationResponse? get costEstimation => _costEstimation;
  
  // Report
  ReportResponse? _report;
  ReportResponse? get report => _report;
  
  // Error message
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  // Progress message
  String _progressMessage = '';
  String get progressMessage => _progressMessage;
  
  /// Set the selected image bytes (web-compatible)
  void setImageBytes(Uint8List bytes, String name) {
    _imageBytes = bytes;
    _imageName = name;
    _status = AssessmentStatus.idle;
    _detectionResult = null;
    _costEstimation = null;
    _report = null;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Clear current image and results
  void clear() {
    _imageBytes = null;
    _imageName = null;
    _detectionResult = null;
    _costEstimation = null;
    _report = null;
    _errorMessage = null;
    _status = AssessmentStatus.idle;
    _progressMessage = '';
    notifyListeners();
  }
  
  /// Update status
  void setStatus(AssessmentStatus status, {String? message}) {
    _status = status;
    _progressMessage = message ?? '';
    
    if (status == AssessmentStatus.error) {
      _errorMessage = message;
    }
    
    notifyListeners();
  }
  
  /// Set detection result
  void setDetectionResult(DamageDetectionResponse result) {
    _detectionResult = result;
    notifyListeners();
  }
  
  /// Set cost estimation
  void setCostEstimation(CostEstimationResponse cost) {
    _costEstimation = cost;
    notifyListeners();
  }
  
  /// Set report
  void setReport(ReportResponse report) {
    _report = report;
    _status = AssessmentStatus.complete;
    notifyListeners();
  }
  
  /// Set error
  void setError(String message) {
    _errorMessage = message;
    _status = AssessmentStatus.error;
    notifyListeners();
  }
  
  /// Check if assessment is in progress
  bool get isProcessing => 
      _status == AssessmentStatus.uploading ||
      _status == AssessmentStatus.analyzing ||
      _status == AssessmentStatus.estimatingCost ||
      _status == AssessmentStatus.generatingReport;
  
  /// Check if we have results
  bool get hasResults => _detectionResult != null;
  
  /// Check if we have detected damages
  bool get hasDamages => 
      _detectionResult != null && _detectionResult!.numDetections > 0;
  
  /// Get damage count
  int get damageCount => _detectionResult?.numDetections ?? 0;
  
  /// Get total estimated cost
  double? get totalCost => _costEstimation?.totalCost;
  
  /// Get overall severity
  String? get overallSeverity => _report?.assessmentSummary.overallSeverity;
}
