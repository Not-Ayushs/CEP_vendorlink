import 'package:flutter/material.dart';
import 'package:swm_vendor/theme/app_theme.dart';
import 'driver_login_screen.dart';
import 'admin_main_screen.dart';
import 'vendor_login_screen.dart'; 

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          'Waste Ops',
          style: TextStyle(
            color: Color(0xFF064E3B), // emerald-900 equivalent
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Headline
              const Text(
                'Select Your Role',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose your workspace to begin managing operations',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.outline, // on-surface-variant
                ),
              ),
              const SizedBox(height: 48),
              
              // Roles Grid
              _buildRoleCard(
                context,
                title: '🚛 Driver / Collector',
                subtitle: 'Route navigation & bin collection',
                icon: Icons.local_shipping,
                iconBgColor: const Color(0xFFC8F6CD), // Approx primary-containerish
                iconColor: AppTheme.primary,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DriverLoginScreen()));
                },
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context,
                title: '🏪 Vendor',
                subtitle: 'Request pickups & manage service',
                icon: Icons.storefront,
                iconBgColor: const Color(0xFFD3E3FD), // Approx secondary-container
                iconColor: AppTheme.secondary,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VendorLoginScreen()));
                },
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context,
                title: '🛠 Admin Dashboard',
                subtitle: 'Fleet oversight & analytics',
                icon: Icons.dashboard_customize,
                iconBgColor: const Color(0xFFFFD9DF), // Approx tertiary-container
                iconColor: const Color(0xFF9B3E3B), // Tertiary
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminMainScreen()));
                },
              ),
              
              const SizedBox(height: 64),
              
              // Footer
              const Text(
                'V2.4.0 • ENTERPRISE EDITION',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.outline,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.outline, // approx on-surface-variant
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: iconColor),
          ],
        ),
      ),
    );
  }
}
