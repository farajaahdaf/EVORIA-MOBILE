import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Posisi GPS user terakhir yang diketahui, dipakai bersama oleh Beranda dan
/// Chatbot agar hasil "event terdekat" konsisten di kedua layar.
///
/// Chatbot menulis posisi terbaru tiap kali menjawab pertanyaan berbau lokasi,
/// dan Beranda ikut membaca provider ini sehingga sortir "Terdekat dari saya"
/// otomatis menyesuaikan lokasi terbaru.
final userPositionProvider = StateProvider<Position?>((ref) => null);

/// Label alamat hasil reverse-geocode dari [userPositionProvider]. Disimpan di
/// provider agar tidak hilang saat Beranda dibuat ulang (mis. pindah tab).
final userAddressProvider = StateProvider<String?>((ref) => null);
