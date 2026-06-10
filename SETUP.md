# Setup Evoria Mobile (untuk yang baru clone)

Repo ini **tidak menyertakan beberapa file sensitif** (sudah di-`.gitignore`).
Tanpa file-file ini, `flutter run` akan gagal. Ikuti langkah di bawah.

## Prasyarat
- Flutter SDK channel **stable** (Dart `^3.11.5`) — cek dengan `flutter --version`
- Android Studio + Android SDK + emulator/HP (USB debugging)
- Jalankan `flutter doctor` dan pastikan tidak ada error merah

## 3 file yang HARUS dibuat manual

Minta isi file ini ke pemilik repo lewat jalur privat (WA/Google Drive),
**jangan** di-commit ke repo publik.

### 1. `.env` (di root `EVORIA-MOBILE/`)
Copy dari template lalu isi nilainya:
```bash
cp .env.example .env
```
Isi minimal yang wajib benar: `BASE_URL`, `MIDTRANS_CLIENT_KEY`, `MAPS_API_KEY`.
> File ini wajib ada — didaftarkan sebagai asset di `pubspec.yaml` dan di-load di `main.dart`.

### 2. `android/app/google-services.json`
**Copy file aslinya** dari pemilik repo (tidak bisa diketik manual — berisi kredensial
Firebase project `evoria-859bb`). Taruh persis di `android/app/google-services.json`.
> Wajib ada, kalau tidak Gradle build gagal: *"File google-services.json is missing"*.

### 3. `android/local.properties` — tambahkan Maps key
File ini dibuat otomatis oleh Flutter saat build pertama (berisi `sdk.dir` & `flutter.sdk`).
Tambahkan satu baris:
```
MAPS_API_KEY=ISI_DENGAN_GOOGLE_MAPS_API_KEY
```
> Dipakai `android/app/build.gradle.kts` untuk mengisi `${MAPS_API_KEY}` di AndroidManifest.
> Kalau kosong, app tetap jalan tapi peta blank.

## Jalankan
```bash
flutter pub get
flutter run
```

## Backend / API
Secara default app menunjuk ke production (`BASE_URL=https://evoria.life/api/v1`).
Untuk backend lokal (emulator Android), ganti di `.env`:
```
BASE_URL=http://10.0.2.2:8000/api/v1
```
(`10.0.2.2` = alias `localhost` dari dalam emulator Android)

## Login uji coba (dari seeder)
- Attendee: `attendee@example.com` / `password`

## Troubleshooting cepat
- **"Unable to load asset: .env"** → file `.env` belum dibuat (langkah 1).
- **"File google-services.json is missing"** → langkah 2 belum dilakukan.
- **Peta blank/abu-abu** → `MAPS_API_KEY` di `android/local.properties` kosong/salah (langkah 3).
- Build aneh setelah ganti config → `flutter clean && flutter pub get && flutter run`.
- **(Windows) `IllegalArgumentException: this and base files have different roots`** →
  Project dan Pub cache berada di drive berbeda (mis. project di `E:`, pub cache di `C:`).
  Sudah dicegah lewat `kotlin.incremental=false` di `android/gradle.properties`.
  Kalau masih muncul: jalankan `flutter clean`, atau set env var `PUB_CACHE=E:\PubCache`
  (drive yang sama dengan project) lalu `flutter pub get` ulang, atau pindahkan project ke drive `C:`.
