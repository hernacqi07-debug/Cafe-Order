import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/cafe_design.dart';
import '../../auth/data/auth_repository.dart';

/// Kerangka bersama layar admin: AppBar + Drawer navigasi ke semua
/// seksi admin (C1–C7) + Keluar. Dipakai semua halaman `/admin/*`.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.auth,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final String currentRoute;
  final AuthRepository auth;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  static const _sections = [
    ('/admin', 'Dashboard', Icons.dashboard_outlined),
    ('/admin/menus', 'Kelola Menu', Icons.restaurant_menu_outlined),
    ('/admin/tables', 'Kelola Meja', Icons.table_restaurant_outlined),
    ('/admin/orders', 'Kelola Pesanan', Icons.receipt_long_outlined),
    ('/admin/reports', 'Laporan', Icons.bar_chart_outlined),
    ('/admin/staff', 'Kelola Staf', Icons.people_outline),
    ('/admin/customization', 'Kustomisasi', Icons.palette_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CafeColors.background,
      appBar: AppBar(
        backgroundColor: CafeColors.background,
        elevation: 0,
        title: Text(title, style: CafeText.pageTitle),
        centerTitle: false,
        actions: actions,
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: CafeColors.accent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Admin Cafe',
                      style: CafeText.cardTitle
                          .copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Panel pengelola cafe',
                      style: CafeText.cardSub
                          .copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              for (final (route, label, icon) in _sections)
                ListTile(
                  leading: Icon(
                    icon,
                    color: currentRoute == route
                        ? CafeColors.accent
                        : CafeColors.muted,
                  ),
                  title: Text(
                    label,
                    style: CafeText.body.copyWith(
                      fontWeight: currentRoute == route
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: currentRoute == route
                          ? CafeColors.accent
                          : CafeColors.ink,
                    ),
                  ),
                  selected: currentRoute == route,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (currentRoute != route) context.go(route);
                  },
                ),
              const Divider(color: CafeColors.border),
              ListTile(
                leading: const Icon(Icons.logout, color: CafeColors.danger),
                title: Text(
                  'Keluar',
                  style: CafeText.body.copyWith(color: CafeColors.danger),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await auth.signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
