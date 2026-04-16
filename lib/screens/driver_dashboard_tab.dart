import 'package:flutter/material.dart';
import 'package:swm_vendor/services/supabase_service.dart';
import 'package:swm_vendor/theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_vendor_detail_screen.dart';

class DriverDashboardTab extends StatefulWidget {
  const DriverDashboardTab({super.key});

  @override
  State<DriverDashboardTab> createState() => _DriverDashboardTabState();
}

class _DriverDashboardTabState extends State<DriverDashboardTab> {
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _collected = [];
  List<Map<String, dynamic>> _all = [];
  Map<String, dynamic>? _driverProfile;
  
  bool _loading = true;
  bool _isMapView = false;
  int? _expandedId;
  String _filter = 'Pending'; // Pending | Collected
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final MapController _mapController = MapController();

  static const LatLng _mumbaiCenter = LatLng(19.0760, 72.8777);

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
      _pending = _all.where((r) => r['status'] == 'Pending').toList();
      _collected = _all.where((r) => r['status'] == 'Collected').toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredByStatus =>
      _filter == 'Pending' ? _pending : _collected;

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

  // Generate deterministic mock coordinates based on Vendor ID near Mumbai
  LatLng _getMockLocation(dynamic vendorIdRaw) {
    final vId = int.tryParse(vendorIdRaw.toString()) ?? 1;
    final offsetLat = (vId % 15) * 0.008 * (vId % 2 == 0 ? 1 : -1);
    final offsetLng = (vId % 10) * 0.008 * (vId % 3 == 0 ? 1 : -1);
    return LatLng(_mumbaiCenter.latitude + offsetLat, _mumbaiCenter.longitude + offsetLng);
  }

  Future<void> _launchNavigation(LatLng loc) async {
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${loc.latitude},${loc.longitude}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open map navigation')),
        );
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
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Dashboard',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  if (_driverProfile != null)
                    Text('Hi, ${_driverProfile!['name']}',
                        style: const TextStyle(color: Colors.black54)),
                ]),
                Row(
                  children: [
                    IconButton(
                        icon: Icon(_isMapView ? Icons.list_alt_rounded : Icons.map_outlined),
                        color: _isMapView ? AppTheme.primary : Colors.grey[700],
                        tooltip: _isMapView ? 'Switch to List View' : 'Switch to Map View',
                        onPressed: () {
                          setState(() => _isMapView = !_isMapView);
                        }),
                    IconButton(
                        icon: const Icon(Icons.refresh_rounded), onPressed: _load),
                  ],
                ),
              ],
            ),
          ),

          // ── Route Summary — 3 stat cards ──────────────────────────────────
          if (!_isMapView)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total',
                    value: '${_all.length}',
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
                    value: '${_collected.length}',
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
                    value: '${_pending.length}',
                    bgColor: Colors.orange[50]!,
                    borderColor: Colors.orange[100]!,
                    iconColor: Colors.orange[600]!,
                    valueColor: Colors.orange[700]!,
                    icon: Icons.pending_actions_rounded,
                  ),
                ),
              ]),
            ),

          // ── Search & Filters ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search vendor by name…',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500], size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: Colors.grey[400], size: 20),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  label: 'Pending (${_pending.length})',
                  selected: _filter == 'Pending',
                  onTap: () => setState(() => _filter = 'Pending'),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: 'Collected (${_collected.length})',
                  selected: _filter == 'Collected',
                  onTap: () => setState(() => _filter = 'Collected'),
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
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20), 
        topRight: Radius.circular(20)
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mumbaiCenter,
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.swmvendor.app',
              ),
              MarkerLayer(
                markers: _filteredAndSearched.map((r) {
                  final loc = _getMockLocation(r['vendorId']);
                  final isCollected = r['status'] == 'Collected';
                  final isSelected = _expandedId == r['id'];
                  return Marker(
                    point: loc,
                    width: isSelected ? 50 : 40,
                    height: isSelected ? 50 : 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_expandedId == r['id']) {
                            _expandedId = null;
                            _isMapView = false; // Optional logic: could stay on map, but user asked to open map from card
                          } else {
                            _expandedId = r['id'];
                            _mapController.move(loc, 14.0);
                          }
                        });
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
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
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
                }).toList(),
              ),
            ],
          ),
          // Floating Vendor Card Overlay on Map
          if (_expandedId != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: _buildVendorExpandableTile(
                _filteredAndSearched.firstWhere((r) => r['id'] == _expandedId),
                forceExpand: true,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_filteredAndSearched.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                _filter == 'Pending' ? Icons.check_circle_outline : Icons.inbox_outlined,
                size: 64,
                color: _filter == 'Pending' ? Colors.green[400] : Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
                _searchQuery.isNotEmpty
                    ? 'No matching vendors'
                    : _filter == 'Pending'
                        ? 'All caught up!'
                        : 'No collected pickups',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: _filteredAndSearched.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final r = _filteredAndSearched[i];
          return _buildVendorExpandableTile(r, forceExpand: false);
        },
      ),
    );
  }

  Widget _buildVendorExpandableTile(Map<String, dynamic> r, {bool forceExpand = false}) {
    final vendor = r['vendors'];
    final isCollected = r['status'] == 'Collected';
    final isExpanded = forceExpand || _expandedId == r['id'];
    final loc = _getMockLocation(r['vendorId']);
    
    // Mock details
    final mockAddress = 'Sector ${(r['vendorId'] as int?) is int ? (r['vendorId'] as int) % 15 + 1 : 1}, Andheri West, Mumbai';
    final distMock = ((r['vendorId'] as int?) is int ? (r['vendorId'] as int) % 5 + 1.5 : 2.0).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isExpanded ? AppTheme.primary.withValues(alpha: 0.3) : Colors.grey[200]!,
            width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
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
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: isCollected ? Colors.green[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(
                        isCollected ? Icons.check_circle_rounded : Icons.pending_actions,
                        color: isCollected ? Colors.green[600] : Colors.orange[600],
                        size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendor?['name'] ?? 'Vendor #${r['vendorId']}',
                            style: TextStyle(
                                fontWeight: isExpanded ? FontWeight.w800 : FontWeight.bold, 
                                fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${r['declaredWaste']} kg  •  ${r['wasteType'] ?? '—'}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCollected ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      r['status'] ?? '',
                      style: TextStyle(
                        color: isCollected ? Colors.green[700] : Colors.orange[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                    color: Colors.grey[400]
                  ),
                ]),
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
                    _InfoRow(icon: Icons.location_on_outlined, text: mockAddress),
                    const SizedBox(height: 6),
                    _InfoRow(icon: Icons.directions_car_outlined, text: '$distMock km away'),
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.notes_outlined, 
                      text: (r['notes'] != null && r['notes'].toString().isNotEmpty) 
                          ? r['notes'] 
                          : 'No special instructions given.'
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _launchNavigation(loc),
                            icon: const Icon(Icons.navigation_outlined, size: 18),
                            label: const Text('Navigate'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue[700],
                              side: BorderSide(color: Colors.blue[200]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (!_isMapView) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _expandedId = r['id'];
                                  _isMapView = true;
                                });
                                // Small delay to allow view switch then center map
                                Future.delayed(const Duration(milliseconds: 300), () {
                                  _mapController.move(loc, 14.0);
                                });
                              },
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('View on Map'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
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
                        icon: const Icon(Icons.qr_code_scanner, size: 18, color: Colors.white),
                        label: const Text('Complete Pickup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

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
          border: Border.all(color: selected ? AppTheme.primary : Colors.grey[300]!),
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
    required this.label, required this.value, required this.bgColor,
    required this.borderColor, required this.iconColor, required this.valueColor,
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
          Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: valueColor)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ],
      ),
    );
  }
}
