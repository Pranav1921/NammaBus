import 'package:bus_tracker_final/screens/map_screen.dart';
import 'package:bus_tracker_final/services/auth_service.dart';
import 'package:flutter/material.dart';

const Color kKarnatakaYellow = Color(0xFFFFCD00);
const Color kKarnatakaRed = Color(0xFFC8102E);

class ConductorAuthScreen extends StatefulWidget {
  const ConductorAuthScreen({super.key});

  @override
  State<ConductorAuthScreen> createState() => _ConductorAuthScreenState();
}

class _ConductorAuthScreenState extends State<ConductorAuthScreen> {
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

  void _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your username and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Append the hidden domain to the username to create a valid email
    final String email = '${_usernameController.text.trim()}@ksrtc.local';
    
    final user = await _authService.signInWithEmail(
      email,
      _passwordController.text.trim(),
    );

    if (mounted) setState(() => _isLoading = false);

    if (user != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MapScreen(isConductor: true)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Please check your credentials.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kKarnatakaYellow, kKarnatakaRed],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text(
                  'Conductor Portal',
                  style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                _buildForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            hintText: 'Username or Employee ID',
            filled: true,
            // ✅ FIXED: Using withAlpha for modern opacity
            fillColor: Colors.white.withAlpha(230), 
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            hintText: 'Password',
            filled: true,
            fillColor: Colors.white.withAlpha(230), // ✅ FIXED
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kKarnatakaRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Sign In'),
              ),
      ],
    );
  }
}

