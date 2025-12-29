/* import 'package:bus_tracker_final/screens/map_screen.dart';
import 'package:bus_tracker_final/services/auth_service.dart';
import 'package:flutter/material.dart';

// --- Minimalist & Premium UI Color Palette ---
const Color kPrimaryColor = Color(0xFF007AFF);
const Color kBackgroundColor = Color(0xFFF2F2F7);
const Color kCardColor = Colors.white;
const Color kTextPrimaryColor = Color(0xFF1D1D1F);
const Color kTextSecondaryColor = Color(0xFF8A8A8E);
const Color kKarnatakaRed = Color(0xFFC8102E);

class LoginScreen extends StatefulWidget {
  final int initialTabIndex;
  const LoginScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithGoogle();
    if (mounted) setState(() => _isLoading = false);

    // ✅ FIXED: Added navigation logic on successful login
    if (user != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MapScreen(isConductor: false)),
      );
    }
  }

  void _handleConductorSignIn() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    final String email = '${_usernameController.text.trim()}@ksrtc.local';
    
    final user = await _authService.signInWithEmail(email, _passwordController.text.trim());
    if (mounted) setState(() => _isLoading = false);
    
    // ✅ FIXED: Added navigation logic on successful login
    if (user != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MapScreen(isConductor: true)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed. Please check credentials.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(backgroundColor: kBackgroundColor, elevation: 0, iconTheme: const IconThemeData(color: kTextPrimaryColor)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'NammaBus',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Welcome Back',
                  style: TextStyle(fontSize: 18, color: kTextSecondaryColor),
                ),
                const SizedBox(height: 40),
                _buildAuthCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
                ],
              ),
              labelColor: kKarnatakaRed, // Themed color
              unselectedLabelColor: kTextSecondaryColor,
              tabs: const [
                Tab(text: 'Passenger'),
                Tab(text: 'Conductor'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPassengerLogin(),
                _buildConductorLogin(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerLogin() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('The easiest way to track your bus.', textAlign: TextAlign.center, style: TextStyle(color: kTextSecondaryColor, fontSize: 16)),
        const SizedBox(height: 25),
        _isLoading
            ? const CircularProgressIndicator(color: kPrimaryColor)
            : ElevatedButton.icon(
                onPressed: _handleGoogleSignIn,
                icon: Image.asset('assets/google_logo.png', height: 24),
                label: const Text('Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
      ],
    );
  }

  Widget _buildConductorLogin() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            hintText: 'Username or Employee ID',
            prefixIcon: const Icon(Icons.person_outline, color: kKarnatakaRed),
            filled: true,
            fillColor: kBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline, color: kKarnatakaRed),
            filled: true,
            fillColor: kBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        _isLoading
            ? const CircularProgressIndicator(color: kKarnatakaRed)
            : ElevatedButton(
                onPressed: _handleConductorSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kKarnatakaRed, // Themed color
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Sign In'),
              ),
      ],
    );
  }
}
*/