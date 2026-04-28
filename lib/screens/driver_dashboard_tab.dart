import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:swm_vendor/services/supabase_service.dart';
import 'package:swm_vendor/services/location_service.dart';
import 'package:swm_vendor/theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_vendor_detail_screen.dart';

class DriverDashboardTab extends StatefulWidget {
  const DriverDashboardTab({super.key});

  @override
  State<DriverDashboardTab> createState() => _DriverDashboardTabState();
}

class _DriverDashboardTabState extends State<DriverDashboardTab> {
  List<Map<String, dynamic>> _all = [];
  Map<String, dynamic>? _driverProfile;

  LatLng? _userLocation;
  bool _locationDenied = false;
  LocationPermission _locationPermission = LocationPermission.denied;

  bool _loading = true;
  bool _isMapView = false;
  int? _expandedId;
  String _filter = 'Pending'; // Pending | Collected
  String _searchQuery = '';
  bool _routeLoading = false;
  String? _routeError;
  List<LatLng> _routePoints = [];
  final _searchCtrl = TextEditingController();
  final MapController _mapController = MapController();

  static const LatLng _mumbaiCenter = LatLng(19.0760, 72.8777);
  static const double _nearbyRadiusKm = 10;
  final Distance _distance = const Distance();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _driverProfile = await SupabaseService.getCurrentDriverProfile();
      _all = await SupabaseService.getAllRecordsForDriver();
    } catch (_) {}

    // Fetch real GPS location on every load
    _locationPermission = await LocationService.requestPermission();
    if (_locationPermission == LocationPermission.always ||
        _locationPermission == LocationPermission.whileInUse) {
      _userLocation = await LocationService.getCurrentLocation();
      _locationDenied = _userLocation == null;
    } else {
      _userLocation = null;
      _locationDenied = true;
    }

    if (mounted) {
      setState(() {
        _loading = false;
        if (!_filteredAndSearched.any((r) => r['id'] == _expandedId)) {
          _expandedId = null;
          _routePoints = [];
          _routeError = null;
          _routeLoading = false;
        }
      });
      if (_locationDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocationService.permissionMessage(_locationPermission),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredByStatus =>
      _nearbyRecords.where((r) => r['status'] == _filter).toList();

  List<Map<String, dynamic>> get _nearbyRecords {
    // If driver location is unavailable, show ALL records so the driver
    // never sees a blank screen just because GPS failed.
    if (_userLocation == null) return List<Map<String, dynamic>>.from(_all);

    return _all.where((r) {
      final loc = _recordLocation(r);
      // Records without coordinates (submitted before GPS was added) are always
      // included — we just can't show a distance for them.
      if (loc == null) return true;
      return _distance.as(LengthUnit.Kilometer, _userLocation!, loc) <=
          _nearbyRadiusKm;
    }).toList();
  }

  List<Map<String, dynamic>> get _nearbyPending =>
      _nearbyRecords.where((r) => r['status'] == 'Pending').toList();

  List<Map<String, dynamic>> get _nearbyCollected =>
      _nearbyRecords.where((r) => r['status'] == 'Collected').toList();

  List<Map<String, dynamic>> get _filteredAndSearched {
    if (_searchQuery.isEmpty) return _filteredByStatus;
    final q = _searchQuery.toLowerCase();
    return _filteredByStatus.where((r) {
      final vendor = r['vendors'];
      final name = (vendor?['name'] ?? '').toString().toLowerCase();
      final shop = (vendor?['shopName'] ?? '').toString().toLowerCase();
      return name.contains(q) || shop.contains(q);
    }).toList();
  }

  Map<String, dynamic>? get _selectedVisibleRecord {
    for (final record in _filteredAndSearched) {
      if (record['id'] == _expandedId) return record;
    }
    return null;
  }

  LatLng? _recordLocation(Map<String, dynamic> record) {
    final lat = (record['lat'] as num?)?.toDouble();
    final lng = (record['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String _distanceLabel(Map<String, dynamic> record) {
    final loc = _recordLocation(record);
    if (_userLocation == null || loc == null) return 'Location unavailable';
    final km = _distance.as(LengthUnit.Kilometer, _userLocation!, loc);
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  Future<void> _selectRecord(
    Map<String, dynamic> record, {
    bool showMap = false,
  }) async {
    final loc = _recordLocation(record);
    if (loc == null) return;

    setState(() {
      _expandedId = record['id'];
      if (showMap) _isMapView = true;
      _routeLoading = true;
      _routeError = null;
      _routePoints = [];
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      _mapController.move(loc, 14.5);
    });

    await _loadRouteTo(loc);
  }

  Future<void> _loadRouteTo(LatLng destination) async {
    final origin = _userLocation;
    if (origin == null) {
      setState(() {
        _routeLoading = false;
        _routeError = 'Driver location unavailable';
      });
      return;
    }

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw Exception('Route service unavailable');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        throw Exception('No route found');
      }

      final coordinates =
          routes.first['geometry']['coordinates'] as List<dynamic>;
      final points = coordinates.map((c) {
        final pair = c as List<dynamic>;
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList();

      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _routeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _routePoints = [origin, destination];
        _routeLoading = false;
        _routeError = 'Showing direct path. Route service did not respond.';
      });
    }
  }

  Future<void> _launchNavigation(LatLng loc) async {
    // On Android 11+, canLaunchUrl() returns false for https:// URLs unless
    // <queries> intents are declared. We skip the check and call launchUrl
    // directly — it handles the failure case cleanly.

    // Primary: Google Maps navigation URL (works on iOS + Android via browser/app)
    final mapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}',
    );

    // Fallback: geo: URI — natively opens the Maps app on Android
    final geoUrl = Uri.parse(
      'geo:${loc.latitude},${loc.longitude}?q=${loc.latitude},${loc.longitude}',
    );

    try {
      final launched = await launchUrl(
        mapsUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        // Try geo: URI as fallback (Android-native)
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Last resort: try geo: URI
      try {
        await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open maps. Install Google Maps and try again.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_driverProfile != null)
                      Text(
                        'Hi, ${_driverProfile!['name']}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isMapView
                            ? Icons.list_alt_rounded
                            : Icons.map_outlined,
                      ),
                      color: _isMapView ? AppTheme.primary : Colors.grey[700],
                      tooltip: _isMapView
                          ? 'Switch to List View'
                          : 'Switch to Map View',
                      onPressed: () {
                        setState(() => _isMapView = !_isMapView);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _load,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Route Summary — 3 stat cards ──────────────────────────────────
          if (!_isMapView)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total',
                      value: '${_nearbyRecords.length}',
                      bgColor: Colors.blue[50]!,
                      borderColor: Colors.blue[100]!,
                      iconColor: Colors.blue[600]!,
                      valueColor: Colors.blue[700]!,
                      icon: Icons.assignment_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Done',
                      value: '${_nearbyCollected.length}',
                      bgColor: Colors.green[50]!,
                      borderColor: Colors.green[100]!,
                      iconColor: Colors.green[600]!,
                      valueColor: Colors.green[700]!,
                      icon: Icons.check_circle_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Left',
                      value: '${_nearbyPending.length}',
                      bgColor: Colors.orange[50]!,
                      borderColor: Colors.orange[100]!,
                      iconColor: Colors.orange[600]!,
                      valueColor: Colors.orange[700]!,
                      icon: Icons.pending_actions_rounded,
                    ),
                  ),
                ],
              ),
            ),

          // ── Search & Filters ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() {
                _searchQuery = v;
                _expandedId = null;
                _routePoints = [];
              }),
              decoration: InputDecoration(
                hintText: 'Search vendor by name…',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey[500],
                  size: 22,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchQuery = '';
                            _expandedId = null;
                            _routePoints = [];
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _FilterChip(
                  label: 'Pending (${_nearbyPending.length})',
                  selected: _filter == 'Pending',
                  onTap: () => setState(() {
                    _filter = 'Pending';
                    _expandedId = null;
                    _routePoints = [];
                  }),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: 'Collected (${_nearbyCollected.length})',
                  selected: _filter == 'Collected',
                  onTap: () => setState(() {
                    _filter = 'Collected';
                    _expandedId = null;
                    _routePoints = [];
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Content Area (Map or List) ───────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _isMapView
                ? _buildMobileFriendlyMap()
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFriendlyMap() {
    final mapCenter = _userLocation ?? _mumbaiCenter;

    // Build vendor markers — only for records that have GPS coordinates.
    // Records without lat/lng still appear in the list view.
    final vendorMarkers = _filteredAndSearched
        .where((r) => _recordLocation(r) != null)
        .map((r) {
      final loc = _recordLocation(r)!;
      final isCollected = r['status'] == 'Collected';
      final isSelected = _expandedId == r['id'];
      return Marker(
        point: loc,
        width: isSelected ? 50 : 40,
        height: isSelected ? 50 : 40,
        child: GestureDetector(
          onTap: () {
            if (_expandedId == r['id']) {
              setState(() {
                _expandedId = null;
                _routePoints = [];
                _routeError = null;
              });
            } else {
              _selectRecord(r);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCollected ? Colors.green : Colors.orange,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              isCollected ? Icons.check : Icons.local_shipping_rounded,
              color: Colors.white,
              size: isSelected ? 24 : 20,
            ),
          ),
        ),
      );
    }).toList();

    // "You are here" blue marker
    if (_userLocation != null) {
      vendorMarkers.add(
        Marker(
          point: _userLocation!,
          width: 48,
          height: 48,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue[600],
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: mapCenter, initialZoom: 13.0),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.swmvendor.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: AppTheme.primary,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(markers: vendorMarkers),
            ],
          ),

          // "Re-center" FAB
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              elevation: 3,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _mapController.move(mapCenter, 13.0),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _userLocation != null
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                    color: _userLocation != null
                        ? Colors.blue[700]
                        : Colors.grey[600],
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          // Floating Vendor Card Overlay on Map
          if (_expandedId != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Builder(
                builder: (_) {
                  final selected = _selectedVisibleRecord;
                  if (selected == null) return const SizedBox.shrink();
                  return _buildVendorExpandableTile(
                    selected,
                    forceExpand: true,
                  );
                },
              ),
            ),
          if (_routeLoading || _routeError != null)
            Positioned(
              left: 20,
              right: 20,
              top: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8),
                  ],
                ),
                child: Row(
                  children: [
                    if (_routeLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.route_outlined,
                        size: 18,
                        color: Colors.orange[700],
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _routeLoading ? 'Finding route...' : _routeError!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_filteredAndSearched.isEmpty) {
      final message = _searchQuery.isNotEmpty
          ? 'No matching vendors found'
          : _filter == 'Pending'
          ? 'No pending pickups'
          : 'No collected pickups yet';
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _filter == 'Pending'
                  ? Icons.check_circle_outline
                  : Icons.inbox_outlined,
              size: 64,
              color: _filter == 'Pending'
                  ? Colors.green[400]
                  : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            if (_userLocation != null) ...[
              const SizedBox(height: 8),
              Text(
                'Showing vendors within ${_nearbyRadiusKm.toStringAsFixed(0)} km of you.',
                style: const TextStyle(color: Colors.black45, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const SizedBox(height: 8),
              const Text(
                'Enable location for distance-based filtering.',
                style: TextStyle(color: Colors.black45, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: _filteredAndSearched.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final r = _filteredAndSearched[i];
          return _buildVendorExpandableTile(r, forceExpand: false);
        },
      ),
    );
  }

  Widget _buildVendorExpandableTile(
    Map<String, dynamic> r, {
    bool forceExpand = false,
  }) {
    final vendor = r['vendors'];
    final isCollected = r['status'] == 'Collected';
    final isExpanded = forceExpand || _expandedId == r['id'];
    // loc may be null for records submitted without GPS — handle safely
    final loc = _recordLocation(r);
    final address = (vendor?['address'] ?? '').toString().trim().isNotEmpty
        ? vendor!['address'].toString()
        : loc != null
            ? '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}'
            : 'Location not captured';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? AppTheme.primary.withValues(alpha: 0.3)
              : Colors.grey[200]!,
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Standard Header (always visible)
            InkWell(
              onTap: () {
                setState(() {
                  if (_expandedId == r['id'] && !forceExpand) {
                    _expandedId = null;
                  } else {
                    _expandedId = r['id'];
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isCollected
                            ? Colors.green[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCollected
                            ? Icons.check_circle_rounded
                            : Icons.pending_actions,
                        color: isCollected
                            ? Colors.green[600]
                            : Colors.orange[600],
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendor?['name'] ?? 'Vendor #${r['vendorId']}',
                            style: TextStyle(
                              fontWeight: isExpanded
                                  ? FontWeight.w800
                                  : FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r['declaredWaste']} kg  •  ${r['wasteType'] ?? '—'}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCollected
                            ? Colors.green[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r['status'] ?? '',
                        style: TextStyle(
                          color: isCollected
                              ? Colors.green[700]
                              : Colors.orange[700],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),

            // Expanded Details Section
            if (isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 16),
                    const SizedBox(height: 8),

                    // Info rows
                    _InfoRow(icon: Icons.location_on_outlined, text: address),
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.directions_car_outlined,
                      text: _distanceLabel(r),
                    ),
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.notes_outlined,
                      text: (r['notes'] != null &&
                              r['notes'].toString().isNotEmpty)
                          ? r['notes']
                          : 'No special instructions given.',
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons — only shown when location is available
                    if (loc != null)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _launchNavigation(loc),
                              icon: const Icon(
                                Icons.navigation_outlined,
                                size: 18,
                              ),
                              label: const Text('Open Maps'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue[700],
                                side: BorderSide(color: Colors.blue[200]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          if (!_isMapView) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _selectRecord(r, showMap: true),
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: const Text('Show Route'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  side: BorderSide(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                    if (!isCollected) ...[
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverVendorDetailScreen(
                                record: r,
                                driverProfile: _driverProfile,
                              ),
                            ),
                          );
                          _load();
                        },
                        icon: const Icon(
                          Icons.qr_code_scanner,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text('Complete Pickup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black54,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final Color valueColor;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.valueColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
