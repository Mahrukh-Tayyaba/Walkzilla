import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../services/step_counter_service.dart';

class StepDebugWidget extends StatefulWidget {
  const StepDebugWidget({Key? key}) : super(key: key);

  @override
  State<StepDebugWidget> createState() => _StepDebugWidgetState();
}

class _StepDebugWidgetState extends State<StepDebugWidget> {
  final HealthService _healthService = HealthService();
  int _healthConnectSteps = 0;
  int _realTimeSteps = 0;
  int _unifiedSteps = 0;
  int _baseline = 0;

  @override
  void initState() {
    super.initState();
    _updateStepData();
  }

  Future<void> _updateStepData() async {
    try {
      // Get individual components
      final healthSteps = await _healthService.fetchStepsData();
      final realTimeSteps = StepCounterService.currentSteps;
      final unifiedSteps = await _healthService.fetchHybridStepsData();
      final baseline = _healthService.healthConnectBaseline;

      setState(() {
        _healthConnectSteps = healthSteps;
        _realTimeSteps = realTimeSteps;
        _unifiedSteps = unifiedSteps;
        _baseline = baseline;
      });
    } catch (e) {
      print('Error updating step data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Step Debug Info',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _updateStepData,
                  icon: Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                'Health Connect Steps', _healthConnectSteps, Colors.blue),
            _buildInfoRow('Real-time Steps', _realTimeSteps, Colors.green),
            _buildInfoRow('Baseline', _baseline, Colors.orange),
            const Divider(),
            _buildInfoRow('Unified Total', _unifiedSteps, Colors.purple,
                isBold: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _healthService.resetBaseline();
                      _updateStepData();
                    },
                    child: Text('Reset Baseline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      StepCounterService.resetCounter();
                      _updateStepData();
                    },
                    child: Text('Reset Real-time'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, int value, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
