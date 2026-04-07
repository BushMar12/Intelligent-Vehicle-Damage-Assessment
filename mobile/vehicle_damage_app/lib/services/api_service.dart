/// API Service for communicating with the Vehicle Damage Assessment backend

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/damage_models.dart';

class ApiService {
  // Base URL - configure for your environment
  // For local development: http://localhost:8000
  // For Android emulator: http://10.0.2.2:8000
  // For iOS simulator: http://localhost:8000
  // For AWS SageMaker: https://your-sagemaker-endpoint.amazonaws.com
  
  static const String _baseUrl = 'http://localhost:8000';
  
  final http.Client _client = http.Client();
  
  /// Set a custom base URL
  String baseUrl = _baseUrl;
  
  /// Headers for API requests
  Map<String, String> get _headers => {
    'Accept': 'application/json',
  };
  
  /// Detect damage from image bytes (web-compatible)
  Future<DamageDetectionResponse> detectDamageBytes({
    required Uint8List bytes,
    required String filename,
    double confThreshold = 0.25,
    bool returnAnnotated = true,
  }) async {
    final uri = Uri.parse('$baseUrl/damage/predict')
        .replace(queryParameters: {
          'conf_threshold': confThreshold.toString(),
          'return_annotated': returnAnnotated.toString(),
        });
    
    final request = http.MultipartRequest('POST', uri);
    
    // Add the image bytes
    final extension = filename.split('.').last.toLowerCase();
    
    MediaType? mediaType;
    if (extension == 'jpg' || extension == 'jpeg') {
      mediaType = MediaType('image', 'jpeg');
    } else if (extension == 'png') {
      mediaType = MediaType('image', 'png');
    } else if (extension == 'webp') {
      mediaType = MediaType('image', 'webp');
    }
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: mediaType,
      ),
    );
    
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return DamageDetectionResponse.fromJson(json);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to detect damage: ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
      );
    }
  }
  
  /// Detect damage from base64 encoded image
  Future<DamageDetectionResponse> detectDamageBase64({
    required String base64Image,
    double confThreshold = 0.25,
    bool returnAnnotated = true,
  }) async {
    final uri = Uri.parse('$baseUrl/damage/predict/base64');
    
    final body = jsonEncode({
      'image_base64': base64Image,
      'conf_threshold': confThreshold,
      'return_annotated': returnAnnotated,
    });
    
    try {
      final response = await _client.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: body,
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return DamageDetectionResponse.fromJson(json);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to detect damage: ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
      );
    }
  }
  
  /// Estimate repair costs
  Future<CostEstimationResponse> estimateCost({
    required List<Detection> detections,
    bool includeLabor = true,
    String currency = 'USD',
  }) async {
    final uri = Uri.parse('$baseUrl/cost/predict');
    
    final body = jsonEncode({
      'detections': detections.map((d) => d.toJson()).toList(),
      'include_labor': includeLabor,
      'currency': currency,
    });
    
    try {
      final response = await _client.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: body,
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return CostEstimationResponse.fromJson(json);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to estimate cost: ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
      );
    }
  }
  
  /// Generate assessment report
  Future<ReportResponse> generateReport({
    required List<Detection> detections,
    CostEstimationResponse? costEstimation,
    Map<String, dynamic>? vehicleInfo,
    String reportFormat = 'json',
  }) async {
    final uri = Uri.parse('$baseUrl/report/generate');
    
    final body = jsonEncode({
      'detections': detections.map((d) => d.toJson()).toList(),
      'cost_estimation': costEstimation != null ? {
        'success': costEstimation.success,
        'message': costEstimation.message,
        'damages': costEstimation.damages.map((d) => {
          'damage_type': d.damageType,
          'severity': d.severity,
          'base_cost': d.baseCost,
          'severity_multiplier': d.severityMultiplier,
          'labor_hours': d.laborHours,
          'labor_cost': d.laborCost,
          'parts_cost': d.partsCost,
          'total_cost': d.totalCost,
        }).toList(),
        'subtotal': costEstimation.subtotal,
        'tax_rate': costEstimation.taxRate,
        'tax_amount': costEstimation.taxAmount,
        'total_cost': costEstimation.totalCost,
        'currency': costEstimation.currency,
        'estimate_range': costEstimation.estimateRange,
      } : null,
      'vehicle_info': vehicleInfo,
      'report_format': reportFormat,
    });
    
    try {
      final response = await _client.post(
        uri,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: body,
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return ReportResponse.fromJson(json);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to generate report: ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
      );
    }
  }
  
  /// Detect damage from video bytes (web-compatible)
  Future<VideoDetectionResponse> detectDamageVideoBytes({
    required Uint8List bytes,
    required String filename,
    double confThreshold = 0.25,
    int frameInterval = 30,
    int maxFrames = 50,
  }) async {
    final uri = Uri.parse('$baseUrl/damage/predict/video')
        .replace(queryParameters: {
          'conf_threshold': confThreshold.toString(),
          'frame_interval': frameInterval.toString(),
          'max_frames': maxFrames.toString(),
        });
    
    final request = http.MultipartRequest('POST', uri);
    
    // Determine media type from extension
    final extension = filename.split('.').last.toLowerCase();
    
    MediaType? mediaType;
    if (extension == 'mp4') {
      mediaType = MediaType('video', 'mp4');
    } else if (extension == 'avi') {
      mediaType = MediaType('video', 'x-msvideo');
    } else if (extension == 'mov') {
      mediaType = MediaType('video', 'quicktime');
    } else if (extension == 'mkv') {
      mediaType = MediaType('video', 'x-matroska');
    } else if (extension == 'webm') {
      mediaType = MediaType('video', 'webm');
    }
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: mediaType,
      ),
    );
    
    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return VideoDetectionResponse.fromJson(json);
      } else {
        throw ApiException(
          statusCode: response.statusCode,
          message: 'Failed to process video: ${response.body}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        statusCode: 0,
        message: 'Network error: $e',
      );
    }
  }
  
  /// Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Get damage classes
  Future<List<Map<String, dynamic>>> getDamageClasses() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/damage/classes'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(json['classes'] as List);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// Dispose client
  void dispose() {
    _client.close();
  }
}

/// Custom API Exception
class ApiException implements Exception {
  final int statusCode;
  final String message;
  
  ApiException({
    required this.statusCode,
    required this.message,
  });
  
  @override
  String toString() => 'ApiException($statusCode): $message';
}
