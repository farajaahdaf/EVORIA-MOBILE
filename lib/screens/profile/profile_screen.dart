import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/evoria_app_bar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const EvoriaAppBar(title: 'Profil'),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(user.name, user.email, user.avatarUrl),
                  const SizedBox(height: 16),
                  _buildMenuSection(context, ref),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(String name, String email, String avatarUrl) {
    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.border,
            backgroundImage: CachedNetworkImageProvider(avatarUrl),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Attendee',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          _menuItem(
            icon: Icons.confirmation_number_outlined,
            title: 'Tiket Saya',
            subtitle: 'Lihat semua tiket & riwayat order',
            onTap: () => context.go('/orders'),
          ),
          const Divider(height: 1, indent: 56),
          _menuItem(
            icon: Icons.smart_toy_outlined,
            title: 'Evoria AI',
            subtitle: 'Tanya rekomendasi event ke AI',
            onTap: () => context.go('/chatbot'),
          ),
          const Divider(height: 1, indent: 56),
          _menuItem(
            icon: Icons.language_outlined,
            title: 'Buka Website',
            subtitle: 'evoria.life',
            onTap: () {},
          ),
          const Divider(height: 1, indent: 56),
          _menuItem(
            icon: Icons.help_outline,
            title: 'Bantuan',
            subtitle: 'FAQ dan panduan penggunaan',
            onTap: () {},
          ),
          const Divider(height: 1),
          _menuItem(
            icon: Icons.logout,
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 22,
          color: iconColor ?? AppColors.primary,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right,
          size: 20, color: AppColors.textLight),
      onTap: onTap,
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Keluar dari Evoria?'),
        content: const Text('Kamu perlu login lagi untuk mengakses akunmu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('Keluar',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
