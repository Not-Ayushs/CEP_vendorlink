import 'package:flutter/material.dart';
import 'package:swm_vendor/services/supabase_service.dart';
import 'package:swm_vendor/theme/app_theme.dart';

class DriverVendorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> record;
  final Map<String, dynamic>? driverProfile;

  const DriverVendorDetailScreen({
    super.key,
    required this.record,
    this.driverProfile,
  });

  @override
  State<DriverVendorDetailScreen> createState() => _DriverVendorDetailScreenState();
}

class _DriverVendorDetailScreenState extends State<DriverVendorDetailScreen> {
  bool _qrScanned = false;
  bool _photoAdded = false;
  bool _submitting = false;
  final _verifiedCtrl = TextEditingController();

  // Mock previous pickup history
  static const List<Map<String, String>> _mockHistory = [
    {'date': 'Apr 12, 10:30 AM', 'amount': '12 kg', 'type': 'Organic', 'status': 'Collected'},
    {'date': 'Apr 10, 09:15 AM', 'amount': '8 kg', 'type': 'Plastic', 'status': 'Collected'},
    {'date': 'Apr 7, 11:00 AM', 'amount': '20 kg', 'type': 'Mixed', 'status': 'Collected'},
  ];

  void _scan() {
    setState(() => _qrScanned = true);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ QR scanned successfully!'),
          behavior: SnackBarBehavior.floating,
        ));
  }

  void _photo() {
    setState(() => _photoAdded = true);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📷 Photo uploaded successfully!'),
          behavior: SnackBarBehavior.floating,
        ));
  }

  void _callVendor() {
    final vendor = widget.record['vendors'];
    final name = vendor?['name'] ?? 'Vendor';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Calling $name…'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blue[700],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmAndCollect() async {
    final weight = double.tryParse(_verifiedCtrl.text);
    if (weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter verified waste weight'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.primary),
            SizedBox(width: 10),
            Text('Confirm Collection'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to mark this pickup as collected?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Declared: ${widget.record['declaredWaste']} kg',
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Verified: $weight kg',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  if ((widget.record['declaredWaste'] as num).toDouble() != weight)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange[700], size: 16),
                          const SizedBox(width: 6),
                          Text('Weight mismatch detected',
                              style: TextStyle(
                                  color: Colors.orange[700], fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _markCollected(weight);
  }

  Future<void> _markCollected(double weight) async {
    setState(() => _submitting = true);
    final now = DateTime.now();
    final ts = '${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    try {
      await SupabaseService.collectRecord(
        recordId: widget.record['id'],
        driverId: widget.driverProfile?['id'] ?? 1,
        verifiedWaste: weight,
        qrScanned: _qrScanned,
        photoAdded: _photoAdded,
        timestamp: ts,
      );
      if (mounted) {
        // Show success snackbar with animation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.celebration_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pickup Completed!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Collection recorded successfully',
                          style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() { _verifiedCtrl.dispose(); super.dispose(); }

  IconData _wasteIcon(String type) {
    switch (type.toLowerCase()) {
      case 'organic': return Icons.eco_rounded;
      case 'plastic': return Icons.recycling_rounded;
      case 'paper': return Icons.description_rounded;
      case 'e-waste': return Icons.devices_rounded;
      default: return Icons.delete_rounded;
    }
  }

  Color _wasteColor(String type) {
    switch (type.toLowerCase()) {
      case 'organic': return Colors.green[600]!;
      case 'plastic': return Colors.blue[600]!;
      case 'paper': return Colors.brown[600]!;
      case 'e-waste': return Colors.purple[600]!;
      default: return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final vendor = r['vendors'];
    final bool canCollect = _qrScanned && _photoAdded;
    final wasteType = r['wasteType'] ?? 'Mixed';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Pickup Details', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ── Vendor Info Card ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vendor?['name'] ?? 'Vendor #${r['vendorId']}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          if (vendor?['shopName'] != null) ...[
                            const SizedBox(height: 4),
                            Text(vendor!['shopName'], style: const TextStyle(color: Colors.black54)),
                          ],
                        ],
                      ),
                    ),
                    // Call Vendor Button
                    Material(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _callVendor,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(Icons.phone_rounded,
                              color: Colors.blue[600], size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Declared Waste', style: TextStyle(color: Colors.black54)),
                  Text('${r['declaredWaste']} kg',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Waste Type', style: TextStyle(color: Colors.black54)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _wasteColor(wasteType).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_wasteIcon(wasteType),
                            size: 16, color: _wasteColor(wasteType)),
                        const SizedBox(width: 6),
                        Text(wasteType,
                            style: TextStyle(
                                color: _wasteColor(wasteType),
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                ]),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Previous Pickup History ───────────────────────────────────────
            const Text('Previous Pickups',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._mockHistory.map((h) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: Colors.grey[400]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${h['amount']}  •  ${h['type']}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(h['date']!,
                            style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(h['status']!,
                        style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 24),

            // ── Verification ─────────────────────────────────────────────────
            const Text('Verification', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildAction(Icons.qr_code_scanner, 'Scan Vendor QR',
                _qrScanned ? 'Matched ✓' : 'Tap to simulate', _qrScanned, _qrScanned ? null : _scan),
            const SizedBox(height: 12),
            _buildAction(Icons.camera_alt, 'Upload Waste Photo',
                _photoAdded ? 'Uploaded ✓' : 'Tap to simulate', _photoAdded, _photoAdded ? null : _photo),
            const SizedBox(height: 24),
            AnimatedOpacity(
              opacity: canCollect ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 300),
              child: TextFormField(
                controller: _verifiedCtrl,
                enabled: canCollect,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Verified Waste Weight (kg)',
                  hintText: 'Actual measured weight',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50],
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: (canCollect && !_submitting) ? _confirmAndCollect : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor: Colors.grey[300],
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Mark Collected',
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            if (!canCollect)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Complete QR scan and photo first',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45, fontSize: 12)),
              ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, String title, String subtitle, bool done, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: done ? Colors.green[300]! : Colors.grey[200]!),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: done ? Colors.green[50] : Colors.grey[100], shape: BoxShape.circle),
            child: Icon(icon, color: done ? Colors.green[600] : Colors.grey[600]),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: done ? Colors.green[700] : Colors.black54)),
          ])),
          if (!done) Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400])
          else Icon(Icons.check, color: Colors.green[600]),
        ]),
      ),
    );
  }
}
