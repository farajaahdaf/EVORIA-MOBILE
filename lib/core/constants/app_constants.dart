import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Semua nilai dibaca dari .env — fallback ke production jika key tidak ditemukan
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'https://evoria.life/api/v1';

  static String get _host {
    final url = baseUrl;
    final uri = Uri.tryParse(url);
    return uri != null ? '${uri.scheme}://${uri.host}' : 'https://evoria.life';
  }

  static String get logoUrl => '$_host/images/logo.png';
  static String get storageUrl => '$_host/storage';

  static String get midtransSnapUrl =>
      dotenv.env['MIDTRANS_SNAP_URL'] ??
      'https://app.sandbox.midtrans.com/snap/snap.js';

  static String get midtransClientKey =>
      dotenv.env['MIDTRANS_CLIENT_KEY'] ?? '';

  // Backward-compat alias
  static String get midtransSnapUrlSandbox => midtransSnapUrl;
  static String get midtransClientKeySandbox => midtransClientKey;

  static String get googleMapsAndroidApiKey =>
      dotenv.env['MAPS_API_KEY'] ?? '';

  static double get defaultLat =>
      double.tryParse(dotenv.env['DEFAULT_LAT'] ?? '') ?? -0.02633;

  static double get defaultLng =>
      double.tryParse(dotenv.env['DEFAULT_LNG'] ?? '') ?? 109.3425;

  static double get defaultZoom =>
      double.tryParse(dotenv.env['DEFAULT_ZOOM'] ?? '') ?? 13;

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
