/// Cost breakdown visualization widget

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/damage_models.dart';

class CostBreakdownWidget extends StatelessWidget {
  final CostEstimationResponse cost;
  final bool showDetails;

  const CostBreakdownWidget({
    super.key,
    required this.cost,
    this.showDetails = true,
  });

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: cost.currency == 'USD' ? '\$' : cost.currency,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with total
        _TotalCostHeader(
          total: cost.totalCost,
          currency: cost.currency,
          estimateRange: cost.estimateRange,
        ),
        
        if (showDetails) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          // Individual damage costs
          Text(
            'Cost Breakdown',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          ...cost.damages.map((damage) => _DamageCostRow(
            damage: damage,
            formatCurrency: _formatCurrency,
          )),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          
          // Subtotal
          _CostRow(
            label: 'Subtotal',
            value: _formatCurrency(cost.subtotal),
          ),
          const SizedBox(height: 8),
          
          // Tax
          _CostRow(
            label: 'Tax (${(cost.taxRate * 100).toStringAsFixed(0)}%)',
            value: _formatCurrency(cost.taxAmount),
            isSecondary: true,
          ),
          
          const SizedBox(height: 12),
          const Divider(thickness: 2),
          const SizedBox(height: 12),
          
          // Final total
          _CostRow(
            label: 'Total Estimate',
            value: _formatCurrency(cost.totalCost),
            isBold: true,
            isPrimary: true,
          ),
        ],
      ],
    );
  }
}

class _TotalCostHeader extends StatelessWidget {
  final double total;
  final String currency;
  final Map<String, double> estimateRange;

  const _TotalCostHeader({
    required this.total,
    required this.currency,
    required this.estimateRange,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      symbol: currency == 'USD' ? '\$' : currency,
      decimalDigits: 0,
    );
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Estimated Repair Cost',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatter.format(total),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Range: ${formatter.format(estimateRange['low'])} - ${formatter.format(estimateRange['high'])}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DamageCostRow extends StatelessWidget {
  final DamageCostItem damage;
  final String Function(double) formatCurrency;

  const _DamageCostRow({
    required this.damage,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 16, bottom: 12),
      title: Row(
        children: [
          Expanded(
            child: Text(
              damage.damageType.replaceAll('_', ' ').toUpperCase(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            formatCurrency(damage.totalCost),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      children: [
        _DetailRow('Base Cost', formatCurrency(damage.baseCost)),
        _DetailRow('Severity (${damage.severity})', '×${damage.severityMultiplier.toStringAsFixed(1)}'),
        _DetailRow('Labor (${damage.laborHours}h)', formatCurrency(damage.laborCost)),
        _DetailRow('Parts', formatCurrency(damage.partsCost)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isPrimary;
  final bool isSecondary;

  const _CostRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isPrimary = false,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isSecondary ? Colors.grey[600] : null,
            fontSize: isPrimary ? 16 : null,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isPrimary ? Theme.of(context).colorScheme.primary : null,
            fontSize: isPrimary ? 18 : null,
          ),
        ),
      ],
    );
  }
}
