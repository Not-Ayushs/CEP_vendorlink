import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class WasteRecord {
  final int? id;
  final int vendorId;
  final int? driverId;
  final double declaredWaste;
  final double verifiedWaste;
  final String status; // 'Pending' | 'Collected'
  final String timestamp;
  final bool qrScanned;
  final bool photoAdded;
  final String wasteType;

  // Denormalized display fields (populated via JOIN)
  final String? vendorName;
  final String? driverName;

  const WasteRecord({
    this.id,
    required this.vendorId,
    this.driverId,
    required this.declaredWaste,
    this.verifiedWaste = 0.0,
    this.status = 'Pending',
    this.timestamp = '',
    this.qrScanned = false,
    this.photoAdded = false,
    this.wasteType = 'Mixed',
    this.vendorName,
    this.driverName,
  });

  bool get isFlagged {
    if (status == 'Collected' && (declaredWaste - verifiedWaste).abs() > 2) return true;
    if (status == 'Collected' && !photoAdded) return true;
    if (status == 'Collected' && !qrScanned) return true;
    return false;
  }

  List<String> get flagReasons {
    List<String> reasons = [];
    if (status == 'Collected' && (declaredWaste - verifiedWaste).abs() > 2) reasons.add('Weight mismatch');
    if (status == 'Collected' && !photoAdded) reasons.add('Missing photo');
    if (status == 'Collected' && !qrScanned) reasons.add('QR not scanned');
    return reasons;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'vendorId': vendorId,
      'driverId': driverId,
      'declaredWaste': declaredWaste,
      'verifiedWaste': verifiedWaste,
      'status': status,
      'timestamp': timestamp,
      'qrScanned': qrScanned ? 1 : 0,
      'photoAdded': photoAdded ? 1 : 0,
      'wasteType': wasteType,
    };
  }

  factory WasteRecord.fromMap(Map<String, dynamic> map) {
    return WasteRecord(
      id: map['id'],
      vendorId: map['vendorId'],
      driverId: map['driverId'],
      declaredWaste: (map['declaredWaste'] as num).toDouble(),
      verifiedWaste: (map['verifiedWaste'] as num).toDouble(),
      status: map['status'],
      timestamp: map['timestamp'] ?? '',
      qrScanned: map['qrScanned'] == 1,
      photoAdded: map['photoAdded'] == 1,
      wasteType: map['wasteType'] ?? 'Mixed',
      vendorName: map['vendorName'],
      driverName: map['driverName'],
    );
  }

  WasteRecord copyWith({
    int? id,
    int? vendorId,
    int? driverId,
    double? declaredWaste,
    double? verifiedWaste,
    String? status,
    String? timestamp,
    bool? qrScanned,
    bool? photoAdded,
    String? wasteType,
    String? vendorName,
    String? driverName,
  }) {
    return WasteRecord(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      driverId: driverId ?? this.driverId,
      declaredWaste: declaredWaste ?? this.declaredWaste,
      verifiedWaste: verifiedWaste ?? this.verifiedWaste,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      qrScanned: qrScanned ?? this.qrScanned,
      photoAdded: photoAdded ?? this.photoAdded,
      wasteType: wasteType ?? this.wasteType,
      vendorName: vendorName ?? this.vendorName,
      driverName: driverName ?? this.driverName,
    );
  }
}

class VendorModel {
  final int? id;
  final String name;
  final String shopName;
  final String phone;
  final String address;

  const VendorModel({
    this.id,
    required this.name,
    required this.shopName,
    required this.phone,
    required this.address,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'shopName': shopName,
    'phone': phone,
    'address': address,
  };

  factory VendorModel.fromMap(Map<String, dynamic> map) => VendorModel(
    id: map['id'],
    name: map['name'],
    shopName: map['shopName'],
    phone: map['phone'],
    address: map['address'],
  );
}

class DriverModel {
  final int? id;
  final String name;
  final String phone;

  const DriverModel({this.id, required this.name, required this.phone});

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'phone': phone,
  };

  factory DriverModel.fromMap(Map<String, dynamic> map) => DriverModel(
    id: map['id'],
    name: map['name'],
    phone: map['phone'],
  );
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  DatabaseHelper._internal();

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'swm_vendor.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vendors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        shopName TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE drivers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE waste_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendorId INTEGER NOT NULL,
        driverId INTEGER,
        declaredWaste REAL NOT NULL,
        verifiedWaste REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'Pending',
        timestamp TEXT NOT NULL DEFAULT '',
        qrScanned INTEGER NOT NULL DEFAULT 0,
        photoAdded INTEGER NOT NULL DEFAULT 0,
        wasteType TEXT NOT NULL DEFAULT 'Mixed',
        FOREIGN KEY (vendorId) REFERENCES vendors(id),
        FOREIGN KEY (driverId) REFERENCES drivers(id)
      )
    ''');

    // --- Seed Demo Data ---
    await db.insert('vendors', {
      'name': 'Amit Sharma',
      'shopName': 'Sharma Groceries',
      'phone': '+91 9876543210',
      'address': '142 Market Street, North Zone',
    });
    await db.insert('vendors', {
      'name': 'Priya Nair',
      'shopName': 'City Cafe',
      'phone': '+91 9812345678',
      'address': '88 Central Avenue, South Zone',
    });
    await db.insert('vendors', {
      'name': 'Tech Corp Ltd.',
      'shopName': 'Green Tech Office',
      'phone': '+91 9800011122',
      'address': 'Tech Park Block B, East Zone',
    });

    await db.insert('drivers', {'name': 'Rajesh Kumar', 'phone': '+91 9111222333'});
    await db.insert('drivers', {'name': 'Amit Singh', 'phone': '+91 9444555666'});

    // Some initial records (one pending, one collected, one flagged)
    await db.insert('waste_records', {
      'vendorId': 1,
      'driverId': 1,
      'declaredWaste': 15.0,
      'verifiedWaste': 15.0,
      'status': 'Collected',
      'timestamp': '10:30 AM',
      'qrScanned': 1,
      'photoAdded': 1,
      'wasteType': 'Organic',
    });
    await db.insert('waste_records', {
      'vendorId': 2,
      'driverId': null,
      'declaredWaste': 8.0,
      'verifiedWaste': 0.0,
      'status': 'Pending',
      'timestamp': '',
      'qrScanned': 0,
      'photoAdded': 0,
      'wasteType': 'Mixed',
    });
    await db.insert('waste_records', {
      'vendorId': 3,
      'driverId': 1,
      'declaredWaste': 25.0,
      'verifiedWaste': 10.0, // Intentional mismatch → flagged
      'status': 'Collected',
      'timestamp': '09:15 AM',
      'qrScanned': 1,
      'photoAdded': 0, // Missing photo
      'wasteType': 'Plastic',
    });
  }

  // ─── VENDOR CRUD ────────────────────────────────────────────────────
  Future<int> insertVendor(VendorModel vendor) async {
    final d = await db;
    return d.insert('vendors', vendor.toMap());
  }

  Future<VendorModel?> getVendorById(int id) async {
    final d = await db;
    final res = await d.query('vendors', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return VendorModel.fromMap(res.first);
  }

  Future<List<VendorModel>> getAllVendors() async {
    final d = await db;
    final res = await d.query('vendors');
    return res.map(VendorModel.fromMap).toList();
  }

  // ─── DRIVER CRUD ─────────────────────────────────────────────────────
  Future<int> insertDriver(DriverModel driver) async {
    final d = await db;
    return d.insert('drivers', driver.toMap());
  }

  Future<DriverModel?> getDriverById(int id) async {
    final d = await db;
    final res = await d.query('drivers', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return null;
    return DriverModel.fromMap(res.first);
  }

  // ─── WASTE RECORD CRUD ───────────────────────────────────────────────
  Future<int> insertWasteRecord(WasteRecord record) async {
    final d = await db;
    return d.insert('waste_records', record.toMap());
  }

  Future<int> updateWasteRecord(WasteRecord record) async {
    final d = await db;
    return d.update(
      'waste_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<List<WasteRecord>> getAllRecordsWithNames() async {
    final d = await db;
    final res = await d.rawQuery('''
      SELECT
        wr.*,
        v.name   AS vendorName,
        v.shopName,
        d.name   AS driverName
      FROM waste_records wr
      LEFT JOIN vendors v ON wr.vendorId = v.id
      LEFT JOIN drivers d ON wr.driverId = d.id
      ORDER BY wr.id DESC
    ''');
    return res.map(WasteRecord.fromMap).toList();
  }

  Future<List<WasteRecord>> getPendingRecordsWithNames() async {
    final d = await db;
    final res = await d.rawQuery('''
      SELECT
        wr.*,
        v.name   AS vendorName,
        v.shopName,
        d.name   AS driverName
      FROM waste_records wr
      LEFT JOIN vendors v ON wr.vendorId = v.id
      LEFT JOIN drivers d ON wr.driverId = d.id
      WHERE wr.status = 'Pending'
      ORDER BY wr.id ASC
    ''');
    return res.map(WasteRecord.fromMap).toList();
  }

  Future<List<WasteRecord>> getRecordsByVendorId(int vendorId) async {
    final d = await db;
    final res = await d.rawQuery('''
      SELECT
        wr.*,
        v.name   AS vendorName,
        d.name   AS driverName
      FROM waste_records wr
      LEFT JOIN vendors v ON wr.vendorId = v.id
      LEFT JOIN drivers d ON wr.driverId = d.id
      WHERE wr.vendorId = ?
      ORDER BY wr.id DESC
    ''', [vendorId]);
    return res.map(WasteRecord.fromMap).toList();
  }
}
