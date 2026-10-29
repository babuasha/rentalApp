import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rentalapp/Screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Instant navigation timer (500ms is snappy and prevents any perceived lag)
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0D6338);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Apartment Icon Container
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.06),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.apartment_rounded,
                      size: 55,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // App Title
                const Text(
                  'Rental Space',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                const Text(
                  'Property & Tenant Management Portal',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Footer version and Powered by branding stacked at the bottom center
          Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Owner Admin v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Powered by A3S Apps',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}