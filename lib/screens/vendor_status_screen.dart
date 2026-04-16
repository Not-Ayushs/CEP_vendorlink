import 'package:flutter/material.dart';

class VendorStatusScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bool isPending = currentStatus == 'Pending Pickup';

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
          child: isPending
              ? _buildPendingView()
              : _buildCollectedView(),
        ),
      ),
    );
  }

  Widget _buildPendingView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.yellow[50], // Yellow for pending
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
          _buildInfoRow('Declared Load', '$declaredWaste ($wasteType)'),
        ],
      ),
    );
  }

  Widget _buildCollectedView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.green[50], // Green for collected
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
}
