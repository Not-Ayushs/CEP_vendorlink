import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:swm_vendor/services/location_service.dart';
import 'package:swm_vendor/services/supabase_service.dart';
import 'package:swm_vendor/theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  final int expectedVendorId;
  final int expectedRecordId;
  final int driverId;

  const QrScannerScreen({
    super.key,
    required this.expectedVendorId,
    required this.expectedRecordId,
    required this.driverId,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;

    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;

    setState(() {
      _processing = true;
      _message = 'Verifying QR and location...';
    });
    await _controller.stop();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw Exception('Invalid QR format.');
      }

      final token = decoded['token']?.toString();
      final vendorId = int.tryParse(decoded['vendor_id'].toString());
      final recordId = int.tryParse(decoded['record_id'].toString());

      if (token == null ||
          token.isEmpty ||
          vendorId == null ||
          recordId == null) {
        throw Exception('QR is missing required fields.');
      }
      if (vendorId != widget.expectedVendorId ||
          recordId != widget.expectedRecordId) {
        throw Exception('QR does not match this pickup.');
      }

      final loc = await LocationService.getCurrentLocation();
      if (loc == null) {
        throw Exception('Location permission is required for QR verification.');
      }

      final result = await SupabaseService.verifyQrPickup(
        token: token,
        vendorId: vendorId,
        recordId: recordId,
        driverId: widget.driverId,
        driverLat: loc.latitude,
        driverLng: loc.longitude,
      );

      if (result['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Verification Successful',
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
        return;
      }

      throw Exception(result['error']?.toString() ?? 'QR verification failed.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_message!),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Vendor QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_processing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.qr_code_scanner, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _message ?? 'Align the vendor QR inside the box.',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
