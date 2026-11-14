import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/cafe_design.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_field.dart';
import 'widgets/auth_header.dart';

/// Masuk customer — sesuai desain Figma "Pemrograman-Mobile"
/// (frame Customer · Masuk), dicocokkan dari screenshot frame
/// yang dikirim Rid 7 Nov 2026 (Figma MCP masih kehabisan kuota).
///
/// Logo + foto interior cafe di atas, judul "Selamat datang kembali.",
/// field "Email / nomor HP" (login bisa pakai nomor HP yang terdaftar
/// di profil — dicari emailnya dulu), kotak info "Masuk untuk mulai
/// memesan", dan tautan "Lupa kata sandi?".
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.config,
    required this.auth,
  });

  final AppConfig config;
  final AuthRepository auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Isi email/nomor HP dan kata sandi.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.signIn(
        email: _email.text,
        password: _password.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Login gagal. Periksa koneksi internet.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailController =
        TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lupa kata sandi?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kami kirim link reset kata sandi ke email kamu.',
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Email',
              controller: emailController,
              hint: 'nama@email.com',
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(emailController.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: CafeColors.accent,
            ),
            child: const Text('Kirim link'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await widget.auth.resetPassword(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Link reset dikirim ke $email. Cek inbox / spam.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim link: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim link reset.')),
      );
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
              Text('Selamat datang kembali.', style: CafeText.greeting),
              const SizedBox(height: 8),
              Text(
                'Masuk, pilih yang kamu suka, lalu nikmati waktumu di '
                '${widget.config.cafeName}.',
                style: CafeText.cardSub,
              ),
              const SizedBox(height: 28),
              AuthField(
                label: 'Email / nomor HP',
                controller: _email,
                hint: 'nama@email.com',
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              AuthField(
                label: 'Kata sandi',
                controller: _password,
                hint: 'Kata sandi kamu',
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
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: _forgotPassword,
                  child:
                      Text('Lupa kata sandi?', style: CafeText.shortcut),
                ),
              ),
              const SizedBox(height: 20),
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
                      : Text('Masuk', style: CafeText.buttonLabel),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CafeColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: CafeColors.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Masuk untuk mulai memesan',
                            style: CafeText.toggleTitle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Akun diperlukan untuk pembayaran, notifikasi, '
                            'dan riwayat pesanan. Tidak tersedia mode tamu.',
                            style: CafeText.cardSub,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Belum punya akun? ', style: CafeText.cardSub),
                  InkWell(
                    onTap: () => context.go('/register'),
                    child:
                        Text('Daftar sekarang', style: CafeText.shortcut),
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
