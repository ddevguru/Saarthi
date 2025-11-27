/**
 * SAARTHI Flutter App - Smart AI Card Widget
 * Shows intelligent insights and proactive suggestions
 */

import 'package:flutter/material.dart';
import '../../data/services/smart_ai_service.dart';
import '../../core/app_theme.dart';

class SmartAICard extends StatefulWidget {
  final SmartAIService smartAI;
  
  const SmartAICard({
    super.key,
    required this.smartAI,
  });

  @override
  State<SmartAICard> createState() => _SmartAICardState();
}

class _SmartAICardState extends State<SmartAICard> {
  Map<String, dynamic>? _analysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final analysis = await widget.smartAI.analyzeSituation();
      setState(() {
        _analysis = analysis;
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'LOW':
        return AppTheme.secondaryColor;
      case 'MEDIUM':
        return AppTheme.warningColor;
      case 'HIGH':
        return AppTheme.dangerColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text(
                'Analyzing situation...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_analysis == null) {
      return const SizedBox.shrink();
    }

    final riskLevel = _analysis!['risk_level'] as String;
    final recommendations = _analysis!['recommendations'] as List<String>;
    final alerts = _analysis!['alerts'] as List<String>;

    return Card(
      color: _getRiskColor(riskLevel).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: _getRiskColor(riskLevel),
                ),
                const SizedBox(width: 8),
                Text(
                  'Smart AI Analysis',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRiskColor(riskLevel),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    riskLevel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (alerts.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...alerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )),
            ],
            if (recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Recommendations:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rec,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _loadAnalysis,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

