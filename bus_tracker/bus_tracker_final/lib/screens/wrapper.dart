import 'package:bus_tracker_final/screens/role_selection.dart';
import 'package:bus_tracker_final/screens/map_screen.dart';
import 'package:bus_tracker_final/services/auth_service.dart';
import 'package:bus_tracker_final/services/user_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // If no Firebase user, show role selection
        if (!snapshot.hasData || snapshot.data == null) {
          return const RoleSelectionScreen();
        }

        // Firebase user exists; ensure local passenger session exists for Google-signed users
        return FutureBuilder<Map<String, String?>>(
          future: (() async {
            final storage = UserStorageService();
            // Ensure service is initialized (important for other methods to work)
            await storage.init();
            final existing = await storage.getPassengerProfile();
            if (existing['isLoggedIn'] == 'true') return existing;

            // If the Firebase user signed in via Google, persist a passenger session automatically
            final user = snapshot.data!;
            final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
            if (isGoogle) {
              // ✅ FIX: Use the correct method name
              await storage.savePassengerProfile(
                uid: user.uid,
                name: user.displayName ?? 'Passenger',
                email: user.email ?? '',
              );
              return await storage.getPassengerProfile();
            }
            return existing;
          })(),
          builder: (context, ss) {
            if (ss.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final profile = ss.data;
            if (profile != null && profile['isLoggedIn'] == 'true') {
              // Passenger is signed in locally — go straight to map (passenger mode)
              return const MapScreen(isConductor: false);
            }
            // Otherwise show the role selection (user may be a conductor or unsigned passenger)
            return const RoleSelectionScreen();
          },
        );
      },
    );
  }
}
