import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication against Supabase Auth + the `public.users` profile row.
///
/// One account = one role (see `user_role` enum in the database).
/// Staff accounts are created by the admin; this repository only handles
/// the customer self-registration flow.
///
/// NOTE (MVP): turn OFF "Confirm email" in the Supabase dashboard
/// (Authentication > Providers > Email) so newly registered users get a
/// session immediately. Otherwise signUp succeeds but the user stays
/// logged out until they click the email link.
class AuthRepository extends ChangeNotifier {
  AuthRepository() {
    _subscription = _client.auth.onAuthStateChange.listen((_) async {
      await fetchProfile();
      notifyListeners();
    });
  }

  final SupabaseClient _client = Supabase.instance.client;
  late final StreamSubscription<AuthState> _subscription;

  bool get isLoggedIn => _client.auth.currentSession != null;
  User? get currentUser => _client.auth.currentUser;

  /// Peran dari baris `public.users` (customer/waitress/barista/dapur/
  /// admin). Null = belum dimuat atau tidak ada baris profil.
  String? role;

  /// Muat profil (peran + nama) user yang login. Dipanggil tiap
  /// perubahan sesi auth; router memakai [role] untuk mengarahkan
  /// staf/admin ke layar mereka ("Akun staf diarahkan sesuai peran").
  Future<void> fetchProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      role = null;
      return;
    }
    try {
      final row = await _client
          .from('users')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      role = row?['role'] as String?;
    } catch (_) {
      role = null;
    }
  }

  /// Layar awal sesuai peran.
  String get roleHome => switch (role) {
        'waitress' => '/staff/tables',
        'barista' => '/staff/kds?station=bar',
        'dapur' => '/staff/kds?station=dapur',
        'admin' => '/admin',
        _ => '/',
      };

  /// Register a new customer. Creates the auth user AND the profile row
  /// in `public.users` (id = auth user id, role = customer).
  Future<void> signUp({
    required String nama,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException(
          'Pendaftaran gagal. Coba lagi atau hubungi admin.');
    }
    await _client.from('users').upsert({
      'id': user.id,
      'nama': nama.trim(),
      'email': email.trim(),
      'role': 'customer',
    });
  }

  /// Masuk dengan email ATAU nomor HP (sesuai label desain "Email /
  /// nomor HP"). Nomor HP dicari dulu emailnya di `public.users`.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    var loginEmail = email.trim();
    if (!loginEmail.contains('@')) {
      final phone = loginEmail.replaceAll(RegExp(r'[\s\-]'), '');
      final candidates = <String>[phone];
      if (phone.startsWith('0')) candidates.add('62${phone.substring(1)}');
      if (phone.startsWith('+62')) {
        candidates.add('0${phone.substring(3)}');
      }
      if (phone.startsWith('62')) {
        candidates.add('0${phone.substring(2)}');
      }
      String? foundEmail;
      for (final c in candidates) {
        final row = await _client
            .from('users')
            .select('email')
            .eq('no_hp', c)
            .maybeSingle();
        if (row != null && (row['email'] as String?)?.isNotEmpty == true) {
          foundEmail = row['email'] as String;
          break;
        }
      }
      if (foundEmail == null) {
        throw const AuthException(
          'Nomor HP tidak terdaftar. Coba email, atau daftar dulu.',
        );
      }
      loginEmail = foundEmail;
    }
    await _client.auth.signInWithPassword(
      email: loginEmail,
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Kirim email reset password. Penyelesaian reset (membuat kata
  /// sandi baru) masih lewat tautan di email — layar buat kata sandi
  /// baru di aplikasi menyusul (butuh deep link).
  Future<void> resetPassword({required String email}) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
