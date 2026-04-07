/// Interactive image viewer with zoom and damage overlay

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/damage_models.dart';

class ImageViewer extends StatefulWidget {
  final File? imageFile;
  final String? base64Image;
  final List<Detection>? detections;
  final bool showOverlay;
  final bool enableZoom;

  const ImageViewer({
    super.key,
    this.imageFile,
    this.base64Image,
    this.detections,
    this.showOverlay = true,
    this.enableZoom = true,
  }) : assert(imageFile != null || base64Image != null);

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  final TransformationController _controller = TransformationController();
  int? _selectedDetection;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _controller.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    
    if (widget.base64Image != null) {
      imageWidget = Image.memory(
        base64Decode(widget.base64Image!),
        fit: BoxFit.contain,
      );
    } else {
      imageWidget = Image.file(
        widget.imageFile!,
        fit: BoxFit.contain,
      );
    }
    
    return Stack(
      children: [
        // Zoomable image
        widget.enableZoom
            ? InteractiveViewer(
                transformationController: _controller,
                minScale: 0.5,
                maxScale: 4.0,
                child: imageWidget,
              )
            : imageWidget,
        
        // Detection overlay
        if (widget.showOverlay && widget.detections != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: widget.detections!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final det = entry.value;
                    return _DetectionOverlay(
                      detection: det,
                      index: index,
                      isSelected: _selectedDetection == index,
                      onTap: () {
                        setState(() {
                          _selectedDetection = _selectedDetection == index ? null : index;
                        });
                      },
                      containerWidth: constraints.maxWidth,
                      containerHeight: constraints.maxHeight,
                    );
                  }).toList(),
                );
              },
            ),
          ),
        
        // Zoom controls
        if (widget.enableZoom)
          Positioned(
            right: 8,
            bottom: 8,
            child: Column(
              children: [
                _ZoomButton(
                  icon: Icons.zoom_in,
                  onPressed: () {
                    final currentScale = _controller.value.getMaxScaleOnAxis();
                    if (currentScale < 4.0) {
                      _controller.value = Matrix4.identity()
                        ..scale(currentScale * 1.5);
                    }
                  },
                ),
                const SizedBox(height: 4),
                _ZoomButton(
                  icon: Icons.zoom_out,
                  onPressed: () {
                    final currentScale = _controller.value.getMaxScaleOnAxis();
                    if (currentScale > 0.5) {
                      _controller.value = Matrix4.identity()
                        ..scale(currentScale / 1.5);
                    }
                  },
                ),
                const SizedBox(height: 4),
                _ZoomButton(
                  icon: Icons.fit_screen,
                  onPressed: _resetZoom,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetectionOverlay extends StatelessWidget {
  final Detection detection;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final double containerWidth;
  final double containerHeight;

  const _DetectionOverlay({
    required this.detection,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.containerWidth,
    required this.containerHeight,
  });

  Color get _color {
    switch (detection.className.toLowerCase()) {
      case 'dent':
        return const Color(0xFFE53935);
      case 'scratch':
        return const Color(0xFF43A047);
      case 'crack':
        return const Color(0xFF1E88E5);
      case 'glass shatter':
      case 'glass_shatter':
        return const Color(0xFFFDD835);
      case 'lamp broken':
      case 'lamp_broken':
        return const Color(0xFF8E24AA);
      case 'tire flat':
      case 'tire_flat':
        return const Color(0xFF00ACC1);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: Bounding box coordinates should be normalized (0-1) 
    // or absolute pixel values depending on your backend
    final bbox = detection.bbox;
    
    // If coordinates are already absolute pixels
    // final left = bbox.xMin;
    // final top = bbox.yMin;
    // final width = bbox.width;
    // final height = bbox.height;
    
    // If coordinates are normalized (0-1), uncomment below:
    final left = bbox.xMin * containerWidth;
    final top = bbox.yMin * containerHeight;
    final width = bbox.width * containerWidth;
    final height = bbox.height * containerHeight;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: _color,
              width: isSelected ? 3 : 2,
            ),
            color: isSelected ? _color.withOpacity(0.2) : Colors.transparent,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Label
              Positioned(
                top: -20,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              // Info popup when selected
              if (isSelected)
                Positioned(
                  bottom: -60,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          detection.className.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _color,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (detection.severity != null)
                          Text(
                            'Severity: ${detection.severity}',
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// Full screen image viewer dialog
class FullScreenImageViewer extends StatelessWidget {
  final File? imageFile;
  final String? base64Image;
  final List<Detection>? detections;

  const FullScreenImageViewer({
    super.key,
    this.imageFile,
    this.base64Image,
    this.detections,
  });

  static Future<void> show(
    BuildContext context, {
    File? imageFile,
    String? base64Image,
    List<Detection>? detections,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageFile: imageFile,
          base64Image: base64Image,
          detections: detections,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: ImageViewer(
          imageFile: imageFile,
          base64Image: base64Image,
          detections: detections,
          enableZoom: true,
        ),
      ),
    );
  }
}
