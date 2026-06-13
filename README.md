# Evoria Mobile

Aplikasi mobile **Evoria** — marketplace tiket event. Cari event, beli tiket, simpan e-ticket, dan tanya **AI Assistant** untuk menemukan event terdekat dari lokasimu.

## 📋 Prasyarat

- [Flutter SDK](https://docs.flutter.dev/get-started/install) channel **stable**
- Android Studio + Android SDK + emulator / HP (USB debugging aktif)
- Jalankan `flutter doctor` — pastikan tidak ada error

---

## 🚀 Setup

### 1. Clone & install dependency
```bash
git clone <repo-url>
cd EVORIA-MOBILE
flutter pub get
```

### 2. Buat file konfigurasi (tidak ikut di-commit)

**a. `.env`** — salin dari template lalu isi nilainya:
```bash
sudah dikumpulkan di LMS
```

**b. `android/app/google-services.json`** — minta file aslinya ke pemilik repo (kredensial Firebase, tidak bisa diketik manual).

**c. `android/local.properties`** — tambahkan satu baris untuk Google Maps:
```properties
MAPS_API_KEY=your_google_maps_api_key
```

### 3. Jalankan
```bash
flutter run
```

---

## 👤 Akun Uji Coba

| Role | Email | Password |
|------|-------|----------|
| Attendee | `attendee@example.com` | `password` |

---

## 🧰 Troubleshooting

| Masalah | Solusi |
|---------|--------|
| `Unable to load asset: .env` | File `.env` belum dibuat (langkah 2a) |
| `File google-services.json is missing` | Belum menaruh `google-services.json` (langkah 2b) |
| Peta blank/abu-abu | `MAPS_API_KEY` di `android/local.properties` kosong/salah (langkah 2c) |
| Build aneh setelah ganti config | `flutter clean && flutter pub get && flutter run` |

---

