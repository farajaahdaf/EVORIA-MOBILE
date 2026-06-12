import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authProvider.notifier).register(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final isLoading = state.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHero(
              title: 'Buat Akun Baru',
              subtitle: 'Daftar dan mulai beli tiket event seru',
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AuthCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.error != null) ...[
                          AuthErrorBox(message: state.error!),
                          Gap.h16,
                        ],
                        const AuthLabel('Nama Lengkap'),
                        Gap.h6,
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'Nama kamu',
                            prefixIcon: Icon(Icons.person_outline,
                                color: AppColors.textLight),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Nama tidak boleh kosong'
                              : null,
                        ),
                        Gap.h16,
                        const AuthLabel('Email'),
                        Gap.h6,
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'nama@email.com',
                            prefixIcon: Icon(Icons.email_outlined,
                                color: AppColors.textLight),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Email tidak boleh kosong';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        Gap.h16,
                        const AuthLabel('Password'),
                        Gap.h6,
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText: 'Min. 8 karakter',
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: AppColors.textLight),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textLight,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password tidak boleh kosong';
                            }
                            if (v.length < 8) return 'Password minimal 8 karakter';
                            return null;
                          },
                        ),
                        Gap.h24,
                        AuthGradientButton(
                          label: 'Daftar Sekarang',
                          loading: isLoading,
                          onTap: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AuthFooterLink(
              question: 'Sudah punya akun? ',
              action: 'Masuk',
              onTap: () => context.go('/login'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
