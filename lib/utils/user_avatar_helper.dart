import 'package:flutter/material.dart';

// Utility class for generating consistent colors for user initials
class UserAvatarHelper {
  static final List<Color> _colors = [
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
    const Color(0xFFED3E57), // Crimson Rose
  ];

  static Color getColorForUser(String userId) {
    // Generate a consistent color based on user ID
    int hash = userId.hashCode;
    return _colors[hash.abs() % _colors.length];
  }

  static String getInitials(String name) {
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }

  static Widget buildAvatar({
    required String userId,
    required String displayName,
    String? profileImage,
    double radius = 28,
    double fontSize = 18,
  }) {
    if (profileImage != null && profileImage.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(profileImage),
        radius: radius,
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback to initials if image fails to load
        },
        child: profileImage.isEmpty
            ? _buildInitialsAvatar(userId, displayName, radius, fontSize)
            : null,
      );
    } else {
      return _buildInitialsAvatar(userId, displayName, radius, fontSize);
    }
  }

  static Widget _buildInitialsAvatar(
      String userId, String displayName, double radius, double fontSize) {
    return CircleAvatar(
      backgroundColor: getColorForUser(userId),
      radius: radius,
      child: Text(
        getInitials(displayName),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
