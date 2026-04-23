import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:swm_vendor/services/location_service.dart';

class VendorStatusScreen extends StatefulWidget {
  final String currentStatus;
  final String declaredWaste;
  final String wasteType;

  const VendorStatusScreen({
    super.key,
    required this.currentStatus,
    required this.declaredWaste,
    required this.wasteType,
  });

  @override
  State<VendorStatusScreen> createState() => _VendorStatusScreenState();
}

class _VendorStatusScreenState extends State<VendorStatusScreen> {
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

  @override
  Widget build(BuildContext context) {
    final bool isPending = widget.currentStatus == 'Pending Pickup';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pickup Status', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMapView(isPending),
              const SizedBox(height: 20),
              isPending ? _buildPendingView() : _buildCollectedView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.yellow[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.time_to_leave, size: 64, color: Colors.orange[600]),
          const SizedBox(height: 16),
          Text(
            'Driver En Route',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange[800]),
          ),
          const SizedBox(height: 8),
          const Text('Expected arrival: 1:45 PM', style: TextStyle(color: Colors.black87, fontSize: 16)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _buildInfoRow('Driver Name', 'Rajesh Kumar'),
          const SizedBox(height: 16),
          _buildInfoRow('Contact', '+91 9876543210'),
          const SizedBox(height: 16),
          _buildInfoRow('Declared Load', '${widget.declaredWaste} (${widget.wasteType})'),
        ],
      ),
    );
  }

  Widget _buildCollectedView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green[600]),
          const SizedBox(height: 16),
          Text(
            'Successfully Collected',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[800]),
          ),
          const SizedBox(height: 8),
          const Text('Last pickup: Today at 10:30 AM', style: TextStyle(color: Colors.black87, fontSize: 16)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _buildInfoRow('Driver Name', 'Amit Singh'),
          const SizedBox(height: 16),
          _buildInfoRow('Load Collected', '15 kg (Organic)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.black54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87)),
      ],
    );
  }

  Widget _buildMapView(bool isPending) {
    // Vendor location = user's real GPS (they ARE the vendor)
    final vendorLoc = _userLocation ?? _fallback;

    // Mock driver location ~600m away from vendor
    final driverLoc = LatLng(vendorLoc.latitude - 0.005, vendorLoc.longitude + 0.004);

    return Container(
      height: 220,
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
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: vendorLoc,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.swmvendor.app',
            ),
            MarkerLayer(
              markers: [
                // Vendor (user) location marker
                Marker(
                  point: vendorLoc,
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPending ? Colors.orange : Colors.green,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Icon(
                      isPending ? Icons.storefront : Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                // Mock driver position marker (only when pending)
                if (isPending)
                  Marker(
                    point: driverLoc,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue[700],
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
