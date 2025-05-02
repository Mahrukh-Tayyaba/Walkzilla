import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class HealthPermissionDialog extends StatefulWidget {
  final Function(List<HealthDataType>, int?)? onAllow;
  final bool isPermissionNeeded;

  const HealthPermissionDialog({
    Key? key,
    this.onAllow,
    this.isPermissionNeeded = false,
  }) : super(key: key);

  @override
  State<HealthPermissionDialog> createState() => _HealthPermissionDialogState();
}

class _HealthPermissionDialogState extends State<HealthPermissionDialog> {
  bool allowAll = false;
  bool steps = false;
  bool distance = false;
  bool heartRate = false;
  bool calories = false;
  final health = Health();

  void updateAll(bool value) {
    setState(() {
      allowAll = value;
      steps = value;
      distance = value;
      heartRate = value;
      calories = value;
    });
  }

  void updateIndividual() {
    setState(() {
      allowAll = steps && distance && heartRate && calories;
    });
  }

  Future<void> requestGoogleFitAuthorization(List<HealthDataType> types) async {
    try {
      // First check if permissions are already granted
      bool? hasPermissions = await health.hasPermissions(types);

      if (hasPermissions == true) {
        return; // Already has permissions
      }

      // Request authorization
      bool granted = await health.requestAuthorization(types);

      if (!granted) {
        throw Exception('Health permissions not granted');
      }
    } catch (e) {
      print('Error requesting health permissions: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button at top-right
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.black54),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),

            // Heart Icon
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFFFF4EC),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                color: Color(0xFFFF7940),
                size: 32,
              ),
            ),
            SizedBox(height: 16),

            // Title
            Text(
              'Allow Walkzilla to access your fitness data?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),

            // Subtitle
            Text(
              'To track your steps, distance, heart rate, and calories burnt — and power your adventure!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 24),

            // Allow all switch
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Color(0xFFFFF4EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Allow all',
                    style: TextStyle(fontSize: 16),
                  ),
                  Switch(
                    value: allowAll,
                    onChanged: updateAll,
                    activeColor: Color(0xFFFF7940),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Permission section title
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Allow "Walkzilla" to read:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 8),

            // Permission items
            _buildPermissionItem(
              icon: Icons.monitor_heart_outlined,
              title: 'Steps',
              value: steps,
              onChanged: (val) {
                setState(() {
                  steps = val;
                  updateIndividual();
                });
              },
            ),
            _buildPermissionItem(
              icon: Icons.place_outlined,
              title: 'Distance',
              value: distance,
              onChanged: (val) {
                setState(() {
                  distance = val;
                  updateIndividual();
                });
              },
            ),
            _buildPermissionItem(
              icon: Icons.favorite_border,
              title: 'Heart Rate',
              value: heartRate,
              onChanged: (val) {
                setState(() {
                  heartRate = val;
                  updateIndividual();
                });
              },
            ),
            _buildPermissionItem(
              icon: Icons.local_fire_department_outlined,
              title: 'Calories Burnt',
              value: calories,
              onChanged: (val) {
                setState(() {
                  calories = val;
                  updateIndividual();
                });
              },
            ),
            SizedBox(height: 16),

            // Privacy text
            Text(
              'Walkzilla only uses your fitness data to enhance your adventure. Your data stays private.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      "Don't Allow",
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (steps || distance || heartRate || calories)
                        ? () async {
                            try {
                              final types = <HealthDataType>[];
                              if (steps) types.add(HealthDataType.STEPS);
                              if (distance)
                                types.add(HealthDataType.DISTANCE_DELTA);
                              if (heartRate)
                                types.add(HealthDataType.HEART_RATE);
                              if (calories)
                                types.add(HealthDataType.ACTIVE_ENERGY_BURNED);

                              await requestGoogleFitAuthorization(types);

                              if (widget.onAllow != null) {
                                await widget.onAllow!(types, null);
                              }
                              Navigator.of(context).pop(true);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Failed to get health permissions. Please try again.'),
                                ),
                              );
                            }
                          }
                        : null,
                    child: Text(
                      'Allow',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF7940),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.black54),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Color(0xFFFF7940),
          ),
        ],
      ),
    );
  }
}

class PermissionsNeededDialog extends StatelessWidget {
  final VoidCallback onGrantPermissions;
  const PermissionsNeededDialog({super.key, required this.onGrantPermissions});

  @override
  Widget build(BuildContext context) {
    final orange = Color(0xFFFEB14C);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: orange.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              padding: EdgeInsets.all(16),
              child: Icon(Icons.shield_outlined, color: orange, size: 40),
            ),
            SizedBox(height: 24),
            Text(
              'Permissions Needed',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 22,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 18),
            Text(
              "Walkzilla needs access to your fitness data to track your steps and power your adventure. Without these permissions, Walkzilla won't work properly.",
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: Color(0xFF6C6C6C),
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFFDADADA), width: 1.5),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      "Exit App",
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onGrantPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      elevation: 0,
                    ),
                    child: Text('Grant Permissions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showHealthPermissionDialog({
  required BuildContext context,
  bool isPermissionNeeded = false,
}) async {
  bool? result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => HealthPermissionDialog(
      isPermissionNeeded: isPermissionNeeded,
      onAllow: (types, stepsCount) => Navigator.of(context).pop(true),
    ),
  );

  return result ?? false;
}
