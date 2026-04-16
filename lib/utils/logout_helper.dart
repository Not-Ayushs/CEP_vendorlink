import 'package:flutter/material.dart';
import 'package:swm_vendor/services/supabase_service.dart';

/// Call from any logout button to sign out and fully reset the navigation stack.
///
/// Usage:
///   onPressed: () => performLogout(context),
Future<void> performLogout(BuildContext context) async {
  await SupabaseService.signOut();
  if (!context.mounted) return;
  // Clears entire nav stack, goes to '/' which is AuthGate.
  // AuthGate sees session == null → shows UnifiedLoginScreen.
  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
}
