import 'package:flutter/material.dart';

class AdminExportTab extends StatelessWidget {
  const AdminExportTab({super.key});

  void _export(BuildContext context, String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export successful as $format!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    final padding = isMobile ? 16.0 : 32.0;

    final csvOption = _buildExportOption(
      context,
      title: 'Export as CSV',
      subtitle: 'Comma-separated, open in any spreadsheet app',
      icon: Icons.grid_on_rounded,
      color: Colors.blue,
      onTap: () => _export(context, 'CSV'),
    );

    final excelOption = _buildExportOption(
      context,
      title: 'Export as Excel',
      subtitle: 'Full spreadsheet with formatting',
      icon: Icons.table_chart_rounded,
      color: Colors.green,
      onTap: () => _export(context, 'Excel'),
    );

    final pdfOption = _buildExportOption(
      context,
      title: 'Export as PDF',
      subtitle: 'Print-ready audit report',
      icon: Icons.picture_as_pdf_rounded,
      color: Colors.red,
      onTap: () => _export(context, 'PDF'),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Export Data',
              style: TextStyle(
                  fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
            'Download records for offline processing or auditing.',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          SizedBox(height: isMobile ? 24 : 40),

          // ── Layout: Column on mobile, Wrap on desktop ─────────────────
          isMobile
              ? Column(
                  children: [
                    csvOption,
                    const SizedBox(height: 14),
                    excelOption,
                    const SizedBox(height: 14),
                    pdfOption,
                  ],
                )
              : Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [csvOption, excelOption, pdfOption],
                ),

          SizedBox(height: isMobile ? 24 : 48),

          // ── Info box ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Exports include all records visible in the Records tab, filtered by the same criteria.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isMobile = MediaQuery.of(context).size.width <= 800;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: isMobile ? double.infinity : 240,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: isMobile
            // ── Mobile: horizontal row ──────────────────────────────────
            ? Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
              ])
            // ── Desktop: vertical card ────────────────────────────────
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black45),
                      textAlign: TextAlign.center),
                ],
              ),
      ),
    );
  }
}
