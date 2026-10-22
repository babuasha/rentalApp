import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final bool _isPasswordObscured = true;
  final bool _isConfirmPasswordObscured = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms & Conditions')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create User in Firebase Auth using dummy domain for the username
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: '${_usernameController.text.trim()}@myapp.com',
        password: _passwordController.text.trim(),
      );

      // 2. Store Additional User Data in Firestore
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'uid': userCredential.user!.uid,
          'fullName': _fullNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account Created Successfully!')),
        );
        Navigator.pop(context); // Return to login page
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Registration failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 40.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign up to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Full Name
                    const Text('Full Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullNameController,
                      validator: (val) => val != null && val.isNotEmpty ? null : 'Please enter your name',
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline),
                        hintText: 'Enter your full name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Username
                    const Text('Username', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameController,
                      keyboardType: TextInputType.text,
                      validator: (val) => val != null && val.isNotEmpty ? null : 'Enter a valid username',
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline),
                        hintText: 'Enter your username',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password
                    const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isPasswordObscured,
                      validator: (val) => val != null && val.length >= 6 ? null : 'Password must be at least 6 characters',
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'Enter your password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password
                    const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _isConfirmPasswordObscured,
                      validator: (val) {
                        if (val != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: 'Confirm your password',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Terms Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          activeColor: const Color(0xFF0D6338),
                          onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                        ),
                        const Expanded(
                          child: Text('I agree to the Terms & Conditions'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Sign Up Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6338),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Sign Up', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),

          // Locked to the absolute bottom-most right corner of the screen
          Positioned(
            bottom: 8,
            right: 12,
            child: Text(
              'Powered by a3sApps',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}