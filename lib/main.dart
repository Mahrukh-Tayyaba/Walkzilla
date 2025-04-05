import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';

import 'welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Auth UI',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: kDebugMode ? WelcomeScreen() : const SplashScreen(),
    );
  }
}
