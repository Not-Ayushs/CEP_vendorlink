import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:swm_vendor/services/location_service.dart';

class AdminDashboardTab extends StatefulWidget {
  final int totalPickups;
  final int completed;
  final int pending;
  final int flagged;
  final List<Map<String, dynamic>> records;
  final VoidCallback? onRefresh;

  const AdminDashboardTab({
    super.key,
    required this.totalPickups,
    required this.completed,
    required this.pending,
    required this.flagged,
    required this.records,
    this.onRefresh,
  });

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  LatLng? _userLocation;
  static const LatLng _fallback = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final loc = await LocationService.getCurrentLocation();
    if (mounted) setState(() => _userLocation = loc);
  }

  /// Deterministic vendor position anchored to real location (or fallback).
  LatLng _vendorLocation(dynamic vendorIdRaw) {
    final center = _userLocation ?? _fallback;
    final vId = int.tryParse(vendorIdRaw.toString()) ?? 1;
    final offsetLat = (vId % 15) * 0.006 * (vId % 2 == 0 ? 1 : -1);
    final offsetLng = (vId % 10) * 0.006 * (vId % 3 == 0 ? 1 : -1);
    return LatLng(center.latitude + offsetLat, center.longitude + offsetLng);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    final padding = isMobile ? 16.0 : 32.0;
    final mapHeight = isMobile ? 220.0 : 380.0;
    final mapCenter = _userLocation ?? _fallback;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),

          // ── Stat cards: 2x2 grid on mobile, 1 row on desktop ──────────
          isMobile
              ? GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    _buildStatCard(
                      'Total',
                      widget.totalPickups.toString(),
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Completed',
                      widget.completed.toString(),
                      Colors.green,
                    ),
                    _buildStatCard(
                      'Pending',
                      widget.pending.toString(),
                      Colors.orange,
                    ),
                    _buildStatCard(
                      'Flagged',
                      widget.flagged.toString(),
                      Colors.red,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Pickups',
                        widget.totalPickups.toString(),
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Completed',
                        widget.completed.toString(),
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Pending',
                        widget.pending.toString(),
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Flagged',
                        widget.flagged.toString(),
                        Colors.red,
                      ),
                    ),
                  ],
                ),

          SizedBox(height: isMobile ? 28 : 48),

          // Map section header with location status
          Row(
            children: [
              Text(
                'Live Territory Map',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _userLocation != null ? Icons.location_on : Icons.location_off,
                size: 16,
                color: _userLocation != null ? Colors.green[600] : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                _userLocation != null ? 'Live' : 'Default view',
                style: TextStyle(
                  fontSize: 12,
                  color: _userLocation != null
                      ? Colors.green[700]
                      : Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: mapHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: mapCenter,
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.swmvendor.app',
                  ),
                  MarkerLayer(
                    markers: [
                      // Vendor record markers
                      ...widget.records.map((r) {
                        final loc = _vendorLocation(r['vendorId']);
                        final isCollected = r['status'] == 'Collected';
                        return Marker(
                          point: loc,
                          width: isCollected ? 32 : 40,
                          height: isCollected ? 32 : 40,
                          child: Tooltip(
                            message: r['vendors']?['name'] ?? 'Vendor',
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCollected
                                    ? Colors.green
                                    : Colors.orange,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isCollected
                                    ? Icons.check
                                    : Icons.local_shipping_rounded,
                                color: Colors.white,
                                size: isCollected ? 16 : 20,
                              ),
                            ),
                          ),
                        );
                      }),
                      // Admin / viewer current location
                      if (_userLocation != null)
                        Marker(
                          point: _userLocation!,
                          width: 48,
                          height: 48,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue[700],
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 6),
                              ],
                            ),
                            child: const Icon(
                              Icons.my_location_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
