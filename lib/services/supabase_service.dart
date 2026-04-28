import 'dart:convert';
import 'dart:typed_data';

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

  static bool isDemoUser(String email) =>
      demoUsers.containsKey(email.toLowerCase().trim());
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
  static const String proofPhotoBucket = 'collection-proof-photos';

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
        'This email is already registered. Please sign in instead.',
      );
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
        await client.from('drivers').upsert({
          'user_id': userId,
          'name': name,
          'phone': '',
        }, ignoreDuplicates: true);
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
  // QR VERIFICATION
  // ═══════════════════════════════════════════════════════════════════════════

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) return Map<String, dynamic>.from(jsonDecode(value));
    throw Exception('Unexpected server response.');
  }

  static Future<Map<String, dynamic>> createQrPayload({
    required int vendorId,
    required int recordId,
  }) async {
    final res = await client.rpc(
      'create_qr_token',
      params: {'p_vendor_id': vendorId, 'p_record_id': recordId},
    );
    return _asMap(res);
  }

  static Future<Map<String, dynamic>?> getLatestQrPayloadForRecord({
    required int vendorId,
    required int recordId,
  }) async {
    final res = await client
        .from('qr_tokens')
        .select('token, vendor_id, record_id, created_at')
        .eq('vendor_id', vendorId)
        .eq('record_id', recordId)
        .eq('is_used', false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;
    return {
      'vendor_id': res['vendor_id'],
      'record_id': res['record_id'],
      'timestamp': res['created_at'],
      'token': res['token'],
    };
  }

  static Future<Map<String, dynamic>> getOrCreateQrPayload({
    required int vendorId,
    required int recordId,
  }) async {
    final existing = await getLatestQrPayloadForRecord(
      vendorId: vendorId,
      recordId: recordId,
    );
    if (existing != null) return existing;
    return createQrPayload(vendorId: vendorId, recordId: recordId);
  }

  static Future<Map<String, dynamic>> verifyQrPickup({
    required String token,
    required int vendorId,
    required int recordId,
    required int driverId,
    required double driverLat,
    required double driverLng,
  }) async {
    final res = await client.rpc(
      'verify_qr_pickup',
      params: {
        'p_token': token,
        'p_vendor_id': vendorId,
        'p_record_id': recordId,
        'p_driver_id': driverId,
        'p_driver_lat': driverLat,
        'p_driver_lng': driverLng,
        'p_scanned_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    return _asMap(res);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WASTE RECORDS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getAllRecords() async {
    final res = await client
        .from('waste_records')
        .select(
          '*, vendors(name, shopName), drivers(name), '
          'collection_proof_photos(id, storage_bucket, storage_path, image_url, '
          'mime_type, file_size, uploaded_at, review_status)',
        )
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getPendingRecords() async {
    final res = await client
        .from('waste_records')
        .select('*, vendors(name, shopName, address)')
        .eq('status', 'Pending')
        .order('id', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<List<Map<String, dynamic>>> getVendorRecords(
    int vendorId,
  ) async {
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
        .select('*, vendors(name, shopName, address), drivers(name)')
        .eq('status', 'Collected')
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  /// Fetch ALL records (pending + collected) with vendor info — for driver dashboard.
  static Future<List<Map<String, dynamic>>> getAllRecordsForDriver() async {
    final res = await client
        .from('waste_records')
        .select('*, vendors(name, shopName, address), drivers(name)')
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<Map<String, dynamic>> declareWaste({
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
    final inserted = await client
        .from('waste_records')
        .insert(record)
        .select()
        .single();
    await createQrPayload(vendorId: vendorId, recordId: inserted['id']);
    return Map<String, dynamic>.from(inserted);
  }

  static Future<void> collectRecord({
    required int recordId,
    required int driverId,
    required double verifiedWaste,
    required bool qrScanned,
    required bool photoAdded,
    required String timestamp,
  }) async {
    await client
        .from('waste_records')
        .update({
          'driverId': driverId,
          'verifiedWaste': verifiedWaste,
          'status': 'Collected',
          'timestamp': timestamp,
          'qrScanned': qrScanned,
          'photoAdded': photoAdded,
        })
        .eq('id', recordId);
  }

  static Future<Map<String, dynamic>> uploadCollectionProofPhoto({
    required int recordId,
    required int vendorId,
    required int driverId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final ext = _photoExtension(fileName, mimeType);
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final storagePath = 'record_$recordId/driver_${driverId}_$timestamp.$ext';

    await client.storage
        .from(proofPhotoBucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    final proof = await client
        .from('collection_proof_photos')
        .insert({
          'record_id': recordId,
          'vendor_id': vendorId,
          'driver_id': driverId,
          'storage_bucket': proofPhotoBucket,
          'storage_path': storagePath,
          'image_url': client.storage
              .from(proofPhotoBucket)
              .getPublicUrl(storagePath),
          'mime_type': mimeType,
          'file_size': bytes.length,
          'review_status': 'available',
        })
        .select()
        .single();

    await client
        .from('waste_records')
        .update({'photoAdded': true})
        .eq('id', recordId);

    return Map<String, dynamic>.from(proof);
  }

  static Future<Map<String, dynamic>?> getLatestProofPhoto(int recordId) async {
    final res = await client
        .from('collection_proof_photos')
        .select()
        .eq('record_id', recordId)
        .order('uploaded_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  static Future<String> createProofPhotoSignedUrl(
    Map<String, dynamic> proof, {
    int expiresInSeconds = 600,
  }) async {
    final bucket = proof['storage_bucket']?.toString() ?? proofPhotoBucket;
    final path = proof['storage_path']?.toString();
    if (path == null || path.isEmpty) {
      throw Exception('Proof photo storage path is missing.');
    }
    return client.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
  }

  static Future<void> markProofPhotoViewed(int proofPhotoId) async {
    await client
        .from('collection_proof_photos')
        .update({
          'admin_viewed_at': DateTime.now().toUtc().toIso8601String(),
          'admin_viewed_by': currentUser?.id,
        })
        .eq('id', proofPhotoId);
  }

  static String _photoExtension(String fileName, String mimeType) {
    final lowerName = fileName.toLowerCase();
    if (mimeType.contains('png') || lowerName.endsWith('.png')) return 'png';
    if (mimeType.contains('webp') || lowerName.endsWith('.webp')) return 'webp';
    return 'jpg';
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
