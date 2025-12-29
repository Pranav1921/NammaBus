import 'package:bus_tracker_final/screens/map_screen.dart';
import 'package:bus_tracker_final/services/auth_service.dart';
import 'package:flutter/material.dart';
// --- NEW --- Import the central color palette
import 'package:bus_tracker_final/util/app_colors.dart' as app_colors;

// --- REMOVED --- Old color constants are now in app_colors.dart

class ConductorAuthScreen extends StatefulWidget {
  const ConductorAuthScreen({super.key});

  @override
  State<ConductorAuthScreen> createState() => _ConductorAuthScreenState();
}

class _ConductorAuthScreenState extends State<ConductorAuthScreen> {
  // ... your existing state variables and methods are correct and unchanged ...
  final AuthService _authService = AuthService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleConductorSignIn() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your username and password.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    final String email = '${_usernameController.text.trim()}@ksrtc.local';

    final user = await _authService.signInWithEmail(email, _passwordController.text.trim());
    if (mounted) setState(() => _isLoading = false);

    if (user != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MapScreen(isConductor: true)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed. Please check credentials.')));
    }
  }

  // The build method and its children are also correct and unchanged
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: app_colors.AppColors.background,
      appBar: AppBar(
          backgroundColor: app_colors.AppColors.background,
          elevation: 0,
          // This now correctly finds kTextPrimaryColor from the imported file
          iconTheme: const IconThemeData(color: app_colors.AppColors.textPrimary)
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Conductor Portal',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: app_colors.AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please sign in to continue',
                  style: TextStyle(fontSize: 18, color: app_colors.AppColors.textSecondary),
                ),
                const SizedBox(height: 40),
                _buildConductorLogin(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConductorLogin() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: app_colors.AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              hintText: 'Username or Employee ID',
              prefixIcon: const Icon(Icons.person_outline, color: app_colors.AppColors.destructive),
              filled: true,
              fillColor: app_colors.AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline, color: app_colors.AppColors.destructive),
              filled: true,
              fillColor: app_colors.AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 20),
          _isLoading
              ? const CircularProgressIndicator(color: app_colors.AppColors.destructive)
              : ElevatedButton(
            onPressed: _handleConductorSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: app_colors.AppColors.destructive,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
