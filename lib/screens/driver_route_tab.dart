import 'package:flutter/material.dart';
import 'package:swm_vendor/services/supabase_service.dart';
import 'package:swm_vendor/services/location_service.dart';
import 'package:swm_vendor/theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DriverRouteTab extends StatefulWidget {
  const DriverRouteTab({super.key});

  @override
  State<DriverRouteTab> createState() => _DriverRouteTabState();
}

class _DriverRouteTabState extends State<DriverRouteTab> {
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  LatLng? _userLocation;

  static const LatLng _fallbackCenter = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _pending = await SupabaseService.getPendingRecords();
    } catch (_) {}
    _userLocation = await LocationService.getCurrentLocation();
    if (mounted) setState(() => _loading = false);
  }

  LatLng _vendorLocation(dynamic vendorIdRaw) {
    final center = _userLocation ?? _fallbackCenter;
    final vId = int.tryParse(vendorIdRaw.toString()) ?? 1;
    final offsetLat = (vId % 15) * 0.006 * (vId % 2 == 0 ? 1 : -1);
    final offsetLng = (vId % 10) * 0.006 * (vId % 3 == 0 ? 1 : -1);
    return LatLng(center.latitude + offsetLat, center.longitude + offsetLng);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Today\'s Route',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _load,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // ── Map view ───────────────────────────────────────────────────
          Container(
            height: 200,
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _userLocation ?? _fallbackCenter,
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.swmvendor.app',
                  ),
                  MarkerLayer(
                    markers: [
                      // Vendor stop markers
                      ..._pending.map((r) {
                        final loc = _vendorLocation(r['vendorId']);
                        return Marker(
                          point: loc,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                          ),
                        );
                      }),
                      // Current user / driver location marker
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
                              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                            ),
                            child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('Upcoming Stops',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (!_loading)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${_pending.length}',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Stop list ────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _pending.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 56, color: Colors.green[400]),
                            const SizedBox(height: 12),
                            const Text('All pickups done!',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black54)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _pending.length,
                          itemBuilder: (context, index) {
                            final r = _pending[index];
                            final vendor = r['vendors'];
                            final isLast = index == _pending.length - 1;
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Timeline column
                                  SizedBox(
                                    width: 36,
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 28, height: 28,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppTheme.primary,
                                          ),
                                          child: Center(
                                            child: Text('${index + 1}',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        if (!isLast)
                                          Expanded(
                                            child: Container(
                                              width: 2,
                                              color: Colors.grey[200],
                                              margin: const EdgeInsets.symmetric(vertical: 4),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Stop card
                                  Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(bottom: isLast ? 8 : 16),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey[200]!),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.03),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2)),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  vendor?['name'] ?? 'Vendor #${r['vendorId']}',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15),
                                                ),
                                                if (vendor?['shopName'] != null) ...[
                                                  const SizedBox(height: 2),
                                                  Text(vendor!['shopName'],
                                                      style: const TextStyle(
                                                          color: Colors.black45,
                                                          fontSize: 12)),
                                                ],
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${r['declaredWaste']} kg  •  ${r['wasteType'] ?? '—'}',
                                                  style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange[50],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text('Pending',
                                                style: TextStyle(
                                                    color: Colors.orange[700],
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
