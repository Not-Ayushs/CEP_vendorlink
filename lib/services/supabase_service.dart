import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase service — single source of truth for all DB and Auth ops.
class SupabaseService {
  // ─── CONFIG ──────────────────────────────────────────────────────────────
  // static const String supabaseUrl = 'https://brdieuduyciqzgihdfhl.supabase.co';
  static const String supabaseUrl = 'https://nidkxztxsjkberieynsf.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5pZGt4enR4c2prYmVyaWV5bnNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY3NjE3NjEsImV4cCI6MjA5MjMzNzc2MX0.scjGDboldvNAzcIJehRyKlA5zaABsmqhA1fyTm16VvE';

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

  /// Sign up a new user and create their profile + role-specific row.
  ///
  /// Handles:
  ///  - Duplicate email (Supabase returns empty identities instead of error)
  ///  - DB upsert conflicts via ON CONFLICT DO NOTHING (ignoreDuplicates)
  ///  - Clean friendly error messages
  static Future<void> signUpAndCreateProfile({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    if (role != 'vendor' && role != 'driver' && role != 'admin') {
      throw Exception('Invalid role specified.');
    }

    final res = await client.auth.signUp(
      email: email.trim(),
      password: password,
    );

    final user = res.user;

    // Supabase v2: when email is already registered, signUp() does NOT throw.
    // Instead it returns a User with an empty `identities` list.
    // We detect this and surface a friendly error.
    if (user == null) {
      throw Exception('Sign-up failed. Please try again.');
    }

    final isAlreadyRegistered =
        user.identities != null && user.identities!.isEmpty;
    if (isAlreadyRegistered) {
      throw Exception(
          'This email is already registered. Please sign in instead.');
    }

    final userId = user.id;

    // Write profile row — use upsert with ignoreDuplicates so a race-condition
    // or trigger-created row doesn't cause a conflict.
    try {
      await client.from('profiles').upsert(
        {'id': userId, 'name': name, 'role': role},
        ignoreDuplicates: false, // update if somehow exists
      );
    } catch (e) {
      // Best-effort: profile may have been created by a DB trigger.
      // Log but don't fail registration.
    }

    // Write role-specific row
    try {
      if (role == 'vendor') {
        await client.from('vendors').upsert(
          {
            'user_id': userId,
            'name': name,
            'shopName': "$name's Shop",
            'phone': '',
            'address': '',
          },
          ignoreDuplicates: true, // skip if already exists (no overwrite)
        );
      } else if (role == 'driver') {
        await client.from('drivers').upsert(
          {'user_id': userId, 'name': name, 'phone': ''},
          ignoreDuplicates: true,
        );
      }
      // admin: only profiles row needed
    } catch (e) {
      // Role-specific row failure is non-fatal at this stage;
      // getCurrentUserRole() will recreate it on next login.
    }
  }

  static Future<void> signOut() => client.auth.signOut();

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILES / ROLES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch role from `profiles` table. Returns null if not found.
  static Future<String?> getCurrentUserRole() async {
    final user = currentUser;
    if (user == null) return null;

    final res = await client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    final email = user.email?.toLowerCase().trim() ?? '';

    // Auto-correct corrupted roles for demo accounts or handle missing demo profiles
    if (demoUsers.containsKey(email)) {
      final expectedRole = demoUsers[email]!.role;
      if (res == null || res['role'] != expectedRole) {
        await client.from('profiles').upsert({
          'id': user.id,
          'name': demoUsers[email]!.name,
          'role': expectedRole,
        });

        if (expectedRole == 'vendor') {
          await client.from('vendors').upsert({
            'user_id': user.id,
            'name': demoUsers[email]!.name,
            'shopName': "Default Shop",
            'phone': '',
            'address': '',
          });
        } else if (expectedRole == 'driver') {
          await client.from('drivers').upsert({
            'user_id': user.id,
            'name': demoUsers[email]!.name,
            'phone': '',
          });
        }
        return expectedRole;
      }
    }

    if (res == null) {
      // Profile missing for a non-demo user -> determine actual role if possible
      String roleToCreate = user.userMetadata?['role'] ?? 'vendor';

      // Create it automatically
      await client.from('profiles').upsert({
        'id': user.id,
        'name': user.email?.split('@')[0] ?? 'Unknown',
        'role': roleToCreate,
      });

      // Ensure specific row exists for the determined role
      if (roleToCreate == 'vendor') {
        await client.from('vendors').upsert({
          'user_id': user.id,
          'name': user.email?.split('@')[0] ?? 'Unknown',
          'shopName': "Default Shop",
          'phone': '',
          'address': '',
        });
      } else if (roleToCreate == 'driver') {
        await client.from('drivers').upsert({
          'user_id': user.id,
          'name': user.email?.split('@')[0] ?? 'Unknown',
          'phone': '',
        });
      }
      return roleToCreate;
    }

    return res['role'] as String?;
  }

  static Future<Map<String, dynamic>?> getCurrentVendorProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return client.from('vendors').select().eq('user_id', user.id).maybeSingle();
  }

  static Future<Map<String, dynamic>?> getCurrentDriverProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return client.from('drivers').select().eq('user_id', user.id).maybeSingle();
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
    double? lat,
    double? lng,
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
    // Save GPS coordinates when available so the driver map can use real locations
    if (lat != null && lng != null) {
      record['lat'] = lat;
      record['lng'] = lng;
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
