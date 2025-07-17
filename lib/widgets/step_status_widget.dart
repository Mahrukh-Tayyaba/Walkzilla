import 'package:flutter/material.dart';
import '../services/health_service.dart';
import '../services/step_counter_service.dart';

class StepStatusWidget extends StatefulWidget {
  const StepStatusWidget({Key? key}) : super(key: key);

  @override
  State<StepStatusWidget> createState() => _StepStatusWidgetState();
}

class _StepStatusWidgetState extends State<StepStatusWidget> {
  final HealthService _healthService = HealthService();
  bool _isRealTimeActive = false;
  bool _sensorAvailable = false;
  int _baseline = 0;
  int _realTimeSteps = 0;
  int _unifiedSteps = 0;

  @override
  void initState() {
    super.initState();
    _updateStatus();
  }

  Future<void> _updateStatus() async {
    try {
      final realTimeActive = _healthService.isRealTimeTrackingActive;
      final sensorAvailable = await StepCounterService.isSensorAvailable();
      final baseline = _healthService.healthConnectBaseline;
      final realTimeSteps = StepCounterService.currentSteps;
      final unifiedSteps = await _healthService.fetchHybridStepsData();

      setState(() {
        _isRealTimeActive = realTimeActive;
        _sensorAvailable = sensorAvailable;
        _baseline = baseline;
        _realTimeSteps = realTimeSteps;
        _unifiedSteps = unifiedSteps;
      });
    } catch (e) {
      print('Error updating status: $e');
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
                Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Step Tracking Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _updateStatus,
                  icon: Icon(Icons.refresh),
                  tooltip: 'Refresh Status',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow(
                'Real-time Tracking', _isRealTimeActive, Colors.green),
            _buildStatusRow('Sensor Available', _sensorAvailable, Colors.blue),
            _buildStatusRow('Baseline Set', _baseline > 0, Colors.orange),
            const Divider(),
            _buildInfoRow('Baseline Steps', _baseline, Colors.orange),
            _buildInfoRow('Real-time Steps', _realTimeSteps, Colors.green),
            _buildInfoRow('Unified Total', _unifiedSteps, Colors.purple,
                isBold: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _healthService.forceRefreshStepCount();
                      _updateStatus();
                    },
                    child: Text('Force Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _healthService.resetBaseline();
                      _updateStatus();
                    },
                    child: Text('Reset Baseline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
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

  Widget _buildStatusRow(String label, bool status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? color : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            status ? 'Active' : 'Inactive',
            style: TextStyle(
              color: status ? color : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
