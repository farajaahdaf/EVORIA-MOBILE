import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/dio_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/evoria_app_bar.dart';

/// Edit Profile — mirrors the website profile page sections:
/// 1. Profile information (photo, name, email)
/// 2. Update password
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _infoFormKey = GlobalKey<FormState>();
  final _passFormKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  File? _pickedImage;
  bool _removePhoto = false;

  bool _savingInfo = false;
  bool _savingPass = false;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── Photo picking ──────────────────────────────────────────────────────
  Future<void> _showPhotoOptions(bool hasPhoto) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Hapus Foto',
                    style: TextStyle(color: AppColors.error)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (action == null) return;
    if (action == 'remove') {
      setState(() {
        _pickedImage = null;
        _removePhoto = true;
      });
      return;
    }

    final source =
        action == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
        _removePhoto = false;
      });
    }
  }

  // ── Submit handlers ────────────────────────────────────────────────────
  Future<void> _saveInfo() async {
    if (!_infoFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingInfo = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            photoPath: _pickedImage?.path,
            removePhoto: _removePhoto,
          );
      if (!mounted) return;
      setState(() {
        _pickedImage = null;
        _removePhoto = false;
      });
      _showSnack('Profil berhasil diperbarui', success: true);
    } catch (e) {
      if (mounted) _showSnack(_errMessage(e));
    } finally {
      if (mounted) setState(() => _savingInfo = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingPass = true);
    try {
      await ref.read(authProvider.notifier).updatePassword(
            currentPassword: _currentPassCtrl.text,
            newPassword: _newPassCtrl.text,
            confirmPassword: _confirmPassCtrl.text,
          );
      if (!mounted) return;
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      _showSnack('Password berhasil diubah', success: true);
    } catch (e) {
      if (mounted) _showSnack(_errMessage(e));
    } finally {
      if (mounted) setState(() => _savingPass = false);
    }
  }

  String _errMessage(Object e) =>
      e is ApiException ? e.message : 'Terjadi kesalahan, coba lagi';

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const EvoriaAppBar(title: 'Edit Profil'),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatarPicker(user.avatarUrl),
                  const SizedBox(height: 20),
                  _infoCard(),
                  const SizedBox(height: 16),
                  _passwordCard(),
                  const SizedBox(height: 16),
                  _dangerCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────
  Widget _avatarPicker(String currentUrl) {
    final hasPhoto = _pickedImage != null ||
        (!_removePhoto && ref.read(authProvider).user?.profilePhotoPath != null);

    ImageProvider avatarImage;
    if (_pickedImage != null) {
      avatarImage = FileImage(_pickedImage!);
    } else if (_removePhoto) {
      // Fallback ui-avatars (recomputed from the unchanged name).
      avatarImage = NetworkImage(_fallbackAvatar());
    } else {
      avatarImage = CachedNetworkImageProvider(currentUrl);
    }

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  gradient: AppGradients.brand,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.surface,
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: AppColors.border,
                    backgroundImage: avatarImage,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => _showPhotoOptions(hasPhoto),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppGradients.brand,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2.5),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _showPhotoOptions(hasPhoto),
            child: const Text('Ubah Foto Profil'),
          ),
        ],
      ),
    );
  }

  String _fallbackAvatar() {
    final encoded = Uri.encodeComponent(_nameCtrl.text.trim());
    return 'https://ui-avatars.com/api/?name=$encoded&background=2563EB&color=ffffff&size=128';
  }

  // ── Profile information card ────────────────────────────────────────────
  Widget _infoCard() {
    return _card(
      title: 'Informasi Profil',
      subtitle: 'Perbarui nama dan alamat email akunmu.',
      child: Form(
        key: _infoFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Nama'),
            TextFormField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Nama lengkap',
                prefixIcon:
                    Icon(Icons.person_outline, color: AppColors.textLight),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
            ),
            const SizedBox(height: 16),
            _label('Email'),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'nama@email.com',
                prefixIcon:
                    Icon(Icons.email_outlined, color: AppColors.textLight),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email tidak boleh kosong';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savingInfo ? null : _saveInfo,
              child: _savingInfo
                  ? const _BtnSpinner()
                  : const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Password card ───────────────────────────────────────────────────────
  Widget _passwordCard() {
    return _card(
      title: 'Ubah Password',
      subtitle: 'Gunakan password yang panjang dan acak agar tetap aman.',
      child: Form(
        key: _passFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Password Saat Ini'),
            _passwordField(
              controller: _currentPassCtrl,
              obscure: _obscureCurrent,
              onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Password saat ini tidak boleh kosong'
                  : null,
            ),
            const SizedBox(height: 16),
            _label('Password Baru'),
            _passwordField(
              controller: _newPassCtrl,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password baru tidak boleh kosong';
                if (v.length < 8) return 'Minimal 8 karakter';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _label('Konfirmasi Password Baru'),
            _passwordField(
              controller: _confirmPassCtrl,
              obscure: _obscureConfirm,
              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Konfirmasi password tidak boleh kosong';
                if (v != _newPassCtrl.text) return 'Password tidak cocok';
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savingPass ? null : _savePassword,
              child:
                  _savingPass ? const _BtnSpinner() : const Text('Ubah Password'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: '••••••••',
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textLight),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: AppColors.textLight,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  // ── Danger zone (delete account) ────────────────────────────────────────
  Widget _dangerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hapus Akun',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Setelah akun dihapus, seluruh data termasuk tiket & riwayat order '
            'akan dihapus permanen dan tidak bisa dikembalikan.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _confirmDeleteAccount,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Hapus Akun Saya'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (deleted == true && mounted) {
      context.go('/login');
    }
  }

  // ── Shared building blocks ──────────────────────────────────────────────
  Widget _card({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

class _BtnSpinner extends StatelessWidget {
  const _BtnSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
}

/// Password-confirmation dialog for permanent account deletion.
/// Pops `true` on success.
class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_passCtrl.text.isEmpty) {
      setState(() => _error = 'Masukkan password untuk konfirmasi');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .deleteAccount(password: _passCtrl.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : 'Gagal menghapus akun';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Hapus akun?',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tindakan ini permanen. Masukkan password untuk konfirmasi '
            'penghapusan akunmu.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passCtrl,
            obscureText: _obscure,
            enabled: !_loading,
            onSubmitted: (_) => _delete(),
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon:
                  const Icon(Icons.lock_outline, color: AppColors.textLight),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textLight,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Batal',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _delete,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            minimumSize: const Size(110, 44),
          ),
          child: _loading
              ? const _BtnSpinner()
              : const Text('Hapus Akun'),
        ),
      ],
    );
  }
}
