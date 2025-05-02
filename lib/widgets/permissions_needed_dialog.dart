import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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
