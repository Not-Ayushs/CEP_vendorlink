import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Simple helper for runtime location permission and GPS position fetching.
class LocationService {
  /// Requests location permission if not already granted.
  /// Returns the final [LocationPermission] value.
  static Future<LocationPermission> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are turned off on the device — can't proceed.
      return LocationPermission.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Not yet asked — prompt the system dialog.
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Fetches the current [LatLng] of the device.
  ///
  /// Returns [null] if:
  ///  - permission is denied (or denied forever)
  ///  - location services are disabled
  ///  - any exception occurs
  static Future<LatLng?> getCurrentLocation() async {
    try {
      final permission = await requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Human-readable message describing the [permission] state.
  /// Useful for snackbars / banners.
  static String permissionMessage(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.deniedForever:
        return 'Location permission permanently denied. Enable it in app settings.';
      case LocationPermission.denied:
        return 'Location permission denied. Map centered on default location.';
      default:
        return 'Location unavailable. Map centered on default location.';
    }
  }
}
