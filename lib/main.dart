import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'welcome_screen.dart';
import 'package:provider/provider.dart';
import 'providers/step_goal_provider.dart';
import 'providers/streak_provider.dart';
import 'health_dashboard.dart';
import 'streaks_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'widgets/duo_challenge_invite_dialog.dart';
import 'services/user_document_cleanup_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle background message (can be expanded later)
  print('Handling a background message: ${message.messageId}');
}

// Global navigator key to show dialogs from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('Flutter binding initialized');

    // Set preferred orientations to portrait only
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    print('Screen orientation set');

    try {
      await Firebase.initializeApp();
      print('Firebase initialized successfully');

      // Initialize cleanup service to remove unnecessary fields from existing user documents
      final cleanupService = UserDocumentCleanupService();
      await cleanupService.cleanupAllUserDocuments();
      print('User document cleanup completed');
    } catch (e) {
      print('Error initializing Firebase: $e');
      // Continue without Firebase for now
    }

    // FCM setup
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    final fcm = FirebaseMessaging.instance;
    await fcm.requestPermission();
    await fcm.setAutoInitEnabled(true);
    // Optionally: print the FCM token for testing
    final token = await fcm.getToken();
    print('FCM Token: $token');

    // Listen for foreground messages (keeping for backup, but real-time listener in home screen is primary)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.data['type'] == 'duo_challenge_invite') {
        // Show popup for duo challenge invite (backup method)
        _showDuoChallengeInviteDialog(
          message.data['inviterUsername'] ?? 'Someone',
          message.data['inviteId'] ?? '',
        );
      }
    });

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => StepGoalProvider()),
          ChangeNotifierProvider(create: (_) => StreakSettingsProvider()),
          ChangeNotifierProvider(create: (_) => StreakProvider()),
        ],
        child: const MyApp(),
      ),
    );
    print('App started successfully');
  } catch (e) {
    print('Error in main: $e');
    // Show some UI even if there's an error
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Error initializing app: $e'),
        ),
      ),
    ));
  }
}

void _showDuoChallengeInviteDialog(String inviterUsername, String inviteId) {
  // Show the dialog using the global navigator key
  if (navigatorKey.currentContext != null) {
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => DuoChallengeInviteDialog(
        inviterUsername: inviterUsername,
        inviteId: inviteId,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add the global navigator key
      debugShowCheckedModeBanner: false,
      title: 'Walkzilla',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: kDebugMode ? const WelcomeScreen() : const HealthDashboard(),
    );
  }
}
