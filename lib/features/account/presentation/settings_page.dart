import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/cafe_design.dart';
import '../../../core/widgets/cafe_bottom_nav.dart';
import '../../auth/data/auth_repository.dart';

/// Pengaturan — mengikuti token desain Figma "Pemrograman-Mobile"
/// (frame Customer · Pengaturan).
///
/// Notifikasi meja memakai `table_notifications` yang sama dengan
/// Beranda & Lokasi. Tema gelap masih "segera hadir" (seperti tombol
/// tema di Beranda) — belum diimplementasikan.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.config,
    required this.auth,
  });

  final AppConfig config;
  final AuthRepository auth;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifyMe = false;
  bool _loadingNotify = true;

  @override
  void initState() {
    super.initState();
    _loadNotify();
  }

  Future<void> _loadNotify() async {
    final uid = widget.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loadingNotify = false);
      return;
    }
    try {
      final row = await Supabase.instance.client
          .from('table_notifications')
          .select('id')
          .eq('user_id', uid)
          .eq('aktif', true)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _notifyMe = row != null;
        _loadingNotify = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingNotify = false);
    }
  }

  Future<void> _onNotifyChanged(bool value) async {
    final previous = _notifyMe;
    setState(() => _notifyMe = value);
    final uid = widget.auth.currentUser?.id;
    if (uid == null) return;
    final client = Supabase.instance.client;
    try {
      if (value) {
        final existing = await client
            .from('table_notifications')
            .select('id')
            .eq('user_id', uid)
            .order('diminta_pada', ascending: false)
            .limit(1)
            .maybeSingle();
        if (existing == null) {
          await client.from('table_notifications').insert({'user_id': uid});
        } else {
          await client
              .from('table_notifications')
              .update({'aktif': true})
              .eq('id', existing['id']);
        }
      } else {
        await client
            .from('table_notifications')
            .update({'aktif': false})
            .eq('user_id', uid)
            .eq('aktif', true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _notifyMe = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan preferensi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        title: Text('Pengaturan', style: CafeText.pageTitle),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Notifikasi'),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: CafeColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kabari saya kalau ada meja',
                          style: CafeText.toggleTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Notifikasi saja, bukan reservasi.',
                          style: CafeText.toggleSub,
                        ),
                      ],
                    ),
                  ),
                  _loadingNotify
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _notifyMe,
                          activeThumbColor: CafeColors.accent,
                          onChanged: _onNotifyChanged,
                        ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Tampilan'),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: CafeColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tema gelap segera hadir'),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wb_sunny_outlined,
                      size: 20,
                      color: CafeColors.ink,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Tema gelap', style: CafeText.toggleTitle),
                    ),
                    Text('Segera hadir', style: CafeText.menuMeta),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Akun'),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: CafeColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => context.go('/profile'),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 20,
                          color: CafeColors.ink,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Profil saya',
                            style: CafeText.toggleTitle,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: CafeColors.muted,
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: CafeColors.border, height: 28),
                  InkWell(
                    onTap: () => widget.auth.signOut(),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout,
                          size: 20,
                          color: CafeColors.danger,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Keluar',
                          style: CafeText.toggleTitle.copyWith(
                            color: CafeColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Tentang'),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: CafeColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _infoRow('Aplikasi', widget.config.appName),
                  const Divider(color: CafeColors.border, height: 24),
                  _infoRow('Versi', '1.0.0+1'),
                  const Divider(color: CafeColors.border, height: 24),
                  _infoRow('Cafe', widget.config.cafeName),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CafeBottomNav(currentIndex: 4),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: CafeText.toggleTitle),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: CafeText.cardSub),
        Text(value, style: CafeText.body),
      ],
    );
  }
}
