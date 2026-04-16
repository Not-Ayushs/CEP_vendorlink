import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase service — single source of truth for all DB and Auth ops.
class SupabaseService {
  // ─── CONFIG ──────────────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://brdieuduyciqzgihdfhl.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJyZGlldWR1eWNpcXpnaWhkZmhsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYxODA1NjYsImV4cCI6MjA5MTc1NjU2Nn0.zNUscSsPNK-3ZVyiycQI55yemsKaPCd7UamhcjkfmE8';

  // ─── DEMO USERS (bypass email verification) ──────────────────────────────
  static const String demoPassword = 'demo1234';

  static const Map<String, DemoUser> demoUsers = {
    'vendor@test.com': DemoUser(
      email: 'vendor@test.com',
      role: 'vendor',
      name: 'Demo Vendor',
      label: '🏪 Login as Vendor',
    ),
    'driver@test.com': DemoUser(
      email: 'driver@test.com',
      role: 'driver',
      name: 'Demo Driver',
      label: '🚛 Login as Driver',
    ),
    'admin@test.com': DemoUser(
      email: 'admin@test.com',
      role: 'admin',
      name: 'Demo Admin',
      label: '🛠 Login as Admin',
    ),
  };

  static bool isDemoUser(String email) => demoUsers.containsKey(email.toLowerCase().trim());
  // ─────────────────────────────────────────────────────────────────────────

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ═══════════════════════════════════════════════════════════════════════════

  static User? get currentUser => client.auth.currentUser;
  static Session? get currentSession => client.auth.currentSession;

  /// Sign in — demo users get a helpful error message if not yet seeded.
  static Future<AuthResponse> signInWithEmail(String email, String password) {
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign up a new regular user and insert their profile row.
  static Future<void> signUpAndCreateProfile({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final res = await client.auth.signUp(email: email, password: password);
    final userId = res.user?.id;
    if (userId == null) throw Exception('Sign-up failed. Try again.');

    // Insert into profiles table
    await client.from('profiles').insert({
      'id': userId,
      'name': name,
      'role': role,
    });

    // Insert into role-specific table
    if (role == 'vendor') {
      await client.from('vendors').insert({
        'user_id': userId,
        'name': name,
        'shopName': "$name's Shop",
        'phone': '',
        'address': '',
      });
    } else if (role == 'driver') {
      await client.from('drivers').insert({
        'user_id': userId,
        'name': name,
        'phone': '',
      });
    }
    // admin: only profiles row needed
  }

  static Future<void> signOut() => client.auth.signOut();

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILES / ROLES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch role from `profiles` table. Returns null if not found.
  static Future<String?> getCurrentUserRole() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    final res = await client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();

    return res?['role'] as String?;
  }

  static Future<Map<String, dynamic>?> getCurrentVendorProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    return client.from('vendors').select().eq('user_id', userId).maybeSingle();
  }

  static Future<Map<String, dynamic>?> getCurrentDriverProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    return client.from('drivers').select().eq('user_id', userId).maybeSingle();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WASTE RECORDS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getAllRecords() async {
    final res = await client
        .from('waste_records')
        .select('*, vendors(name, shopName), drivers(name)')
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getPendingRecords() async {
    final res = await client
        .from('waste_records')
        .select('*, vendors(name, shopName)')
        .eq('status', 'Pending')
        .order('id', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getVendorRecords(int vendorId) async {
    final res = await client
        .from('waste_records')
        .select('*, drivers(name)')
        .eq('vendorId', vendorId)
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Fetch all collected records (for driver history).
  static Future<List<Map<String, dynamic>>> getCollectedRecords() async {
    final res = await client
        .from('waste_records')
        .select('*, vendors(name, shopName), drivers(name)')
        .eq('status', 'Collected')
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Fetch ALL records (pending + collected) with vendor info — for driver dashboard.
  static Future<List<Map<String, dynamic>>> getAllRecordsForDriver() async {
    final res = await client
        .from('waste_records')
        .select('*, vendors(name, shopName), drivers(name)')
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> declareWaste({
    required int vendorId,
    required double declaredWaste,
    required String wasteType,
    String? notes,
  }) async {
    final record = <String, dynamic>{
      'vendorId': vendorId,
      'declaredWaste': declaredWaste,
      'verifiedWaste': 0.0,
      'status': 'Pending',
      'timestamp': '',
      'qrScanned': false,
      'photoAdded': false,
      'wasteType': wasteType,
    };
    if (notes != null && notes.trim().isNotEmpty) {
      record['notes'] = notes.trim();
    }
    await client.from('waste_records').insert(record);
  }

  static Future<void> collectRecord({
    required int recordId,
    required int driverId,
    required double verifiedWaste,
    required bool qrScanned,
    required bool photoAdded,
    required String timestamp,
  }) async {
    await client.from('waste_records').update({
      'driverId': driverId,
      'verifiedWaste': verifiedWaste,
      'status': 'Collected',
      'timestamp': timestamp,
      'qrScanned': qrScanned,
      'photoAdded': photoAdded,
    }).eq('id', recordId);
  }
}

/// Value object for demo user metadata.
class DemoUser {
  final String email;
  final String role;
  final String name;
  final String label;

  const DemoUser({
    required this.email,
    required this.role,
    required this.name,
    required this.label,
  });
}
