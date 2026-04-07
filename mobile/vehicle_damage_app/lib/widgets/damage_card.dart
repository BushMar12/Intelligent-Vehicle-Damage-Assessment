/// Reusable damage detection card widget

import 'package:flutter/material.dart';
import '../models/damage_models.dart';

class DamageCard extends StatelessWidget {
  final Detection detection;
  final int index;
  final VoidCallback? onTap;

  const DamageCard({
    super.key,
    required this.detection,
    required this.index,
    this.onTap,
  });

  Color get _damageColor {
    switch (detection.className.toLowerCase()) {
      case 'dent':
        return const Color(0xFFE53935); // Red
      case 'scratch':
        return const Color(0xFF43A047); // Green
      case 'crack':
        return const Color(0xFF1E88E5); // Blue
      case 'glass shatter':
      case 'glass_shatter':
        return const Color(0xFFFDD835); // Yellow
      case 'lamp broken':
      case 'lamp_broken':
        return const Color(0xFF8E24AA); // Purple
      case 'tire flat':
      case 'tire_flat':
        return const Color(0xFF00ACC1); // Cyan
      default:
        return Colors.grey;
    }
  }

  IconData get _damageIcon {
    switch (detection.className.toLowerCase()) {
      case 'dent':
        return Icons.car_crash;
      case 'scratch':
        return Icons.format_paint;
      case 'crack':
        return Icons.broken_image;
      case 'glass shatter':
      case 'glass_shatter':
        return Icons.window;
      case 'lamp broken':
      case 'lamp_broken':
        return Icons.lightbulb_outline;
      case 'tire flat':
      case 'tire_flat':
        return Icons.tire_repair;
      default:
        return Icons.warning;
    }
  }

  String get _formattedName {
    return detection.className
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final confidencePercent = (detection.confidence * 100).toStringAsFixed(1);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _damageColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Index badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _damageColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    _damageIcon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Damage info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formattedName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _damageColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.analytics,
                          label: '$confidencePercent%',
                        ),
                        if (detection.severity != null) ...[
                          const SizedBox(width: 8),
                          _SeverityChip(severity: detection.severity!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Chevron
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final String severity;

  const _SeverityChip({required this.severity});

  Color get _color {
    switch (severity.toLowerCase()) {
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'minor':
        return Colors.yellow[700]!;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.5)),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: _color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
