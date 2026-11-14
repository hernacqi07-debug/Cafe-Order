import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../features/account/presentation/history_page.dart';
import '../../features/account/presentation/notifications_page.dart';
import '../../features/account/presentation/profile_page.dart';
import '../../features/account/presentation/settings_page.dart';
import '../../features/admin/presentation/admin_customization_page.dart';
import '../../features/admin/presentation/admin_dashboard_page.dart';
import '../../features/admin/presentation/admin_menus_page.dart';
import '../../features/admin/presentation/admin_orders_page.dart';
import '../../features/admin/presentation/admin_reports_page.dart';
import '../../features/admin/presentation/admin_staff_page.dart';
import '../../features/admin/presentation/admin_tables_page.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/cart/cart_controller.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/order/data/order_repository.dart';
import '../../features/order/data/table_session.dart';
import '../../features/order/presentation/cart_page.dart';
import '../../features/order/presentation/checkout_page.dart';
import '../../features/order/presentation/location_page.dart';
import '../../features/order/presentation/menu_detail_page.dart';
import '../../features/order/presentation/pay_qris_page.dart';
import '../../features/order/presentation/scan_table_page.dart';
import '../../features/order/presentation/table_link_page.dart';
import '../../features/order/presentation/track_order_page.dart';
import '../../features/staff/presentation/kds_page.dart';
import '../../features/staff/presentation/waitress_scan_page.dart';
import '../../features/staff/presentation/waitress_tables_page.dart';

/// App routes, mirroring Alur_Layar_Aplikasi_Order_Cafe.md.
///
/// Auth guard: customers must log in (no guest mode — per MVP decision).
/// Unauthenticated users are redirected to /login; logged-in users
/// visiting /login or /register are sent to their role home.
///
/// Role routing ("Akun staf diarahkan sesuai peran", sesuai footer
/// halaman Masuk): customer → `/`, waitress → `/staff/tables`,
/// barista → `/staff/kds?station=bar`, dapur → `/staff/kds?station=dapur`,
/// admin → `/admin`. Peran dibaca dari `public.users.role` oleh
/// [AuthRepository]; selama peran belum dimuat, tidak ada redirect
/// berbasis peran (menghindari loop).
///
/// Deep link from table QR codes (Model A smart QR / Model B plain QR):
///   /t/:tableCode            -> links the table, opens home
/// (Model A additionally resolves the cafe from the QR host/path.)
GoRouter buildRouter({
  required AppConfig config,
  required AuthRepository auth,
  required CartController cart,
  required TableSession tables,
  required OrderRepository orders,
}) {
  bool isStaffOrAdminLoc(String loc) =>
      loc == '/staff/tables' ||
      loc.startsWith('/staff/') ||
      loc == '/admin' ||
      loc.startsWith('/admin/');

  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final loc = state.matchedLocation;
      final onAuthPage = loc == '/login' || loc == '/register';
      if (!loggedIn && !onAuthPage) return '/login';
      if (loggedIn && onAuthPage) return auth.roleHome;
      if (!loggedIn) return null;
      final role = auth.role;
      if (role == null) return null;
      if (role == 'customer' && isStaffOrAdminLoc(loc)) return '/';
      if (role != 'customer' && !isStaffOrAdminLoc(loc)) {
        return auth.roleHome;
      }
      return null;
    },
    routes: [
      // ── Customer ──────────────────────────────────────────────
      GoRoute(
        path: '/',
        builder: (_, _) => HomePage(
          config: config,
          auth: auth,
          cart: cart,
          tables: tables,
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => LoginPage(config: config, auth: auth),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) => RegisterPage(config: config, auth: auth),
      ),
      GoRoute(
        path: '/menu/:id',
        builder: (_, state) => MenuDetailPage(
          menuId: state.pathParameters['id']!,
          cart: cart,
        ),
      ),
      GoRoute(
        path: '/cart',
        builder: (_, _) => CartPage(cart: cart, tables: tables),
      ),
      GoRoute(
        path: '/checkout',
        builder: (_, _) => CheckoutPage(
          cart: cart,
          tables: tables,
          auth: auth,
          orders: orders,
        ),
      ),
      GoRoute(
        path: '/pay/:kode',
        builder: (_, state) => PayQrisPage(
          kode: state.pathParameters['kode']!,
          orders: orders,
          cart: cart,
        ),
      ),
      GoRoute(
        path: '/tracking',
        builder: (_, _) => TrackOrderPage(
          orders: orders,
          userId: auth.currentUser?.id,
        ),
      ),
      GoRoute(
        path: '/tracking/:code',
        builder: (_, state) => TrackOrderPage(
          kode: state.pathParameters['code'],
          orders: orders,
          userId: auth.currentUser?.id,
        ),
      ),
      GoRoute(
        path: '/history',
        builder: (_, _) => HistoryPage(auth: auth, orders: orders),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => ProfilePage(auth: auth),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => NotificationsPage(
          config: config,
          auth: auth,
          orders: orders,
        ),
      ),
      GoRoute(
        path: '/lokasi',
        builder: (_, _) => LocationPage(
          config: config,
          auth: auth,
          tables: tables,
        ),
      ),
      GoRoute(
        path: '/scan',
        builder: (_, _) => ScanTablePage(
          config: config,
          auth: auth,
          tables: tables,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => SettingsPage(config: config, auth: auth),
      ),
      // Table QR deep link
      GoRoute(
        path: '/t/:tableCode',
        builder: (_, state) => TableLinkPage(
          tableCode: state.pathParameters['tableCode']!,
          auth: auth,
          tables: tables,
        ),
      ),

      // ── Staff ─────────────────────────────────────────────────
      GoRoute(
        path: '/staff/tables',
        builder: (_, _) => WaitressTablesPage(auth: auth),
      ),
      GoRoute(
        path: '/staff/scan',
        builder: (_, _) => WaitressScanPage(auth: auth),
      ),
      GoRoute(
        path: '/staff/kds',
        builder: (_, state) => KdsPage(
          station: state.uri.queryParameters['station'] ?? 'bar',
          auth: auth,
        ),
      ),

      // ── Admin ─────────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        builder: (_, _) => AdminDashboardPage(auth: auth),
      ),
      GoRoute(
        path: '/admin/menus',
        builder: (_, _) => AdminMenusPage(auth: auth),
      ),
      GoRoute(
        path: '/admin/tables',
        builder: (_, _) => AdminTablesPage(auth: auth),
      ),
      GoRoute(
        path: '/admin/orders',
        builder: (_, _) => AdminOrdersPage(auth: auth),
      ),
      GoRoute(
        path: '/admin/reports',
        builder: (_, _) => AdminReportsPage(auth: auth),
      ),
      GoRoute(
        path: '/admin/staff',
        builder: (_, _) => AdminStaffPage(auth: auth),
      ),
      GoRoute(
        path: '/admin/customization',
        builder: (_, _) => AdminCustomizationPage(auth: auth),
      ),
    ],
  );
}
