import 'package:flutter/material.dart';
import 'package:swm_vendor/theme/app_theme.dart';

class AdminRecordsTab extends StatefulWidget {
  final List<Map<String, dynamic>> records;
  final bool Function(Map<String, dynamic>) isFlagged;

  const AdminRecordsTab({super.key, required this.records, required this.isFlagged});

  @override
  State<AdminRecordsTab> createState() => _AdminRecordsTabState();
}

class _AdminRecordsTabState extends State<AdminRecordsTab> {
  String _statusFilter = 'All';

  static const _filters = ['All', 'Pending', 'Collected'];

  List<Map<String, dynamic>> get _filtered => widget.records.where((r) {
        if (_statusFilter != 'All' && r['status'] != _statusFilter) return false;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    final padding = isMobile ? 16.0 : 32.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Master Records',
              style: TextStyle(
                  fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold)),
          SizedBox(height: isMobile ? 16 : 24),

          // ── Scrollable filter chips ───────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._filters.map((f) {
                  final selected = _statusFilter == f;
                  final count = f == 'All'
                      ? widget.records.length
                      : widget.records.where((r) => r['status'] == f).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _FilterChip(
                      label: '$f ($count)',
                      selected: selected,
                      onTap: () => setState(() => _statusFilter = f),
                    ),
                  );
                }),
                // Flagged filter
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _FilterChip(
                    label: 'Flagged (${widget.records.where(widget.isFlagged).length})',
                    selected: _statusFilter == 'Flagged',
                    flagged: true,
                    onTap: () => setState(() => _statusFilter = 'Flagged'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('${_filtered.length} record${_filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.black45, fontSize: 13)),
          ),

          // ── Content ─────────────────────────────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: Colors.black26),
                        const SizedBox(height: 12),
                        const Text('No records found.',
                            style: TextStyle(color: Colors.black45)),
                      ],
                    ),
                  )
                : isMobile
                    ? _buildCardList()
                    : _buildDataTable(),
          ),
        ],
      ),
    );
  }

  // ── Flagged filter (custom): records flagged by isFlagged fn ─────────
  List<Map<String, dynamic>> get _filteredWithFlagged {
    if (_statusFilter == 'Flagged') {
      return widget.records.where(widget.isFlagged).toList();
    }
    return _filtered;
  }

  // ── Mobile: card list ──────────────────────────────────────────────────
  Widget _buildCardList() {
    final list = _statusFilter == 'Flagged' ? _filteredWithFlagged : _filtered;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            const Text('No records found.',
                style: TextStyle(color: Colors.black45)),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: list.length,
      padding: const EdgeInsets.only(bottom: 24),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = list[i];
        final flagged = widget.isFlagged(r);
        final vendor = r['vendors'];
        final driver = r['drivers'];
        final isCollected = r['status'] == 'Collected';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: flagged ? Colors.red[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: flagged ? Colors.red[200]! : Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Record #${r['id']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          fontSize: 12)),
                  Row(children: [
                    _statusChip(r['status'], isCollected),
                    if (flagged) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.flag, color: Colors.red, size: 16),
                    ],
                  ]),
                ],
              ),
              const SizedBox(height: 10),
              _cardRow(Icons.storefront_outlined, vendor?['name'] ?? 'Unknown Vendor'),
              const SizedBox(height: 6),
              _cardRow(Icons.local_shipping_outlined,
                  driver?['name'] ?? (isCollected ? 'Unknown Driver' : 'Unassigned')),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _wasteInfo('Declared', '${r['declaredWaste']} kg'),
                  _wasteInfo('Verified',
                      isCollected ? '${r['verifiedWaste']} kg' : '—'),
                  _wasteInfo('Type', r['wasteType'] ?? '—'),
                ],
              ),
              if (flagged && (r['_reasons'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(r['_reasons'],
                          style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _cardRow(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.black45),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _wasteInfo(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 11, color: Colors.black45, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87)),
    ]);
  }

  Widget _statusChip(String status, bool isCollected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isCollected ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isCollected ? Colors.green[200]! : Colors.orange[200]!),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isCollected ? Colors.green[700] : Colors.orange[700])),
    );
  }

  // ── Desktop: DataTable ─────────────────────────────────────────────────
  Widget _buildDataTable() {
    final list = _statusFilter == 'Flagged' ? _filteredWithFlagged : _filtered;
    if (list.isEmpty) {
      return const Center(
          child: Text('No records found.',
              style: TextStyle(color: Colors.black45)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Vendor')),
            DataColumn(label: Text('Driver')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Declared (kg)')),
            DataColumn(label: Text('Verified (kg)')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Flag')),
          ],
          rows: list.map((r) {
            final flagged = widget.isFlagged(r);
            final vendor = r['vendors'];
            final driver = r['drivers'];
            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>(
                  (_) => flagged ? Colors.red[50] : null),
              cells: [
                DataCell(Text('#${r['id']}')),
                DataCell(Text(vendor?['name'] ?? 'N/A')),
                DataCell(Text(driver?['name'] ?? 'Unassigned')),
                DataCell(Text(r['wasteType'] ?? '—')),
                DataCell(Text('${r['declaredWaste']} kg')),
                DataCell(Text(
                    r['status'] == 'Collected'
                        ? '${r['verifiedWaste']} kg'
                        : '—')),
                DataCell(Text(r['status'],
                    style: TextStyle(
                        color: r['status'] == 'Collected'
                            ? Colors.green[700]
                            : Colors.orange[700],
                        fontWeight: FontWeight.w600))),
                DataCell(flagged
                    ? const Icon(Icons.flag, color: Colors.red, size: 20)
                    : const Icon(Icons.check, color: Colors.green, size: 20)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Reusable horizontal filter chip used in admin/vendor/driver screens.
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool flagged;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.flagged = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = flagged ? Colors.red : AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : Colors.grey[300]!,
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
