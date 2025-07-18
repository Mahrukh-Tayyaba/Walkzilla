import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class UsernameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  // Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    if (username.trim().isEmpty) return false;

    try {
      final normalizedUsername = username.toLowerCase().trim();
      print(
          'Checking availability for normalized username: "$normalizedUsername"');

      // Check in usernames collection (reserved usernames)
      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(normalizedUsername)
          .get();

      if (usernameDoc.exists) {
        print(
            'Username $normalizedUsername is reserved in usernames collection');
        return false;
      }

      print('Username $normalizedUsername not found in usernames collection');

      // Also check in users collection to see if any user has this username
      final usersQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();

      print('Users query returned ${usersQuery.docs.length} documents');

      if (usersQuery.docs.isNotEmpty) {
        print('Username $normalizedUsername is already used by a user');
        return false;
      }

      print('Username $normalizedUsername is available');
      return true;
    } catch (e) {
      print('Error checking username availability: $e');

      // Check if it's a permission error
      if (e.toString().contains('permission-denied')) {
        print(
            'Permission denied error - this might be due to Firestore rules not being deployed yet');
        // For permission errors, we'll assume the username is available to allow signup to proceed
        // The actual availability will be checked during the signup process
        return true;
      }

      // In case of other errors, assume username is not available to be safe
      return false;
    }
  }

  // Generate username from name
  String generateUsernameFromName(String firstName, String lastName) {
    // Clean and normalize names
    final cleanFirstName = _cleanName(firstName);
    final cleanLastName = _cleanName(lastName);

    // Generate base username
    String baseUsername = '';

    if (cleanFirstName.isNotEmpty && cleanLastName.isNotEmpty) {
      // Try first + last name combination
      baseUsername = '$cleanFirstName$cleanLastName';
    } else if (cleanFirstName.isNotEmpty) {
      baseUsername = cleanFirstName;
    } else if (cleanLastName.isNotEmpty) {
      baseUsername = cleanLastName;
    } else {
      // Fallback to generic username
      baseUsername = 'user';
    }

    // Add random numbers to ensure uniqueness
    final randomNumbers = _generateRandomNumbers(4);
    return '$baseUsername$randomNumbers';
  }

  // Clean name for username generation
  String _cleanName(String name) {
    if (name.isEmpty) return '';

    // Remove special characters, keep only letters and numbers
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

    // Convert to lowercase
    return cleaned.toLowerCase();
  }

  // Generate random numbers
  String _generateRandomNumbers(int length) {
    final numbers = List.generate(length, (_) => _random.nextInt(10));
    return numbers.join();
  }

  // Suggest alternative usernames
  Future<List<String>> suggestUsernames(String baseUsername) async {
    final suggestions = <String>[];
    final base = _cleanName(baseUsername);

    if (base.isEmpty) return suggestions;

    // Try different variations
    final variations = [
      base,
      '$base${_generateRandomNumbers(2)}',
      '$base${_generateRandomNumbers(3)}',
      '$base${_generateRandomNumbers(4)}',
      'the$base',
      'my$base',
      '${base}user',
      '${base}walker',
      '${base}fitness',
      '$base${_generateRandomNumbers(2)}',
      '$base${_generateRandomNumbers(3)}',
      '$base${_generateRandomNumbers(4)}',
    ];

    // Check availability for each variation
    for (final variation in variations) {
      if (suggestions.length >= 5) break; // Limit to 5 suggestions

      final isAvailable = await isUsernameAvailable(variation);
      if (isAvailable) {
        suggestions.add(variation);
      }
    }

    return suggestions;
  }

  // Reserve username for user
  Future<bool> reserveUsername(String username, String userId) async {
    if (username.trim().isEmpty) return false;

    try {
      final normalizedUsername = username.toLowerCase().trim();

      // First check availability outside transaction
      final isAvailable = await isUsernameAvailable(normalizedUsername);
      if (!isAvailable) {
        print('Username $normalizedUsername is not available for reservation');
        return false;
      }

      // Use a transaction to ensure atomic username reservation
      final result = await _firestore.runTransaction<bool>((transaction) async {
        // Double-check availability in transaction
        final usernameDoc = await transaction
            .get(_firestore.collection('usernames').doc(normalizedUsername));

        if (usernameDoc.exists) {
          print(
              'Username $normalizedUsername is already reserved (transaction check)');
          return false;
        }

        // Reserve the username
        transaction
            .set(_firestore.collection('usernames').doc(normalizedUsername), {
          'userId': userId,
          'reservedAt': FieldValue.serverTimestamp(),
        });

        print(
            'Username $normalizedUsername reserved successfully for user $userId');
        return true;
      });

      return result;
    } catch (e) {
      print('Error reserving username: $e');
      return false;
    }
  }

  // Validate username format
  bool isValidUsername(String username) {
    if (username.isEmpty) return false;

    // Check length (3-20 characters)
    if (username.length < 3 || username.length > 20) return false;

    // Check format: only letters and numbers allowed
    final validFormat = RegExp(r'^[a-zA-Z0-9]+$');
    if (!validFormat.hasMatch(username)) return false;

    // Check for reserved words (optional)
    final reservedWords = ['admin', 'moderator', 'support', 'help', 'info'];
    if (reservedWords.contains(username.toLowerCase())) return false;

    return true;
  }

  // Get username suggestions based on user's name (for Google sign-in)
  Future<List<String>> getUsernameSuggestionsFromName(
      String displayName) async {
    final suggestions = <String>[];

    if (displayName.isEmpty) return suggestions;

    // Split display name into parts
    final nameParts =
        displayName.split(' ').where((part) => part.isNotEmpty).toList();

    if (nameParts.isEmpty) return suggestions;

    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.last : '';

    // Generate shorter base suggestions for Google sign-in
    final baseSuggestions = [
      firstName.toLowerCase(),
      '${firstName.toLowerCase()}${_generateRandomNumbers(2)}',
      '${firstName.toLowerCase()}${_generateRandomNumbers(3)}',
    ];

    if (lastName.isNotEmpty) {
      baseSuggestions.addAll([
        '${firstName.toLowerCase()}${lastName.toLowerCase().substring(0, 1)}',
        '${firstName.toLowerCase()}${lastName.toLowerCase().substring(0, 1)}${_generateRandomNumbers(2)}',
      ]);
    }

    // Check availability and add to suggestions
    for (final suggestion in baseSuggestions) {
      if (suggestions.length >= 5) break;

      if (isValidUsername(suggestion)) {
        final isAvailable = await isUsernameAvailable(suggestion);
        if (isAvailable) {
          suggestions.add(suggestion);
        }
      }
    }

    // If we don't have enough suggestions, add some short generic ones
    if (suggestions.length < 5) {
      final shortGenericSuggestions = [
        'walker${_generateRandomNumbers(2)}',
        'fit${_generateRandomNumbers(2)}',
        'active${_generateRandomNumbers(2)}',
        'user${_generateRandomNumbers(2)}',
        'player${_generateRandomNumbers(2)}',
      ];

      for (final suggestion in shortGenericSuggestions) {
        if (suggestions.length >= 5) break;

        final isAvailable = await isUsernameAvailable(suggestion);
        if (isAvailable) {
          suggestions.add(suggestion);
        }
      }
    }

    return suggestions;
  }

  // Check if username is reserved for a specific user
  Future<bool> isUsernameReservedForUser(String username, String userId) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();

      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(normalizedUsername)
          .get();

      if (usernameDoc.exists) {
        final data = usernameDoc.data();
        final reservedUserId = data?['userId'] as String?;
        return reservedUserId == userId;
      }

      return false;
    } catch (e) {
      print('Error checking username reservation for user: $e');
      return false;
    }
  }

  // Release username reservation (if user cancels signup)
  Future<void> releaseUsername(String username) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();
      await _firestore.collection('usernames').doc(normalizedUsername).delete();
    } catch (e) {
      print('Error releasing username: $e');
    }
  }

  // Clear stale username reservations (for debugging)
  Future<void> clearStaleReservations() async {
    try {
      final reservations = await _firestore.collection('usernames').get();

      for (final doc in reservations.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;

        if (userId != null) {
          // Check if user still exists
          final userDoc =
              await _firestore.collection('users').doc(userId).get();
          if (!userDoc.exists) {
            // User doesn't exist, remove the reservation
            await doc.reference.delete();
            print('Cleared stale reservation for username: ${doc.id}');
          }
        }
      }
    } catch (e) {
      print('Error clearing stale reservations: $e');
    }
  }

  // Test function to debug username availability
  Future<void> debugUsernameAvailability(String username) async {
    print('=== DEBUG: Username Availability Check ===');
    print('Original username: "$username"');

    final normalizedUsername = username.toLowerCase().trim();
    print('Normalized username: "$normalizedUsername"');

    try {
      // Check usernames collection
      final usernameDoc = await _firestore
          .collection('usernames')
          .doc(normalizedUsername)
          .get();

      print('Username in usernames collection: ${usernameDoc.exists}');
      if (usernameDoc.exists) {
        print('Username data: ${usernameDoc.data()}');
      }

      // Check users collection
      final usersQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();

      print('Users with this username: ${usersQuery.docs.length}');
      if (usersQuery.docs.isNotEmpty) {
        print('User data: ${usersQuery.docs.first.data()}');
      }

      final isAvailable = await isUsernameAvailable(username);
      print('Final availability result: $isAvailable');
    } catch (e) {
      print('Error during debug: $e');
    }

    print('=== END DEBUG ===');
  }
}
