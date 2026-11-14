import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/cafe_design.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_header.dart';

/// Daftar customer — restyle mengikuti token desain Figma
/// "Pemrograman-Mobile" (frame Customer · Daftar).
///
/// Perbaikan dari catatan 7 Nov 2026:
/// - Ada feedback setelah daftar berhasil (SnackBar).
/// - Ada kolom konfirmasi kata sandi (mencegah typo yang tersimpan
///   diam-diam — penyebab error login farideraser@gmail.com).
/// - Menampilkan pesan yang berbeda kalau "Confirm email" aktif
///   (akun dibuat tapi belum bisa masuk sebelum konfirmasi email).
class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.config,
    required this.auth,
  });

  final AppConfig config;
  final AuthRepository auth;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  bool _showPasswordConfirm = false;
  String? _error;

  Future<void> _submit() async {
    final nama = _nama.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (nama.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Lengkapi nama, email, dan kata sandi.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Kata sandi minimal 6 karakter.');
      return;
    }
    if (password != _passwordConfirm.text) {
      setState(
        () => _error = 'Konfirmasi kata sandi tidak sama. Periksa lagi.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.signUp(
        nama: nama,
        email: email,
        password: password,
      );
      if (!mounted) return;
      // signUp sukses: kalau langsung dapat sesi, auth guard memindahkan
      // ke Beranda; kalau Confirm email aktif, user tetap di sini.
      final loggedIn = widget.auth.isLoggedIn;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loggedIn
                ? 'Pendaftaran berhasil! Selamat datang, $nama.'
                : 'Pendaftaran berhasil! Cek email untuk konfirmasi akun.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Pendaftaran gagal. Periksa koneksi internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CafeColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthHeader(cafeName: widget.config.cafeName),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/auth_hero.jpg',
                  height: 210,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              Text('Buat akun baru.', style: CafeText.greeting),
              const SizedBox(height: 8),
              Text(
                'Daftar untuk mulai memesan di '
                '${widget.config.cafeName}.',
                style: CafeText.cardSub,
              ),
              const SizedBox(height: 28),
              AuthField(
                label: 'Nama',
                controller: _nama,
                hint: 'Nama kamu',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              AuthField(
                label: 'Email',
                controller: _email,
                hint: 'nama@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AuthField(
                label: 'Kata sandi',
                controller: _password,
                hint: 'Minimal 6 karakter',
                obscureText: !_showPassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: CafeColors.muted,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              const SizedBox(height: 16),
              AuthField(
                label: 'Ulangi kata sandi',
                controller: _passwordConfirm,
                hint: 'Ketik ulang kata sandi',
                obscureText: !_showPasswordConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPasswordConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: CafeColors.muted,
                  ),
                  onPressed: () => setState(
                    () => _showPasswordConfirm = !_showPasswordConfirm,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: CafeText.cardSub
                      .copyWith(color: CafeColors.danger),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CafeColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: CafeColors.border,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Daftar', style: CafeText.buttonLabel),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Sudah punya akun? ', style: CafeText.cardSub),
                  InkWell(
                    onTap: () => context.go('/login'),
                    child: Text('Masuk', style: CafeText.shortcut),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Akun staf diarahkan sesuai peran.',
                  style: CafeText.menuMeta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
