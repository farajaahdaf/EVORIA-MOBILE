import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';

/// Tampilan untuk guest (belum login) di layar yang butuh akun
/// (Tiket Saya, Profil). Mengarahkan ke login dengan `returnTo`
/// agar setelah berhasil masuk kembali ke layar asal.
class GuestPrompt extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String returnTo;

  const GuestPrompt({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.returnTo = '/home',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  context.push('/login?returnTo=${Uri.encodeComponent(returnTo)}'),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Masuk / Daftar'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
