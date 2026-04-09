/// Video Results Screen - Display video analysis results

import 'dart:convert';
import 'package:flutter/material.dart';

import '../models/damage_models.dart';
import 'chat_screen.dart';

class VideoResultsScreen extends StatefulWidget {
  final VideoDetectionResponse videoResult;
  final CostEstimationResponse costResult;
  final ReportResponse? reportResult;

  const VideoResultsScreen({
    super.key,
    required this.videoResult,
    required this.costResult,
    this.reportResult,
  });

  @override
  State<VideoResultsScreen> createState() => _VideoResultsScreenState();
}

class _VideoResultsScreenState extends State<VideoResultsScreen> {
  int _selectedFrameIndex = 0;

  @override
  Widget build(BuildContext context) {
    final result = widget.videoResult;
    final cost = widget.costResult;
    final report = widget.reportResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Analysis Results'),
      ),
      floatingActionButton: report != null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(assessmentId: report.reportId),
                  ),
                );
              },
              icon: const Icon(Icons.smart_toy_outlined),
              label: const Text('Ask AI'),
            )
          : null,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Card
              _SummaryCard(result: result, cost: cost),
              const SizedBox(height: 16),

              // Video Info
              _VideoInfoCard(result: result),
              const SizedBox(height: 16),

              // Detected Damages
              _DetectedDamagesCard(detections: result.aggregatedDetections),
              const SizedBox(height: 16),

              // Cost Breakdown
              _CostBreakdownCard(cost: cost),
              const SizedBox(height: 16),

              // Key Frames
              if (result.frameResults.isNotEmpty) ...[
                Text(
                  'Key Frames with Detections',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                _KeyFramesSection(
                  frameResults: result.frameResults,
                  selectedIndex: _selectedFrameIndex,
                  onFrameSelected: (index) {
                    setState(() => _selectedFrameIndex = index);
                  },
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final VideoDetectionResponse result;
  final CostEstimationResponse cost;

  const _SummaryCard({required this.result, required this.cost});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Analysis Complete',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.warning_amber,
                  value: '${result.uniqueDetections}',
                  label: 'Damages Found',
                  color: Colors.orange,
                ),
                _StatItem(
                  icon: Icons.movie,
                  value: '${result.framesAnalyzed}',
                  label: 'Frames Analyzed',
                  color: Colors.blue,
                ),
                _StatItem(
                  icon: Icons.attach_money,
                  value: '\$${cost.totalCost.toStringAsFixed(0)}',
                  label: 'Est. Cost (AUD)',
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }
}

class _VideoInfoCard extends StatelessWidget {
  final VideoDetectionResponse result;

  const _VideoInfoCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Duration', value: '${result.durationSec.toStringAsFixed(1)}s'),
            _InfoRow(label: 'FPS', value: result.fps.toStringAsFixed(1)),
            _InfoRow(label: 'Total Frames', value: '${result.totalFrames}'),
            _InfoRow(label: 'Frames Analyzed', value: '${result.framesAnalyzed}'),
            _InfoRow(
              label: 'Processing Time',
              value: '${(result.totalInferenceTimeMs / 1000).toStringAsFixed(2)}s',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DetectedDamagesCard extends StatelessWidget {
  final List<Detection> detections;

  const _DetectedDamagesCard({required this.detections});

  Color _getDamageColor(String className) {
    switch (className.toLowerCase()) {
      case 'dent':
        return Colors.red;
      case 'scratch':
        return Colors.orange;
      case 'crack':
        return Colors.purple;
      case 'glass shatter':
        return Colors.blue;
      case 'lamp broken':
        return Colors.amber;
      case 'tire flat':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detected Damages',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (detections.isEmpty)
              const Text('No damages detected')
            else
              ...detections.map((d) => _DamageItem(
                    detection: d,
                    color: _getDamageColor(d.className),
                  )),
          ],
        ),
      ),
    );
  }
}

class _DamageItem extends StatelessWidget {
  final Detection detection;
  final Color color;

  const _DamageItem({required this.detection, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detection.className.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  'Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (detection.severity != null)
            Chip(
              label: Text(
                detection.severity!.toUpperCase(),
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: color.withOpacity(0.2),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
    );
  }
}

class _CostBreakdownCard extends StatelessWidget {
  final CostEstimationResponse cost;

  const _CostBreakdownCard({required this.cost});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost Estimate (AUD)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...cost.damages.map((d) => _CostRow(
                  label: d.damageType.toUpperCase(),
                  value: '\$${d.totalCost.toStringAsFixed(2)}',
                )),
            const Divider(),
            _CostRow(
              label: 'Subtotal',
              value: '\$${cost.subtotal.toStringAsFixed(2)}',
            ),
            _CostRow(
              label: 'GST (${(cost.taxRate * 100).toStringAsFixed(0)}%)',
              value: '\$${cost.taxAmount.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '\$${cost.totalCost.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Estimate range: \$${cost.estimateRange['low']?.toStringAsFixed(0)} - \$${cost.estimateRange['high']?.toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final String value;

  const _CostRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _KeyFramesSection extends StatelessWidget {
  final List<VideoFrameResult> frameResults;
  final int selectedIndex;
  final Function(int) onFrameSelected;

  const _KeyFramesSection({
    required this.frameResults,
    required this.selectedIndex,
    required this.onFrameSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thumbnail strip
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: frameResults.length,
            itemBuilder: (context, index) {
              final frame = frameResults[index];
              final isSelected = index == selectedIndex;
              
              return GestureDetector(
                onTap: () => onFrameSelected(index),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300]!,
                      width: isSelected ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (frame.annotatedFrame != null)
                          Image.memory(
                            base64Decode(frame.annotatedFrame!),
                            fit: BoxFit.cover,
                          )
                        else
                          Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${frame.timestampSec.toStringAsFixed(1)}s',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        
        // Selected frame preview
        if (frameResults.isNotEmpty && selectedIndex < frameResults.length)
          Card(
            child: Column(
              children: [
                if (frameResults[selectedIndex].annotatedFrame != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.memory(
                      base64Decode(frameResults[selectedIndex].annotatedFrame!),
                      fit: BoxFit.contain,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Frame ${frameResults[selectedIndex].frameNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${frameResults[selectedIndex].detections.length} damage(s) detected',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
