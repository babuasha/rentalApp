import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:rentalapp/Screens/splash_screen.dart';

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
      title: 'Rental Space',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        primaryColor: const Color(0xFF0D6338),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
