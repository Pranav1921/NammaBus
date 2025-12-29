import 'package:bus_tracker_final/services/auth_service.dart';
import 'package:bus_tracker_final/services/user_storage_service.dart';
import 'package:bus_tracker_final/screens/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// UI Theme Constants from conductor screen for consistency
const Color kAppPrimaryColor = Color(0xFFE57373);
const Color kGradientTopColor = Color(0xFFFFA500);
const Color kGradientBottomColor = Color(0xFFFFD700);

class PassengerSignInScreen extends StatefulWidget {
  const PassengerSignInScreen({super.key});

  @override
  State<PassengerSignInScreen> createState() => _PassengerSignInScreenState();
}

class _PassengerSignInScreenState extends State<PassengerSignInScreen> {
  final AuthService _authService = AuthService();
  final UserStorageService _storageService = UserStorageService();
  bool _isLoading = false;

  void _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        await _storageService.savePassengerProfile(
          uid: user.uid,
          name: user.displayName ?? 'Passenger',
          email: user.email ?? '',
        );

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MapScreen(isConductor: false)),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
        title: Text(
          'Passenger Sign-In',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kGradientTopColor, kGradientBottomColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/title.png', height: 100),
                const SizedBox(height: 16),
                Text(
                  'Welcome, Passenger',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign in to track your bus and get live updates.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 50),
                _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                    : ElevatedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: Image.asset('assets/google_logo.png', height: 24.0), // Your Google logo
                        label: Text(
                          'Sign in with Google',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
