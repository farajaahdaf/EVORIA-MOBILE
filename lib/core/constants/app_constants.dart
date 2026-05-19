class AppConstants {
  // 10.0.2.2 = localhost dari Android emulator
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String logoUrl = 'https://evoria.life/images/logo.png';
  static const String storageUrl = 'https://evoria.life/storage';

  static const String midtransSnapUrlSandbox =
      'https://app.sandbox.midtrans.com/snap/snap.js';
  static const String midtransClientKeySandbox =
      'SB-Mid-client-NDt_uEVIpouRCEqb';

  static const String googleMapsAndroidApiKey =
      String.fromEnvironment('MAPS_API_KEY');

  static const double defaultLat = -0.02633;
  static const double defaultLng = 109.3425;

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
