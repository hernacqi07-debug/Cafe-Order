import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/cart/cart_controller.dart';
import 'features/order/data/order_repository.dart';
import 'features/order/data/table_session.dart';

/// Root widget. Everything brand-related comes from [AppConfig] —
/// nothing cafe-specific may be hard-coded in the widget tree.
class CafeApp extends StatefulWidget {
  const CafeApp({super.key, required this.config, required this.auth});

  final AppConfig config;
  final AuthRepository auth;

  @override
  State<CafeApp> createState() => _CafeAppState();
}

class _CafeAppState extends State<CafeApp> {
  final CartController _cart = CartController();
  final TableSession _tables = TableSession();
  final OrderRepository _orders = OrderRepository();

  @override
  void dispose() {
    _cart.dispose();
    _tables.dispose();
    widget.auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: widget.config.appName,
      theme: buildTheme(widget.config),
      routerConfig: buildRouter(
        config: widget.config,
        auth: widget.auth,
        cart: _cart,
        tables: _tables,
        orders: _orders,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
