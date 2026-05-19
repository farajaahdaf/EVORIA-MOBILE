import 'dart:io';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

enum LocationResultStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}

class LocationResult {
  final LocationResultStatus status;
  final Position? position;
  const LocationResult(this.status, [this.position]);

  bool get isSuccess => status == LocationResultStatus.success && position != null;
}

class LocationService {
  static Future<LocationResult> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(LocationResultStatus.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const LocationResult(LocationResultStatus.permissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(LocationResultStatus.permissionDeniedForever);
    }

    final settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 30),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 30),
          );

    try {
      final pos = await Geolocator.getCurrentPosition(locationSettings: settings);
      return LocationResult(LocationResultStatus.success, pos);
    } catch (_) {
      // Fallback: pakai last known kalau masih fresh (<10 menit)
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          final age = DateTime.now().difference(last.timestamp);
          if (age.inMinutes < 10) {
            return LocationResult(LocationResultStatus.success, last);
          }
        }
      } catch (_) {/* ignore */}
      return const LocationResult(LocationResultStatus.error);
    }
  }

  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = [
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].where((s) => s != null && s.isNotEmpty).toSet().toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }
}
