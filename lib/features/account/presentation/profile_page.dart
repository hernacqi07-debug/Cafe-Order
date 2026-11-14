import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/cafe_design.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/widgets/auth_field.dart';

/// Profil saya — mengikuti token desain Figma "Pemrograman-Mobile"
/// (frame Customer · Profil).
///
/// Menampilkan data dari `public.users`, bisa ubah nama & no HP,
/// dan keluar dari akun. Kode member tampil apa adanya (belum ada
/// mekanisme penerbitan kode member di MVP).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  bool _editing = false;
  bool _saving = false;
  final _namaController = TextEditingController();
  final _noHpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = widget.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Sesi berakhir, silakan masuk lagi.';
      });
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('nama, email, no_hp, member_code, role, dibuat_pada')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _profile = row;
        _namaController.text = (row?['nama'] as String?) ?? '';
        _noHpController.text = (row?['no_hp'] as String?) ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _save() async {
    final uid = widget.auth.currentUser?.id;
    final nama = _namaController.text.trim();
    if (uid == null || nama.isEmpty) {
      setState(() => _error = 'Nama tidak boleh kosong.');
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('users').update({
        'nama': nama,
        'no_hp': _noHpController.text.trim().isEmpty
            ? null
            : _noHpController.text.trim(),
      }).eq('id', uid);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan profil: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nama = (_profile?['nama'] as String?) ?? '';
    final email = (_profile?['email'] as String?) ??
        widget.auth.currentUser?.email ??
        '';
    final role = (_profile?['role'] as String?) ?? 'customer';
    final memberCode = (_profile?['member_code'] as String?) ?? '';
    final initial = nama.isEmpty ? '?' : nama[0].toUpperCase();

    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CafeColors.ink),
          onPressed: () => context.pop(),
        ),
        title: Text('Profil saya', style: CafeText.pageTitle),
        centerTitle: false,
        actions: [
          if (!_loading && _profile != null)
            TextButton(
              onPressed: _editing
                  ? null
                  : () => setState(() => _editing = true),
              child: Text('Ubah', style: CafeText.shortcut),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _profile == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Gagal memuat profil:\n$_error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: CafeColors.cream,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: CafeText.greeting,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        nama.isEmpty ? 'Kamu' : nama,
                        style: CafeText.cardTitle,
                      ),
                      const SizedBox(height: 4),
                      Text(email, style: CafeText.cardSub),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: CafeColors.softGreen,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          role == 'customer'
                              ? 'Member'
                              : role[0].toUpperCase() + role.substring(1),
                          style: CafeText.toggleTitle.copyWith(
                            color: CafeColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: CafeColors.border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _editing
                            ? Column(
                                children: [
                                  AuthField(
                                    label: 'Nama',
                                    controller: _namaController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                  ),
                                  const SizedBox(height: 16),
                                  AuthField(
                                    label: 'No HP',
                                    controller: _noHpController,
                                    hint: '08xxxxxxxxxx',
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _saving
                                              ? null
                                              : () => setState(
                                                    () => _editing = false,
                                                  ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: CafeColors.ink,
                                            side: const BorderSide(
                                              color: CafeColors.border,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text('Batal'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed:
                                              _saving ? null : _save,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                CafeColors.accent,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: _saving
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Text('Simpan'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  _infoRow('Nama', nama),
                                  const Divider(
                                    color: CafeColors.border,
                                    height: 24,
                                  ),
                                  _infoRow('Email', email),
                                  const Divider(
                                    color: CafeColors.border,
                                    height: 24,
                                  ),
                                  _infoRow(
                                    'No HP',
                                    (_profile?['no_hp'] as String?)
                                            ?.isNotEmpty ==
                                        true
                                        ? _profile!['no_hp'] as String
                                        : 'Belum diisi',
                                  ),
                                  const Divider(
                                    color: CafeColors.border,
                                    height: 24,
                                  ),
                                  _infoRow(
                                    'Kode member',
                                    memberCode.isEmpty
                                        ? 'Belum ada'
                                        : memberCode,
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => widget.auth.signOut(),
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                            color: CafeColors.danger,
                          ),
                          label: Text(
                            'Keluar',
                            style: CafeText.buttonLabel.copyWith(
                              color: CafeColors.danger,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: CafeColors.danger,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: CafeText.cardSub),
        ),
        Expanded(
          child: Text(
            value,
            style: CafeText.body,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
