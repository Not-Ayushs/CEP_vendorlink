import 'package:flutter/material.dart';
import 'package:swm_vendor/services/supabase_service.dart';
import 'package:swm_vendor/theme/app_theme.dart';
import 'package:swm_vendor/utils/logout_helper.dart';
import 'admin_dashboard_tab.dart';
import 'admin_records_tab.dart';
import 'admin_suspicious_tab.dart';
import 'admin_export_tab.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _allRecords = [];
  bool _loading = true;

  static const _navItems = [
    (icon: Icons.dashboard,           label: 'Dashboard',          isLogout: false),
    (icon: Icons.table_chart,         label: 'Records',            isLogout: false),
    (icon: Icons.warning_amber_rounded, label: 'Suspicious',        isLogout: false),
    (icon: Icons.download,            label: 'Export',             isLogout: false),
    (icon: Icons.logout,              label: 'Logout',             isLogout: true),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _allRecords = await SupabaseService.getAllRecords();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  bool _isFlagged(Map<String, dynamic> r) {
    if (r['status'] != 'Collected') return false;
    final decl = (r['declaredWaste'] as num).toDouble();
    final verif = (r['verifiedWaste'] as num).toDouble();
    if ((decl - verif).abs() > 2) return true;
    if (r['photoAdded'] == false) return true;
    if (r['qrScanned'] == false) return true;
    return false;
  }

  List<String> _flagReasons(Map<String, dynamic> r) {
    final reasons = <String>[];
    final decl = (r['declaredWaste'] as num).toDouble();
    final verif = (r['verifiedWaste'] as num).toDouble();
    if ((decl - verif).abs() > 2) reasons.add('Weight mismatch');
    if (r['photoAdded'] == false) reasons.add('Missing photo');
    if (r['qrScanned'] == false) reasons.add('QR not scanned');
    return reasons;
  }

  void _onMenuSelected(int index, {bool closeDrawer = false}) {
    if (closeDrawer && Navigator.canPop(context)) Navigator.pop(context);
    if (index == 4) {
      performLogout(context);
      return;
    }
    setState(() => _selectedIndex = index);
    _loadData();
  }

  // ── Computed values ─────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _flagged => _allRecords.where(_isFlagged).toList();
  List<Map<String, dynamic>> get _flaggedWithReasons =>
      _flagged.map((r) => {...r, '_reasons': _flagReasons(r).join(', ')}).toList();
  int get _completed => _allRecords.where((r) => r['status'] == 'Collected').length;
  int get _pending => _allRecords.where((r) => r['status'] == 'Pending').length;

  String get _currentTitle => _navItems[_selectedIndex < 4 ? _selectedIndex : 3].label;

  Widget get _currentBody {
    switch (_selectedIndex) {
      case 0:
        return AdminDashboardTab(
          totalPickups: _allRecords.length,
          completed: _completed,
          pending: _pending,
          flagged: _flagged.length,
          records: _allRecords,
          onRefresh: _loadData,
        );
      case 1:
        return AdminRecordsTab(records: _allRecords, isFlagged: _isFlagged);
      case 2:
        return AdminSuspiciousTab(records: _flaggedWithReasons);
      default:
        return const AdminExportTab();
    }
  }

  // ── Sidebar (desktop) ───────────────────────────────────────────────────
  Widget _buildSidebar({bool inDrawer = false}) {
    return Container(
      width: 210,
      color: inDrawer ? Colors.white : Colors.grey[50],
      child: SafeArea(
        child: Column(
          children: [
            if (inDrawer) ...[
              const SizedBox(height: 16),
              Row(children: [
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20)),
                const SizedBox(width: 10),
                const Text('Admin Panel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              const Divider(),
            ] else
              const SizedBox(height: 20),
            for (int i = 0; i < _navItems.length; i++)
              _NavTile(
                icon: _navItems[i].icon,
                label: _navItems[i].label,
                isLogout: _navItems[i].isLogout,
                isSelected: _selectedIndex == i && !_navItems[i].isLogout,
                onTap: () => _onMenuSelected(i, closeDrawer: inDrawer),
              ),
            const Spacer(),
            const Divider(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── AppBar actions ───────────────────────────────────────────────────────
  List<Widget> _appBarActions(bool isMobile) {
    return [
      IconButton(
        icon: const Icon(Icons.refresh, color: Colors.black54),
        onPressed: _loadData,
        tooltip: 'Refresh',
      ),
      if (!isMobile)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary,
              radius: 15,
              child: Icon(Icons.admin_panel_settings, size: 16, color: Colors.white)),
            SizedBox(width: 8),
            Text('Admin', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          ]),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isMobile = MediaQuery.of(context).size.width <= 800;

    return Scaffold(
      backgroundColor: Colors.white,
      // ── Mobile drawer ───────────────────────────────────────────────────
      drawer: isMobile
          ? Drawer(child: _buildSidebar(inDrawer: true))
          : null,
      appBar: AppBar(
        title: Text(_currentTitle,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
        // hamburger icon shown automatically when drawer != null
        actions: _appBarActions(isMobile),
      ),
      body: isMobile
          // ── MOBILE: full width body ─────────────────────────────────────
          ? _currentBody
          // ── DESKTOP: sidebar + body side by side ───────────────────────
          : Row(
              children: [
                _buildSidebar(),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: _currentBody),
              ],
            ),
    );
  }
}

// Reusable nav tile used in both sidebar and drawer
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLogout;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.isLogout,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLogout ? Colors.red : (isSelected ? AppTheme.primary : Colors.black87);
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
      tileColor: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}
