/// Results Screen - Display damage detection and cost estimation results

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/damage_models.dart';
import '../services/assessment_state.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AssessmentState>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
        ],
      ),
      body: state.hasResults
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Annotated image
                  _AnnotatedImageCard(state: state),
                  const SizedBox(height: 16),
                  
                  // Summary card
                  if (state.report != null)
                    _SummaryCard(summary: state.report!.assessmentSummary),
                  const SizedBox(height: 16),
                  
                  // Detections list
                  if (state.hasDamages)
                    _DetectionsCard(detections: state.detectionResult!.detections),
                  const SizedBox(height: 16),
                  
                  // Cost estimation
                  if (state.costEstimation != null)
                    _CostCard(cost: state.costEstimation!),
                  const SizedBox(height: 16),
                  
                  // Recommendations
                  if (state.report != null)
                    _RecommendationsCard(summary: state.report!.assessmentSummary),
                  
                  const SizedBox(height: 32),
                  
                  // New assessment button
                  OutlinedButton.icon(
                    onPressed: () {
                      state.clear();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('New Assessment'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            )
          : const Center(
              child: Text('No results available'),
            ),
    );
  }
}

class _AnnotatedImageCard extends StatelessWidget {
  final AssessmentState state;
  
  const _AnnotatedImageCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final annotatedImage = state.detectionResult?.annotatedImage;
    final originalBytes = state.imageBytes;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image
          if (annotatedImage != null)
            Image.memory(
              base64Decode(annotatedImage),
              fit: BoxFit.contain,
            )
          else if (originalBytes != null)
            Image.memory(
              originalBytes,
              fit: BoxFit.contain,
            ),
          
          // Stats row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Damages',
                  value: '${state.damageCount}',
                  icon: Icons.warning_amber,
                  color: state.damageCount > 0 ? Colors.orange : Colors.green,
                ),
                _StatItem(
                  label: 'Inference',
                  value: '${state.detectionResult?.inferenceTimeMs.toStringAsFixed(0) ?? '-'}ms',
                  icon: Icons.speed,
                  color: Colors.blue,
                ),
                if (state.totalCost != null)
                  _StatItem(
                    label: 'Est. Cost',
                    value: '\$${state.totalCost!.toStringAsFixed(0)}',
                    icon: Icons.attach_money,
                    color: Colors.green,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
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

class _SummaryCard extends StatelessWidget {
  final AssessmentSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    Color severityColor;
    IconData severityIcon;
    
    switch (summary.overallSeverity) {
      case 'severe':
        severityColor = Colors.red;
        severityIcon = Icons.error;
        break;
      case 'moderate':
        severityColor = Colors.orange;
        severityIcon = Icons.warning;
        break;
      case 'minor':
        severityColor = Colors.yellow[700]!;
        severityIcon = Icons.info;
        break;
      default:
        severityColor = Colors.green;
        severityIcon = Icons.check_circle;
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(severityIcon, color: severityColor),
                const SizedBox(width: 8),
                Text(
                  'Overall Severity: ${summary.overallSeverity.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: severityColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              summary.summaryText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            // Safety notes
            if (summary.safetyNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Safety Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...summary.safetyNotes.map((note) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        note,
                        style: TextStyle(color: Colors.red[900], fontSize: 13),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetectionsCard extends StatelessWidget {
  final List<Detection> detections;

  const _DetectionsCard({required this.detections});
  
  Color _getDamageColor(String className) {
    switch (className) {
      case 'dent':
        return Colors.red;
      case 'scratch':
        return Colors.green;
      case 'crack':
        return Colors.blue;
      case 'glass_shatter':
        return Colors.yellow[700]!;
      case 'lamp_broken':
        return Colors.purple;
      case 'tire_flat':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            ...detections.asMap().entries.map((entry) {
              final index = entry.key;
              final det = entry.value;
              return _DetectionItem(
                index: index + 1,
                detection: det,
                color: _getDamageColor(det.className),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DetectionItem extends StatelessWidget {
  final int index;
  final Detection detection;
  final Color color;

  const _DetectionItem({
    required this.index,
    required this.detection,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final confidencePercent = (detection.confidence * 100).toStringAsFixed(1);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 16,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detection.className.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  'Confidence: $confidencePercent%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (detection.severity != null)
            Chip(
              label: Text(
                detection.severity!,
                style: const TextStyle(fontSize: 11),
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  final CostEstimationResponse cost;

  const _CostCard({required this.cost});
  
  String _formatCurrency(double amount, String currency) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost Estimation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Cost breakdown
            ...cost.damages.map((damage) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    damage.damageType.replaceAll('_', ' '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    _formatCurrency(damage.totalCost, cost.currency),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )),
            
            const Divider(),
            
            // Subtotal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text(_formatCurrency(cost.subtotal, cost.currency)),
              ],
            ),
            const SizedBox(height: 4),
            
            // Tax
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tax (${(cost.taxRate * 100).toStringAsFixed(0)}%)'),
                Text(_formatCurrency(cost.taxAmount, cost.currency)),
              ],
            ),
            
            const Divider(thickness: 2),
            
            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatCurrency(cost.totalCost, cost.currency),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Estimate range
            Container(
              padding: const EdgeInsets.all(12),
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
                    'Estimate Range: ${_formatCurrency(cost.estimateRange['low']!, cost.currency)} - ${_formatCurrency(cost.estimateRange['high']!, cost.currency)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
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

class _RecommendationsCard extends StatelessWidget {
  final AssessmentSummary summary;

  const _RecommendationsCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.recommendedActions.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommended Actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...summary.recommendedActions.asMap().entries.map((entry) {
              final index = entry.key;
              final action = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(action),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
