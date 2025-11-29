/**
 * SAARTHI Flutter App - Smart AI Card Widget
 * Shows intelligent insights and proactive suggestions
 */

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      // Get comprehensive AI analysis with all agents
      final analysis = await widget.smartAI.getComprehensiveAnalysis(
        await _getUserId(),
      );
      setState(() {
        _analysis = analysis;
      });
    } catch (e) {
      print('Error loading AI analysis: $e');
      // Fallback to basic analysis
      try {
        final basicAnalysis = await widget.smartAI.analyzeSituation();
        setState(() {
          _analysis = basicAnalysis;
        });
      } catch (e2) {
        print('Error loading basic analysis: $e2');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _getUserId() async {
    // Get user ID from shared preferences or API
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_id') ?? '';
    } catch (e) {
      return '';
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

    final riskLevel = _analysis!['risk_level'] as String? ?? 
                     (_analysis!['risk_assessment'] as Map?)?['risk_level'] ?? 
                     'LOW';
    final recommendations = (_analysis!['recommendations'] as List?)?.cast<String>() ?? 
                           <String>[];
    final alerts = (_analysis!['alerts'] as List?)?.cast<String>() ?? 
                  <String>[];
    final aiInsights = _analysis!['ai_insights'] as Map<String, dynamic>?;

    return Card(
      color: _getRiskColor(riskLevel).withValues(alpha: 0.1),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getRiskColor(riskLevel).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
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
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Smart AI Analysis',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
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
              Text(
                'Alerts:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warningColor,
                ),
              ),
              const SizedBox(height: 8),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
            if (recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text(
                'Recommendations:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
            if (aiInsights != null && aiInsights.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              Text(
                'AI Insights:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              if (aiInsights['health'] != null)
                _buildAIInsightItem(
                  context,
                  'Health',
                  aiInsights['health'] as Map<String, dynamic>,
                ),
              if (aiInsights['risk_assessment'] != null)
                _buildAIInsightItem(
                  context,
                  'Risk',
                  aiInsights['risk_assessment'] as Map<String, dynamic>,
                ),
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

  Widget _buildAIInsightItem(BuildContext context, String title, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.insights,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                if (data['risk_score'] != null)
                  Text(
                    'Risk Score: ${(data['risk_score'] as num).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

