import 'package:bus_tracker_final/screens/map_screen.dart';
import 'package:bus_tracker_final/services/auth_service.dart';
import 'package:bus_tracker_final/services/user_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// --- UI Color Palette ---
const Color kPrimaryColor = Color(0xFF007AFF);
const Color kTextPrimaryColor = Color(0xFF1D1D1F);
const Color kTextSecondaryColor = Color(0xFF8A8A8E);

class PassengerLoginScreen extends StatefulWidget {
  const PassengerLoginScreen({super.key});

  @override
  State<PassengerLoginScreen> createState() => _PassengerLoginScreenState();
}

class _PassengerLoginScreenState extends State<PassengerLoginScreen> {
  final AuthService _authService = AuthService();
  final UserStorageService _storageService = UserStorageService();
  bool _isLoading = false;

  void _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final User? user = await _authService.signInWithGoogle();
      if (user != null) {
        await _storageService.savePassengerProfile(
          uid: user.uid,
          name: user.displayName ?? 'Passenger',
          email: user.email ?? 'No email provided',
        );

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MapScreen(isConductor: false),
          ),
              (Route<dynamic> route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed. Please try again. Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.login_rounded,
                size: 80,
                color: kPrimaryColor,
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome, Passenger',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: kTextPrimaryColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Sign in to track buses and view your trip history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: kTextSecondaryColor,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                icon: Image.asset('assets/google_logo.png', height: 24.0),
                label: const Text('Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kTextPrimaryColor,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
