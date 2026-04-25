import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:swm_vendor/services/supabase_service.dart';
import 'package:swm_vendor/theme/app_theme.dart';
import 'vendor_declare_waste_screen.dart';
import 'vendor_status_screen.dart';

class VendorDashboardTab extends StatefulWidget {
  const VendorDashboardTab({super.key});

  @override
  State<VendorDashboardTab> createState() => _VendorDashboardTabState();
}

class _VendorDashboardTabState extends State<VendorDashboardTab> {
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _vendorProfile;
  Map<String, dynamic>? _qrPayload;
  bool _loading = true;
  bool _qrLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _vendorProfile = await SupabaseService.getCurrentVendorProfile();
      if (_vendorProfile != null) {
        _records = await SupabaseService.getVendorRecords(
          _vendorProfile!['id'],
        );
        await _loadQrForLatestPending();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _latest =>
      _records.isNotEmpty ? _records.first : null;
  String get _currentStatus => _latest?['status'] ?? 'Collected';
  String get _declaredWaste =>
      _latest != null ? '${_latest!['declaredWaste']} kg' : '0 kg';
  String get _wasteType => _latest?['wasteType'] ?? 'N/A';

  // Weekly summary calculations
  double get _totalWaste {
    double sum = 0;
    for (final r in _records) {
      sum += (r['declaredWaste'] as num?)?.toDouble() ?? 0;
    }
    return sum;
  }

  int get _collectedCount =>
      _records.where((r) => r['status'] == 'Collected').length;

  Map<String, dynamic>? get _lastCollected {
    try {
      return _records.firstWhere((r) => r['status'] == 'Collected');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadQrForLatestPending() async {
    final latest = _records.isNotEmpty ? _records.first : null;
    if (latest == null || latest['status'] != 'Pending') {
      _qrPayload = null;
      return;
    }

    _qrLoading = true;
    _qrPayload = await SupabaseService.getOrCreateQrPayload(
      vendorId: latest['vendorId'],
      recordId: latest['id'],
    );
    _qrLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    final bool isPending = _currentStatus == 'Pending';

    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading dashboard…', style: TextStyle(color: Colors.black45)),
          ],
        ),
      );
    }
    if (_error != null) return Center(child: Text('Error: $_error'));
    if (_vendorProfile == null) {
      return const Center(child: Text('Vendor profile not found.'));
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Vendor Dashboard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Welcome, ${_vendorProfile!['shopName'] ?? _vendorProfile!['name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Weekly Summary Cards ────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.scale_rounded,
                          label: 'This Week',
                          value: '${_totalWaste.toStringAsFixed(1)} kg',
                          bgColor: Colors.teal[50]!,
                          iconColor: Colors.teal[600]!,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.check_circle_rounded,
                          label: 'Collected',
                          value: '$_collectedCount',
                          bgColor: Colors.green[50]!,
                          iconColor: Colors.green[600]!,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.inventory_2_rounded,
                          label: 'Total',
                          value: '${_records.length}',
                          bgColor: Colors.blue[50]!,
                          iconColor: Colors.blue[600]!,
                        ),
                      ),
                    ],
                  ),

                  // ── Last Pickup Details ─────────────────────────────────────
                  if (_lastCollected != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.purple[100]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.purple[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.local_shipping_rounded,
                              color: Colors.purple[700],
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Last Pickup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_lastCollected!['declaredWaste']} kg • ${_lastCollected!['wasteType'] ?? 'Mixed'}',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                if ((_lastCollected!['drivers']
                                        as Map?)?['name'] !=
                                    null)
                                  Text(
                                    'by ${_lastCollected!['drivers']['name']}',
                                    style: TextStyle(
                                      color: Colors.purple[400],
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if ((_lastCollected!['timestamp'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Text(
                              _lastCollected!['timestamp'],
                              style: TextStyle(
                                color: Colors.purple[400],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Status Card
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VendorStatusScreen(
                            currentStatus: _currentStatus,
                            declaredWaste: _declaredWaste,
                            wasteType: _wasteType,
                          ),
                        ),
                      );
                      _load();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.yellow[50] : Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPending
                              ? Colors.orange[200]!
                              : Colors.green[200]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isPending
                                        ? Icons.access_time_filled
                                        : Icons.check_circle,
                                    color: isPending
                                        ? Colors.orange[700]
                                        : Colors.green[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _currentStatus,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isPending
                                          ? Colors.orange[800]
                                          : Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: isPending
                                    ? Colors.orange[400]
                                    : Colors.green[400],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (isPending) ...[
                            Text(
                              'Declared: $_declaredWaste • $_wasteType',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Pickup expected within 2 hours',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ] else
                            const Text(
                              'No pending pickup. Declare new waste.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 16),
                    _buildQrCard(),
                  ],
                  const SizedBox(height: 32),

                  // Declare button
                  ElevatedButton(
                    onPressed: isPending
                        ? null
                        : () async {
                            final ok = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VendorDeclareWasteScreen(
                                  vendorId: _vendorProfile!['id'],
                                ),
                              ),
                            );
                            if (ok == true) _load();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      disabledBackgroundColor: Colors.grey[300],
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isPending ? 'Pickup Pending…' : 'Declare Waste',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  const Text(
                    'Recent Activity',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_records.isEmpty)
                    const Text(
                      'No records yet.',
                      style: TextStyle(color: Colors.black45),
                    )
                  else
                    ..._records.take(10).map(_buildActivityTile),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> r) {
    final isCollected = r['status'] == 'Collected';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r['declaredWaste']} kg • ${r['wasteType']}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if ((r['timestamp'] ?? '').isNotEmpty)
                  Text(
                    'At ${r['timestamp']}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCollected ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              r['status'],
              style: TextStyle(
                color: isCollected ? Colors.green[700] : Colors.orange[700],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    final latest = _latest;
    final verified = latest?['qr_verified'] == true;
    final qrData = _qrPayload == null ? null : jsonEncode(_qrPayload);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.qr_code_2_rounded,
                color: verified ? Colors.green[700] : AppTheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  verified
                      ? 'Driver verified pickup'
                      : 'Pickup Verification QR',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_qrLoading)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: 'Refresh QR',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _load,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (qrData == null)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Generating QR...',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 190,
              backgroundColor: Colors.white,
            ),
          const SizedBox(height: 10),
          Text(
            verified
                ? 'Scan completed at ${latest?['scan_time'] ?? 'server time'}'
                : 'Show this QR to the driver at pickup.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: verified ? Colors.green[700] : Colors.black54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary card for weekly stats ───────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color bgColor;
  final Color iconColor;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.bgColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
