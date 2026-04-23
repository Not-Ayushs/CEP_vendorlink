import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swm_vendor/theme/app_theme.dart';
import 'package:swm_vendor/services/supabase_service.dart';
import 'package:swm_vendor/screens/vendor_main_screen.dart';
import 'package:swm_vendor/screens/driver_main_screen.dart';
import 'package:swm_vendor/screens/admin_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const WasteOpsApp());
}

class WasteOpsApp extends StatelessWidget {
  const WasteOpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waste Ops',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      // Named route used by performLogout() to clear the nav stack.
      initialRoute: '/',
      routes: {'/': (_) => const AuthGate()},
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AUTH GATE — watches session state, routes to correct screen
// ═══════════════════════════════════════════════════════════════════════════
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _sub;

  @override
  void initState() {
    super.initState();
    _sub = SupabaseService.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SupabaseService.currentSession == null
        ? const UnifiedLoginScreen()
        : const RoleRouter();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ROLE ROUTER — reads role from profiles table, directs to correct app
// ═══════════════════════════════════════════════════════════════════════════
class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveRole();
  }

  Future<void> _resolveRole() async {
    try {
      final role = await SupabaseService.getCurrentUserRole();
      if (!mounted) return;

      if (role == null || role.trim().isEmpty) {
        setState(() => _error =
            'No role found for this account.\nContact your admin or register a new account.');
        return;
      }

      Widget dest;
      switch (role) {
        case 'vendor':
          dest = const VendorMainScreen();
          break;
        case 'driver':
          dest = const DriverMainScreen();
          break;
        case 'admin':
          dest = const AdminMainScreen();
          break;
        default:
          setState(() => _error =
              'Invalid role found for this account.\nContact your admin or register a new account.');
          return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => dest));
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 56),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  onPressed: () async {
                    await SupabaseService.signOut();
                    if (mounted) setState(() => _error = null);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Resolving your role…', style: TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// UNIFIED LOGIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign-in form
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // Register form
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  String _selectedRole = 'vendor';

  bool _loading = false;
  bool _obscurePass = true;
  String? _errorMsg;
  String? _successMsg;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    super.dispose();
  }

  // ── SIGN IN ─────────────────────────────────────────────────────────────
  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = 'Please enter email and password.');
      return;
    }

    setState(() { _loading = true; _errorMsg = null; _successMsg = null; });
    try {
      await SupabaseService.signInWithEmail(email, pass);
      // AuthGate will rebuild automatically on auth state change
    } on AuthException catch (e) {
      String msg = e.message;
      // Friendlier messages for common errors
      if (msg.toLowerCase().contains('invalid login')) {
        msg = 'Invalid email or password.';
      } else if (msg.toLowerCase().contains('email not confirmed')) {
        if (SupabaseService.isDemoUser(email)) {
          msg = '⚠️ Demo user not yet seeded in Supabase.\nRun supabase_setup.sql and create demo users in the dashboard.';
        } else {
          msg = 'Please confirm your email before logging in.';
        }
      }
      setState(() => _errorMsg = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── QUICK DEMO LOGIN ─────────────────────────────────────────────────────
  void _quickLogin(String email) {
    _emailCtrl.text = email;
    _passCtrl.text = SupabaseService.demoPassword;
    setState(() { _errorMsg = null; _successMsg = null; });
    _signIn();
  }

  // ── REGISTER ────────────────────────────────────────────────────────────
  Future<void> _register() async {
    final name = _regNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final pass = _regPassCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = 'Please fill in all fields.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _errorMsg = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _errorMsg = null; _successMsg = null; });
    try {
      await SupabaseService.signUpAndCreateProfile(
        email: email,
        password: pass,
        name: name,
        role: _selectedRole,
      );
      if (mounted) {
        setState(() => _successMsg =
            '✅ Account created! Check your email to confirm, then sign in.');
        _tabController.animateTo(0);
      }
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.toLowerCase().contains('already registered') ||
          msg.toLowerCase().contains('already exists') ||
          msg.toLowerCase().contains('user already')) {
        msg = 'This email is already registered. Please sign in instead.';
      } else if (msg.toLowerCase().contains('weak password')) {
        msg = 'Password is too weak. Use at least 6 characters.';
      }
      setState(() => _errorMsg = msg);
    } catch (e) {
      // Friendly mapping for known messages thrown by signUpAndCreateProfile
      String msg = e.toString();
      if (msg.contains('already registered') || msg.contains('already exists')) {
        msg = 'This email is already registered. Please sign in instead.';
      } else if (msg.contains('Invalid role')) {
        msg = 'Invalid role selected. Please try again.';
      } else if (msg.contains('Sign-up failed')) {
        msg = 'Registration failed. Please check your details and try again.';
      } else {
        // Strip the "Exception:" prefix Dart adds
        msg = msg.replaceFirst('Exception: ', '');
      }
      setState(() => _errorMsg = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // ── Logo ──────────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.delete_sweep, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text('Waste Ops',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                        color: AppTheme.primary)),
              ),
              const Center(
                child: Text('Solid Waste Management System',
                    style: TextStyle(color: Colors.black54, fontSize: 13)),
              ),

              const SizedBox(height: 32),

              // ── Demo Quick Login ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.bolt, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 6),
                      Text('Quick Demo Login',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                              fontSize: 13)),
                    ]),
                    const SizedBox(height: 12),
                    Row(
                      children: SupabaseService.demoUsers.values.map((u) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _DemoButton(
                              label: u.label,
                              onTap: _loading ? null : () => _quickLogin(u.email),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text('Password for all demo accounts: ${SupabaseService.demoPassword}',
                        style: TextStyle(fontSize: 11, color: Colors.blue[600])),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Tabs ─────────────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.black54,
                  dividerColor: Colors.transparent,
                  onTap: (_) => setState(() { _errorMsg = null; _successMsg = null; }),
                  tabs: const [Tab(text: 'Sign In'), Tab(text: 'Register')],
                ),
              ),
              const SizedBox(height: 24),

              // ── Tab Content ───────────────────────────────────────────────
              SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildSignIn(), _buildRegister()],
                ),
              ),

              // ── Feedback Messages ─────────────────────────────────────────
              if (_errorMsg != null) ...[
                const SizedBox(height: 16),
                _feedbackBox(_errorMsg!, isError: true),
              ],
              if (_successMsg != null) ...[
                const SizedBox(height: 16),
                _feedbackBox(_successMsg!, isError: false),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignIn() {
    return Column(
      children: [
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: Colors.grey[50],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: Colors.grey[50],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loading ? null : _signIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Sign In',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildRegister() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        TextField(
          controller: _regNameCtrl,
          decoration: InputDecoration(
            labelText: 'Full Name',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: Colors.grey[50],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: Colors.grey[50],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _regPassCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password (min 6 chars)',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: Colors.grey[50],
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _selectedRole,
          decoration: InputDecoration(
            labelText: 'Register as',
            prefixIcon: const Icon(Icons.badge_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: 'vendor', child: Text('🏪 Vendor')),
            DropdownMenuItem(value: 'driver', child: Text('🚛 Driver')),
            DropdownMenuItem(value: 'admin', child: Text('🛠 Admin')),
          ],
          onChanged: (v) => setState(() => _selectedRole = v!),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _register,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Create Account',
                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        ],
      ),
    );
  }

  Widget _feedbackBox(String msg, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isError ? Colors.red[200]! : Colors.green[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red[700] : Colors.green[700], size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg,
              style: TextStyle(color: isError ? Colors.red[800] : Colors.green[800]))),
        ],
      ),
    );
  }
}

/// Compact quick-login button used in the demo panel.
class _DemoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _DemoButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Colors.blue[300]!),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        foregroundColor: Colors.blue[800],
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
