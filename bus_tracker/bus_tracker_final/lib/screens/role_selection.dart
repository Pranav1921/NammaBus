import 'dart:ui';
import 'package:bus_tracker_final/screens/conductor_login_screen.dart';
import 'package:bus_tracker_final/screens/passenger_signin_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color orangeColor = Color(0xFFFFA500);
    const Color yellowColor = Color(0xFFFFD700);
    const Color buttonColor = Color(0xFFE57373);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [orangeColor, yellowColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Header
                  Column(
                    children: [
                      const SizedBox(height: 50),
                      Image.asset('assets/title.png', height: 100),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                          children: const <TextSpan>[
                            TextSpan(text: 'Bus ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: 'Tracker'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Role Selection Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildRoleButton(
                          context,
                          'Passenger Mode',
                          buttonColor,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PassengerSignInScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildRoleButton(
                          context,
                          'Conductor Mode',
                          buttonColor,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ConductorLoginScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Footer
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Image.asset(
                          'assets/mysore.png',
                          height: 50,
                        ),
                      ),
                      Text(
                        'Made for KSRTC',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(
    BuildContext context,
    String text,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
