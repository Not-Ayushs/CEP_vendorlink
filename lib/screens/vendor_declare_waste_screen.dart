import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:swm_vendor/services/supabase_service.dart';
import 'package:swm_vendor/services/location_service.dart';
import 'package:swm_vendor/theme/app_theme.dart';

class VendorDeclareWasteScreen extends StatefulWidget {
  final int vendorId;
  const VendorDeclareWasteScreen({super.key, required this.vendorId});

  @override
  State<VendorDeclareWasteScreen> createState() =>
      _VendorDeclareWasteScreenState();
}

class _VendorDeclareWasteScreenState extends State<VendorDeclareWasteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _wasteType = 'Organic';
  bool _submitting = false;

  // Location state
  double? _lat;
  double? _lng;
  bool _locationFetching = false;
  String? _locationError;

  // Waste types with icons and colors
  static const List<_WasteOption> _wasteTypes = [
    _WasteOption('Organic', Icons.eco_rounded, Color(0xFF2E7D32)),
    _WasteOption('Plastic', Icons.recycling_rounded, Color(0xFF1565C0)),
    _WasteOption('Mixed', Icons.delete_rounded, Color(0xFF546E7A)),
    _WasteOption('Paper', Icons.description_rounded, Color(0xFF6D4C41)),
    _WasteOption('E-Waste', Icons.devices_rounded, Color(0xFF7B1FA2)),
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  // ── LOCATION ─────────────────────────────────────────────────────────────

  Future<void> _fetchLocation() async {
    setState(() {
      _locationFetching = true;
      _locationError = null;
    });

    try {
      final permission = await LocationService.requestPermission();

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Location permission permanently denied. '
              'Enable it in app settings to attach your location.';
          _locationFetching = false;
        });
        return;
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _locationError =
              'Location permission denied. '
              'Your pickup location will not be recorded.';
          _locationFetching = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationFetching = false;
      });
    } catch (e) {
      setState(() {
        _locationError =
            'Could not get location. '
            'Your pickup location will not be recorded.';
        _locationFetching = false;
      });
    }
  }

  // ── SUBMIT ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog — includes location status
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Confirm Declaration',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please confirm your waste declaration:'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount: ${_amountCtrl.text} kg',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Type: $_wasteType',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (_notesCtrl.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Notes: ${_notesCtrl.text.trim()}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Location confirmation row
                  Row(
                    children: [
                      Icon(
                        _lat != null
                            ? Icons.location_on_rounded
                            : Icons.location_off_rounded,
                        size: 16,
                        color: _lat != null
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _lat != null
                              ? 'Location: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                              : 'Location: not captured',
                          style: TextStyle(
                            fontSize: 12,
                            color: _lat != null
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Declare',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await SupabaseService.declareWaste(
        vendorId: widget.vendorId,
        declaredWaste: double.parse(_amountCtrl.text),
        wasteType: _wasteType,
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
        lat: _lat,
        lng: _lng,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _lat != null
                      ? 'Waste declared with location!'
                      : 'Waste declared successfully!',
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Declare Waste'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Location status banner ───────────────────────────────────────
                _buildLocationBanner(),
                const SizedBox(height: 20),

                // ── Amount ──────────────────────────────────────────────────────
                const Text(
                  'Waste Amount',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Amount in kg',
                    hintText: 'e.g. 12.5',
                    prefixIcon: const Icon(Icons.scale_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (double.tryParse(v) == null)
                      return 'Enter a valid number';
                    return null;
                  },
                ),

                const SizedBox(height: 28),

                // ── Waste Type Selection (icon grid) ─────────────────────────────
                const Text(
                  'Waste Type',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select the type of waste',
                  style: TextStyle(color: Colors.black45, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _wasteTypes.map((wt) {
                    final selected = _wasteType == wt.label;
                    return GestureDetector(
                      onTap: () => setState(() => _wasteType = wt.label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: (MediaQuery.of(context).size.width - 60) / 3,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: selected
                              ? wt.color.withValues(alpha: 0.1)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? wt.color : Colors.grey[200]!,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              wt.icon,
                              color: selected ? wt.color : Colors.grey[500],
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              wt.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: selected ? wt.color : Colors.black54,
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(height: 4),
                              Icon(
                                Icons.check_circle_rounded,
                                color: wt.color,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                // ── Notes ───────────────────────────────────────────────────────
                const Text(
                  'Additional Notes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Optionally add notes for the driver',
                  style: TextStyle(color: Colors.black45, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. Bags are near the back entrance',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 44),
                      child: Icon(Icons.notes_rounded),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Submit ──────────────────────────────────────────────────────
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Submit Declaration',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Location banner widget ────────────────────────────────────────────────

  Widget _buildLocationBanner() {
    if (_locationFetching) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue[100]!),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              'Getting your location…',
              style: TextStyle(fontSize: 13, color: Colors.blue[800]),
            ),
          ],
        ),
      );
    }

    if (_lat != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_rounded, size: 18, color: Colors.green[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Location captured (${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)})',
                style: TextStyle(fontSize: 12, color: Colors.green[800]),
              ),
            ),
            // Retry button
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Colors.green[700],
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _locationFetching ? null : _fetchLocation,
              tooltip: 'Refresh location',
            ),
          ],
        ),
      );
    }

    // Error / denied state
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_rounded, size: 18, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _locationError ??
                  'Location unavailable. Declaration will proceed without coordinates.',
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: Colors.orange[700],
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _locationFetching ? null : _fetchLocation,
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }
}

class _WasteOption {
  final String label;
  final IconData icon;
  final Color color;
  const _WasteOption(this.label, this.icon, this.color);
}
