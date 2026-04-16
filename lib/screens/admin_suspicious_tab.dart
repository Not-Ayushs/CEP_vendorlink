import 'package:flutter/material.dart';

class AdminSuspiciousTab extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const AdminSuspiciousTab({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    final padding = isMobile ? 16.0 : 32.0;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ───────────────────────────────────────────────────────
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Suspicious Activity',
                style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 6),
        Text('${records.length} flagged record${records.length == 1 ? '' : 's'}',
            style: const TextStyle(color: Colors.black45, fontSize: 13)),
        const SizedBox(height: 20),

        // ── List ────────────────────────────────────────────────────────
        if (records.isEmpty)
          Expanded(
            child: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green[400]),
                const SizedBox(height: 16),
                const Text('No suspicious activities!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                const Text('All records look clean.',
                    style: TextStyle(color: Colors.black45)),
              ]),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final r = records[i];
                final vendor = r['vendors'];
                final driver = r['drivers'];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ── Title row ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Record #${r['id']}  •  ${r['timestamp']?.isNotEmpty == true ? r['timestamp'] : 'No time'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.red[700],
                              borderRadius: BorderRadius.circular(10)),
                          child: const Text('FLAGGED',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // ── Info grid — scrollable on mobile ──────────────
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: _info('Vendor', vendor?['name'] ?? 'N/A')),
                                Expanded(child: _info('Driver', driver?['name'] ?? 'Unassigned')),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: _info('Declared', '${r['declaredWaste']} kg')),
                                Expanded(child: _info('Verified', '${r['verifiedWaste']} kg')),
                              ]),
                            ],
                          )
                        : Row(children: [
                            Expanded(child: _info('Vendor', vendor?['name'] ?? 'N/A')),
                            Expanded(child: _info('Driver', driver?['name'] ?? 'Unassigned')),
                            Expanded(child: _info('Declared', '${r['declaredWaste']} kg')),
                            Expanded(child: _info('Verified', '${r['verifiedWaste']} kg')),
                          ]),

                    const SizedBox(height: 14),

                    // ── Reasons ───────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${r['_reasons'] ?? '—'}',
                                style: TextStyle(
                                    color: Colors.red[900],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _info(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black45,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ],
      );
}
