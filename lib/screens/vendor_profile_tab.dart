import 'package:flutter/material.dart';
import 'package:swm_vendor/services/supabase_service.dart';
import 'package:swm_vendor/utils/logout_helper.dart';

class VendorProfileTab extends StatelessWidget {
  const VendorProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;

    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 24),
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.storefront, size: 44, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(user?.email ?? 'Vendor',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Vendor Account', style: TextStyle(color: Colors.black45, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 40),
              _item('Role', '🏪 Vendor'),
              _item('Email', user?.email ?? '—'),
              const SizedBox(height: 40),
              OutlinedButton.icon(
                onPressed: () => performLogout(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold,
                letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
