import 'package:flutter/material.dart';

class AdminDashboardTab extends StatelessWidget {
  final int totalPickups;
  final int completed;
  final int pending;
  final int flagged;
  final VoidCallback? onRefresh;

  const AdminDashboardTab({
    super.key,
    required this.totalPickups,
    required this.completed,
    required this.pending,
    required this.flagged,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    final padding = isMobile ? 16.0 : 32.0;
    final mapHeight = isMobile ? 220.0 : 380.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview',
              style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          SizedBox(height: isMobile ? 16 : 24),

          // ── Stat cards: 2x2 grid on mobile, 1 row on desktop ──────────
          isMobile
              ? GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.8,
                  children: [
                    _buildStatCard('Total', totalPickups.toString(), Colors.blue),
                    _buildStatCard('Completed', completed.toString(), Colors.green),
                    _buildStatCard('Pending', pending.toString(), Colors.orange),
                    _buildStatCard('Flagged', flagged.toString(), Colors.red),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _buildStatCard('Total Pickups', totalPickups.toString(), Colors.blue)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Completed', completed.toString(), Colors.green)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Pending', pending.toString(), Colors.orange)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Flagged', flagged.toString(), Colors.red)),
                  ],
                ),

          SizedBox(height: isMobile ? 28 : 48),

          Text('Live Territory Map',
              style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          Container(
            height: mapHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.map, size: 56, color: Colors.black26),
                const SizedBox(height: 12),
                const Text('Map View Placeholder',
                    style: TextStyle(fontSize: 16, color: Colors.black45, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('$totalPickups records • $pending pending • $flagged flagged',
                    style: const TextStyle(fontSize: 12, color: Colors.black38)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: color[700])),
          ),
        ],
      ),
    );
  }
}
