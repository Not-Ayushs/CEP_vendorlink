import 'package:flutter/material.dart';
import 'package:swm_vendor/services/supabase_service.dart';

class VendorHistoryTab extends StatefulWidget {
  const VendorHistoryTab({super.key});

  @override
  State<VendorHistoryTab> createState() => _VendorHistoryTabState();
}

class _VendorHistoryTabState extends State<VendorHistoryTab> {
  String _activeFilter = 'All';
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await SupabaseService.getCurrentVendorProfile();
      if (profile != null) {
        _records = await SupabaseService.getVendorRecords(profile['id']);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_activeFilter == 'All') return _records;
    return _records.where((r) {
      final status = r['status'] ?? '';
      if (_activeFilter == 'Flagged') {
        // Flagged: collected but mismatch or missing photo/qr
        if (status != 'Collected') return false;
        final declared = (r['declaredWaste'] as num?)?.toDouble() ?? 0;
        final verified = (r['verifiedWaste'] as num?)?.toDouble() ?? 0;
        final qr = r['qrScanned'] == true || r['qrScanned'] == 1;
        final photo = r['photoAdded'] == true || r['photoAdded'] == 1;
        return (declared - verified).abs() > 2 || !photo || !qr;
      }
      return status == _activeFilter;
    }).toList();
  }

  int _count(String tag) {
    if (tag == 'All') return _records.length;
    if (tag == 'Flagged') {
      return _records.where((r) {
        if (r['status'] != 'Collected') return false;
        final declared = (r['declaredWaste'] as num?)?.toDouble() ?? 0;
        final verified = (r['verifiedWaste'] as num?)?.toDouble() ?? 0;
        final qr = r['qrScanned'] == true || r['qrScanned'] == 1;
        final photo = r['photoAdded'] == true || r['photoAdded'] == 1;
        return (declared - verified).abs() > 2 || !photo || !qr;
      }).length;
    }
    return _records.where((r) => r['status'] == tag).length;
  }

  String _resolveTag(Map<String, dynamic> r) {
    final status = r['status'] ?? 'Pending';
    if (status == 'Collected') {
      final declared = (r['declaredWaste'] as num?)?.toDouble() ?? 0;
      final verified = (r['verifiedWaste'] as num?)?.toDouble() ?? 0;
      final qr = r['qrScanned'] == true || r['qrScanned'] == 1;
      final photo = r['photoAdded'] == true || r['photoAdded'] == 1;
      if ((declared - verified).abs() > 2 || !photo || !qr) return 'Flagged';
      return 'Collected';
    }
    return status;
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'Collected', 'Pending', 'Flagged'];

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
                const Text('Pickup History',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text('${_count('Collected')} of ${_records.length} collected',
                        style: const TextStyle(color: Colors.black45, fontSize: 12)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 22),
                      onPressed: _load,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Scrollable filter chips ──────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: filters.map((f) {
                final selected = _activeFilter == f;
                final count = _count(f);

                // Determine chip color per tag
                Color activeCol;
                switch (f) {
                  case 'Collected': activeCol = Colors.green[600]!; break;
                  case 'Pending':   activeCol = Colors.orange[700]!; break;
                  case 'Flagged':   activeCol = Colors.red[600]!; break;
                  default:          activeCol = Colors.blueGrey[700]!;
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? activeCol : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected ? activeCol : Colors.grey[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(f,
                              style: TextStyle(
                                  color: selected ? Colors.white : Colors.black54,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 13)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.3)
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$count',
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.black45,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 48, color: Colors.black26),
                            const SizedBox(height: 12),
                            Text('No $_activeFilter entries',
                                style: const TextStyle(color: Colors.black45)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _filtered[index];
                            final tag = _resolveTag(item);
                            final driver = item['drivers'];

                            return _HistoryCard(
                              amount: '${item['declaredWaste']} kg',
                              type: item['wasteType'] ?? 'Mixed',
                              date: (item['timestamp'] ?? '').toString().isNotEmpty
                                  ? item['timestamp']
                                  : '—',
                              tag: tag,
                              driverName: driver?['name'],
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

class _HistoryCard extends StatelessWidget {
  final String amount;
  final String type;
  final String date;
  final String tag;
  final String? driverName;
  const _HistoryCard({
    required this.amount,
    required this.type,
    required this.date,
    required this.tag,
    this.driverName,
  });

  @override
  Widget build(BuildContext context) {
    late Color tagColor;
    late Color tagBg;
    late IconData tagIcon;
    switch (tag) {
      case 'Collected':
        tagColor = Colors.green[700]!;
        tagBg = Colors.green[50]!;
        tagIcon = Icons.check_circle_outline;
        break;
      case 'Pending':
        tagColor = Colors.orange[700]!;
        tagBg = Colors.orange[50]!;
        tagIcon = Icons.access_time_outlined;
        break;
      default:
        tagColor = Colors.red[700]!;
        tagBg = Colors.red[50]!;
        tagIcon = Icons.flag_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: tagBg, shape: BoxShape.circle),
            child: Icon(tagIcon, color: tagColor, size: 20),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$amount  •  $type',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(date,
                        style: const TextStyle(
                            color: Colors.black45, fontSize: 12)),
                    if (driverName != null) ...[
                      Text('  •  ',
                          style: TextStyle(color: Colors.grey[300], fontSize: 12)),
                      Icon(Icons.local_shipping_rounded,
                          size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Text(driverName!,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: tagBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(tag,
                style: TextStyle(
                    color: tagColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
