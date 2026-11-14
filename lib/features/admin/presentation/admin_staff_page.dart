import 'package:flutter/material.dart';

import '../../../core/theme/cafe_design.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_repository.dart';
import 'admin_scaffold.dart';

/// Kelola Staf (C6): daftar akun + ubah peran + nonaktifkan.
///
/// Pembuatan akun Auth staf TIDAK bisa dari aplikasi (butuh
/// service_role key — tidak boleh ada di aplikasi). Alurnya:
/// 1. Admin membuat akun di dashboard Supabase (Authentication →
///    Users → Add user, isi email + password).
/// 2. Akun itu muncul di daftar ini (peran awal: customer).
/// 3. Admin ubah perannya di sini menjadi waitress / barista /
///    dapur / admin — langsung berlaku saat staf itu login lagi.
///
/// "Tambah staf" di bawah mencari akun dari email: kalau baris
/// profilnya sudah ada, perannya bisa langsung diubah; kalau belum,
/// tampil langkah dashboard di atas.
class AdminStaffPage extends StatefulWidget {
  const AdminStaffPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<AdminStaffPage> createState() => _AdminStaffPageState();
}

class _AdminStaffPageState extends State<AdminStaffPage> {
  final _repo = AdminRepository();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  static const _roles = ['customer', 'waitress', 'barista', 'dapur', 'admin'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await _repo.fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat pengguna: $e';
      });
    }
  }

  Future<void> _changeRole(Map<String, dynamic> user, String role) async {
    try {
      await _repo.updateUserRole(
        userId: user['id'] as String,
        role: role,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${user['nama']} kini berperan $role.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah peran: $e')),
      );
    }
  }

  Future<void> _deactivate(Map<String, dynamic> user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nonaktifkan ${user['nama']}?'),
        content: const Text(
          'Baris profilnya dihapus — akun itu kehilangan peran dan '
          'tidak bisa masuk layar staf. Untuk menghapus total, hapus '
          'juga di dashboard Supabase (Authentication → Users).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: CafeColors.danger,
            ),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteUserProfile(user['id'] as String);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _addStaff() async {
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah staf'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Akun login staf dibuat di dashboard Supabase '
              '(Authentication → Users → Add user). Setelah itu akun '
              'muncul di daftar ini dan perannya bisa diubah.',
              style: CafeText.cardSub,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              style: CafeText.body,
              decoration: const InputDecoration(
                hintText: 'Cari email akun yang sudah dibuat',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: CafeColors.accent,
            ),
            child: const Text('Cari'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final found = _users.where(
      (u) =>
          (u['email'] as String? ?? '').toLowerCase() ==
          email.text.trim().toLowerCase(),
    );
    if (!mounted) return;
    if (found.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email belum ada. Buat dulu akunnya di dashboard Supabase.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Akun ${found.first['nama']} ditemukan — ubah perannya '
            'lewat dropdown di daftar.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Kelola Staf',
      currentRoute: '/admin/staff',
      auth: widget.auth,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: CafeColors.ink),
          onPressed: _load,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStaff,
        backgroundColor: CafeColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah staf',
          style: CafeText.buttonLabel.copyWith(fontSize: 13),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _users.isEmpty
                  ? const Center(child: Text('Belum ada pengguna.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        itemCount: _users.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final user = _users[i];
                          final role = user['role'] as String? ?? 'customer';
                          final isSelf =
                              user['id'] == widget.auth.currentUser?.id;
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: CafeColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user['nama'] as String? ?? '-',
                                            style: CafeText.toggleTitle,
                                          ),
                                          Text(
                                            user['email'] as String? ?? '-',
                                            style: CafeText.cardSub,
                                          ),
                                          if ((user['no_hp'] as String?)
                                                  ?.isNotEmpty ==
                                              true)
                                            Text(
                                              user['no_hp'] as String,
                                              style: CafeText.cardSub,
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (!isSelf)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: CafeColors.danger,
                                        ),
                                        onPressed: () => _deactivate(user),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text('Peran: ', style: CafeText.cardSub),
                                    DropdownButton<String>(
                                      value: _roles.contains(role)
                                          ? role
                                          : 'customer',
                                      underline: const SizedBox.shrink(),
                                      items: _roles
                                          .map(
                                            (r) => DropdownMenuItem(
                                              value: r,
                                              child: Text(
                                                r,
                                                style: CafeText.body,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          _changeRole(user, v);
                                        }
                                      },
                                    ),
                                    if (isSelf)
                                      Text(
                                        '(akun ini)',
                                        style: CafeText.menuMeta,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
