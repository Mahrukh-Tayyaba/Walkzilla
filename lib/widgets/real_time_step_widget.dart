import 'package:flutter/material.dart';
import 'dart:async';
import '../services/step_counter_service.dart';
import '../services/health_service.dart';

class RealTimeStepWidget extends StatefulWidget {
  const RealTimeStepWidget({Key? key}) : super(key: key);

  @override
  State<RealTimeStepWidget> createState() => _RealTimeStepWidgetState();
}

class _RealTimeStepWidgetState extends State<RealTimeStepWidget> {
  final HealthService _healthService = HealthService();
  int _currentSteps = 0;
  bool _isTracking = false;
  bool _sensorAvailable = false;
  StreamSubscription<Map<String, dynamic>>? _stepSubscription;

  @override
  void initState() {
    super.initState();
    _initializeStepTracking();
  }

  Future<void> _initializeStepTracking() async {
    try {
      // Check sensor availability
      final available = await StepCounterService.isSensorAvailable();
      setState(() {
        _sensorAvailable = available;
      });

      if (available) {
        // Start hybrid monitoring
        await _healthService.startHybridMonitoring();

        // Listen to step updates
        _stepSubscription = StepCounterService.stepStream.listen(
          (data) {
            if (data['type'] == 'step_update') {
              setState(() {
                _currentSteps = data['currentSteps'] as int;
                _isTracking = true;
              });
            } else if (data['type'] == 'sensor_status') {
              setState(() {
                _sensorAvailable = data['available'] as bool;
              });
            }
          },
          onError: (error) {
            print('Error in step stream: $error');
          },
        );
      }
    } catch (e) {
      print('Error initializing step tracking: $e');
    }
  }

  @override
  void dispose() {
    _stepSubscription?.cancel();
    super.dispose();
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
                Icon(
                  _isTracking
                      ? Icons.directions_walk
                      : Icons.directions_walk_outlined,
                  color: _isTracking ? Colors.green : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Real-Time Steps',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sensorAvailable ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _sensorAvailable ? 'Sensor Ready' : 'No Sensor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_currentSteps',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _isTracking ? Colors.green : Colors.grey,
                            ),
                      ),
                      Text(
                        'steps since app start',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                if (_isTracking)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sensorAvailable ? _toggleTracking : null,
                    icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
                    label: Text(_isTracking ? 'Pause' : 'Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isTracking ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _resetSteps,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleTracking() async {
    if (_isTracking) {
      await StepCounterService.stopTracking();
      setState(() {
        _isTracking = false;
      });
    } else {
      await StepCounterService.startTracking();
      setState(() {
        _isTracking = true;
      });
    }
  }

  void _resetSteps() {
    StepCounterService.resetCounter();
    setState(() {
      _currentSteps = 0;
    });
  }
}
