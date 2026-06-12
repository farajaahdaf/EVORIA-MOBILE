import 'package:flutter/material.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// Evoria design tokens
/// Diselaraskan dengan tampilan web (Plus Jakarta Sans, brand blue → indigo,
/// kartu putih rounded-16, latar #EBEBEB, aksen gradien biru-indigo).
/// ──────────────────────────────────────────────────────────────────────────

class AppColors {
  // Brand
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryDeep = Color(0xFF1E3A8A);
  static const Color indigo = Color(0xFF4F46E5); // ujung gradien (match web)
  static const Color primaryLight = Color(0xFFEFF4FF);
  static const Color primarySoft = Color(0xFFE6EEFF);

  // Surfaces & background
  static const Color background = Color(0xFFEBEBEB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF8F9FB);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color darkFooter = Color(0xFF0F172A);
  static const Color ink = Color(0xFF0B1220);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  // Lines
  static const Color border = Color(0xFFE7EBF1);
  static const Color borderStrong = Color(0xFFD7DEE8);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFE9F8EF);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3E2);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFFDECEC);
}

/// Gradien khas Evoria (biru → indigo), persis seperti di web.
class AppGradients {
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.indigo],
  );

  static const LinearGradient brandHorizontal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primary, AppColors.indigo],
  );

  /// Overlay gelap untuk foto banner agar teks tetap terbaca.
  static const LinearGradient bannerScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x66101828),
      Color(0xE60B1220),
    ],
    stops: [0.35, 0.7, 1.0],
  );
}

/// Radius standar.
class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rXl = BorderRadius.all(Radius.circular(xl));
}

/// Bayangan halus (lebih premium daripada border keras).
class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0F1B2A4A), // ~6% navy
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x141B2A4A), // ~8% navy
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1F1B2A4A),
      blurRadius: 30,
      offset: Offset(0, 14),
    ),
  ];

  static List<BoxShadow> glow(Color color, {double opacity = 0.35}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}

/// Spasi vertikal/horizontal yang sering dipakai.
class Gap {
  static const w4 = SizedBox(width: 4);
  static const w6 = SizedBox(width: 6);
  static const w8 = SizedBox(width: 8);
  static const w12 = SizedBox(width: 12);
  static const w16 = SizedBox(width: 16);
  static const h4 = SizedBox(height: 4);
  static const h6 = SizedBox(height: 6);
  static const h8 = SizedBox(height: 8);
  static const h12 = SizedBox(height: 12);
  static const h16 = SizedBox(height: 16);
  static const h20 = SizedBox(height: 20);
  static const h24 = SizedBox(height: 24);
  static const h32 = SizedBox(height: 32);
}

/// Pemetaan ikon berdasarkan nama kategori (mengikuti logika web).
IconData categoryIcon(String? name) {
  final n = (name ?? '').toLowerCase();
  const map = <String, IconData>{
    'music': Icons.local_activity_outlined,
    'concert': Icons.local_activity_outlined,
    'konser': Icons.local_activity_outlined,
    'musik': Icons.local_activity_outlined,
    'tech': Icons.computer_outlined,
    'teknologi': Icons.computer_outlined,
    'conference': Icons.groups_outlined,
    'workshop': Icons.handyman_outlined,
    'sport': Icons.sports_soccer_outlined,
    'olahraga': Icons.sports_soccer_outlined,
    'art': Icons.palette_outlined,
    'seni': Icons.palette_outlined,
    'exhibition': Icons.photo_library_outlined,
    'pameran': Icons.photo_library_outlined,
    'festival': Icons.celebration_outlined,
    'seminar': Icons.campaign_outlined,
    'pertunjukan': Icons.theater_comedy_outlined,
    'penampilan': Icons.theater_comedy_outlined,
    'tur': Icons.luggage_outlined,
    'travel': Icons.luggage_outlined,
    'perjalanan': Icons.luggage_outlined,
    'social': Icons.groups_outlined,
    'gathering': Icons.groups_outlined,
    'kuliner': Icons.restaurant_outlined,
    'food': Icons.restaurant_outlined,
    'pendidikan': Icons.school_outlined,
    'education': Icons.school_outlined,
    'bisnis': Icons.business_center_outlined,
    'business': Icons.business_center_outlined,
    'film': Icons.movie_outlined,
  };
  for (final entry in map.entries) {
    if (n.contains(entry.key)) return entry.value;
  }
  return Icons.event_outlined;
}

class AppTheme {
  static const String _font = 'PlusJakartaSans';

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: _font,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        splashFactory: InkSparkle.splashFactory,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: _font,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
            textStyle: const TextStyle(
              fontFamily: _font,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.1,
            ),
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
            textStyle: const TextStyle(
              fontFamily: _font,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
            textStyle: const TextStyle(
              fontFamily: _font,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: const TextStyle(
              fontFamily: _font,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceAlt,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.rMd,
            borderSide: const BorderSide(color: AppColors.error, width: 1.6),
          ),
          hintStyle: const TextStyle(
            color: AppColors.textLight,
            fontSize: 14,
            fontFamily: _font,
          ),
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: _font,
          ),
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textLight,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(
            fontFamily: _font,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: _font,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primaryLight,
          labelStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.rSm,
            side: const BorderSide(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          contentTextStyle: const TextStyle(
            fontFamily: _font,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
          titleTextStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          contentTextStyle: const TextStyle(
            fontFamily: _font,
            fontSize: 14,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 1,
        ),
      );
}
