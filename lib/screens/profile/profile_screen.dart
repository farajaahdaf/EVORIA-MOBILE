import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, user.name, user.email, user.avatarUrl),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 10),
                    child: Text('Akun',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textLight,
                          letterSpacing: 0.3,
                        )),
                  ),
                  _buildMenuCard(context, ref),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(
      BuildContext context, String name, String email, String avatarUrl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 64, 20, 28),
      decoration: const BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Profil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/profile/edit'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
          Gap.h20,
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white24,
              backgroundImage: CachedNetworkImageProvider(avatarUrl),
            ),
          ),
          Gap.h16,
          Text(
            name,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(
                fontSize: 13.5, color: Colors.white.withValues(alpha: 0.85)),
          ),
          Gap.h12,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.all(Radius.circular(999)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 14, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  'Attendee',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _menuItem(
            icon: Icons.manage_accounts_rounded,
            title: 'Edit Profil',
            subtitle: 'Ubah nama, email, foto & password',
            onTap: () => context.push('/profile/edit'),
          ),
          // const Divider(height: 1, indent: 72),
          // _menuItem(
          //   icon: Icons.confirmation_number_rounded,
          //   title: 'Tiket Saya',
          //   subtitle: 'Lihat semua tiket & pesanan',
          //   onTap: () => context.go('/orders'),
          // ),
          const Divider(height: 1, indent: 72),
          _menuItem(
            icon: Icons.logout_rounded,
            title: 'Keluar',
            subtitle: 'Logout dari akun ini',
            iconColor: AppColors.error,
            titleColor: AppColors.error,
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    final isDanger = iconColor != null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: isDanger ? null : AppGradients.brand,
          color: isDanger ? AppColors.errorSoft : null,
          borderRadius: AppRadius.rMd,
        ),
        child: Icon(icon, size: 21, color: iconColor ?? Colors.white),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 22, color: AppColors.textLight),
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Keluar dari Evoria?'),
        content: const Text('Kamu perlu login lagi untuk mengakses akunmu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Keluar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
