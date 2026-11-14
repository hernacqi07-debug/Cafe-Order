import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/app_config.dart';
import '../../../core/theme/cafe_design.dart';
import '../../../core/widgets/cafe_bottom_nav.dart';
import '../../auth/data/auth_repository.dart';
import '../../cart/cart_controller.dart';
import '../../order/data/table_repository.dart';
import '../../order/data/table_session.dart';

/// Beranda customer sesuai desain Figma "Pemrograman-Mobile"
/// (frame Customer · Beranda).
///
/// Data live dari Supabase: nama cafe + nama user, jumlah meja kosong,
/// daftar menu (termasuk yang habis), pesanan aktif, dan status langganan
/// notifikasi meja. Keranjang disimpan di [CartController].
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.config,
    required this.auth,
    required this.cart,
    required this.tables,
  });

  final AppConfig config;
  final AuthRepository auth;
  final CartController cart;

  /// Meja yang sedang terhubung (dipulihkan dari DB saat aplikasi dibuka).
  final TableSession tables;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _filters = ['Semua', 'Kopi', 'Non-kopi', 'Makanan'];

  final _scrollController = ScrollController();
  final _menuSectionKey = GlobalKey();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _menusError;
  String _cafeName = '';
  String _userName = '';
  List<Map<String, dynamic>> _menus = [];
  int? _freeTables;
  Map<String, dynamic>? _activeOrder;
  bool _notifyMe = false;

  String _query = '';
  String _filter = 'Semua';

  @override
  void initState() {
    super.initState();
    _cafeName = widget.config.cafeName;
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<T?> _guard<T>(Future<T> future) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _menusError = null;
    });
    final client = Supabase.instance.client;
    final uid = widget.auth.currentUser?.id;

    List<Map<String, dynamic>> menus = [];
    String? menusError;
    try {
      final res = await client
          .from('menus')
          .select(
            'id, nama, deskripsi, kategori, harga, foto_url, '
            'waktu_produksi_menit, is_available, stations(nama)',
          )
          .order('kategori')
          .order('nama');
      menus = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      menusError = '$e';
    }

    final results = await Future.wait([
      _guard(
        client.from('cafes').select('nama').limit(1).maybeSingle(),
      ),
      uid == null
          ? Future<Map<String, dynamic>?>.value()
          : _guard(
              client.from('users').select('nama').eq('id', uid).maybeSingle(),
            ),
      _guard(client.from('tables').select('status')),
      uid == null
          ? Future<Map<String, dynamic>?>.value()
          : _guard(
              client
                  .from('orders')
                  .select('kode, status, estimasi_siap_pada')
                  .eq('user_id', uid)
                  .inFilter('status', const [
                    'masuk',
                    'sedang_dibuat',
                    'siap_diambil',
                  ])
                  .order('dibuat_pada', ascending: false)
                  .limit(1)
                  .maybeSingle(),
            ),
      uid == null
          ? Future<Map<String, dynamic>?>.value()
          : _guard(
              client
                  .from('table_notifications')
                  .select('id')
                  .eq('user_id', uid)
                  .eq('aktif', true)
                  .maybeSingle(),
            ),
      // Pulihkan sesi meja: kalau user masih menempati meja di DB,
      // hubungkan lagi sesi in-memory-nya.
      uid == null || widget.tables.hasTable
          ? Future<Map<String, dynamic>?>.value()
          : _guard(TableRepository().fetchOccupiedByUser(uid)),
    ]);

    if (!mounted) return;
    final cafeRow = results[0] as Map<String, dynamic>?;
    final profileRow = results[1] as Map<String, dynamic>?;
    final tables = results[2] as List?;
    final order = results[3] as Map<String, dynamic>?;
    final notifyRow = results[4] as Map<String, dynamic>?;
    final occupiedTable = results[5] as Map<String, dynamic>?;

    // Pulihkan sesi meja yang masih ditempati user ini.
    if (occupiedTable != null && !widget.tables.hasTable) {
      widget.tables.link(
        tableId: occupiedTable['id'] as String,
        tableKode: occupiedTable['kode'] as String? ?? '',
      );
    }

    final email = widget.auth.currentUser?.email ?? '';
    var displayName = (profileRow?['nama'] as String?)?.trim() ?? '';
    if (displayName.isEmpty && email.contains('@')) {
      final prefix = email.split('@').first;
      displayName =
          prefix.isEmpty ? '' : prefix[0].toUpperCase() + prefix.substring(1);
    }

    setState(() {
      _loading = false;
      _menus = menus;
      _menusError = menusError;
      if ((cafeRow?['nama'] as String?)?.isNotEmpty == true) {
        _cafeName = cafeRow!['nama'] as String;
      }
      _userName = displayName;
      _freeTables = tables
          ?.where((t) => (t as Map)['status'] == 'kosong')
          .length;
      _activeOrder = order;
      _notifyMe = notifyRow != null;
    });
  }

  String _greetingWord() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'SELAMAT PAGI';
    if (hour < 15) return 'SELAMAT SIANG';
    if (hour < 19) return 'SELAMAT SORE';
    return 'SELAMAT MALAM';
  }

  String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  String _rupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final rev = s.length - 1 - i;
      buf.write(s[rev]);
      if (i % 3 == 2 && i != s.length - 1) buf.write('.');
    }
    return 'Rp${buf.toString().split('').reversed.join()}';
  }

  String _orderStatusLabel(String status) {
    return switch (status) {
      'menunggu_bayar' => 'Menunggu Bayar',
      'masuk' => 'Masuk',
      'sedang_dibuat' => 'Sedang Dibuat',
      'siap_diambil' => 'Siap Diambil',
      'selesai' => 'Selesai',
      'dibatalkan' => 'Dibatalkan',
      _ => status,
    };
  }

  bool _matchesFilter(Map<String, dynamic> menu) {
    final kategori = menu['kategori'] as String?;
    return switch (_filter) {
      'Kopi' => kategori == 'Kopi',
      'Non-kopi' =>
        kategori != null &&
            kategori != 'Kopi' &&
            !{'Makanan', 'Roti', 'Snack'}.contains(kategori),
      'Makanan' => {'Makanan', 'Roti', 'Snack'}.contains(kategori),
      _ => true,
    };
  }

  List<Map<String, dynamic>> get _visibleMenus {
    final q = _query.trim().toLowerCase();
    return _menus.where((m) {
      if (!_matchesFilter(m)) return false;
      if (q.isEmpty) return true;
      return (m['nama'] as String? ?? '').toLowerCase().contains(q);
    }).toList();
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

  void _addToCart(Map<String, dynamic> menu) {
    widget.cart.add(
      menuId: menu['id'] as String,
      nama: menu['nama'] as String? ?? '-',
      harga: (menu['harga'] as num?)?.toInt() ?? 0,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${menu['nama']} ditambahkan ke keranjang'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil saya'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go('/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Keluar',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                widget.auth.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuPhoto(Map<String, dynamic> menu) {
    final available = menu['is_available'] as bool? ?? true;
    final fotoUrl = menu['foto_url'] as String?;
    final asset = !available
        ? 'assets/images/menu_unavailable.jpg'
        : (menu['kategori'] as String?) == 'Kopi'
            ? 'assets/images/menu_coffee.jpg'
            : 'assets/images/menu_food.jpg';
    if (fotoUrl != null && fotoUrl.isNotEmpty) {
      return Image.network(
        fotoUrl,
        height: 126,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Image.asset(asset, height: 126, width: double.infinity,
                fit: BoxFit.cover),
      );
    }
    return Image.asset(asset,
        height: 126, width: double.infinity, fit: BoxFit.cover);
  }

  Widget _menuCard(Map<String, dynamic> menu) {
    final available = menu['is_available'] as bool? ?? true;
    final station = (menu['stations'] is Map)
        ? (menu['stations'] as Map)['nama'] as String? ?? ''
        : '';
    final minutes = (menu['waktu_produksi_menit'] as num?)?.toInt() ?? 5;
    return Opacity(
      opacity: available ? 1 : 0.6,
      child: InkWell(
        onTap: available
            ? () => context.go('/menu/${menu['id']}')
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: CafeColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _menuPhoto(menu),
              ),
              const SizedBox(height: 9),
              Text(
                menu['nama'] as String? ?? '-',
                style: CafeText.menuName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$station · ±$minutes menit',
                style: CafeText.menuMeta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Text(
                    _rupiah((menu['harga'] as num?)?.toInt() ?? 0),
                    style: CafeText.menuPrice,
                  ),
                  const Spacer(),
                  if (available)
                    InkWell(
                      onTap: () => _addToCart(menu),
                      borderRadius: BorderRadius.circular(13),
                      child: const Icon(
                        Icons.add_circle_outline,
                        size: 25,
                        color: CafeColors.ink,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: CafeColors.background,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Habis',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CafeColors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CafeColors.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _menusError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Gagal memuat menu:\n$_menusError',
                            textAlign: TextAlign.center,
                          ),
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
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildGreeting(),
                        const SizedBox(height: 20),
                        _buildPromo(),
                        const SizedBox(height: 10),
                        _buildPromoDots(),
                        const SizedBox(height: 20),
                        _buildTableCard(),
                        const SizedBox(height: 20),
                        _buildMenuSection(),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: const CafeBottomNav(currentIndex: 0),
    );
  }

  Widget _buildGreeting() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_cafeName.toUpperCase()} · ${_greetingWord()}',
                style: CafeText.eyebrow(),
              ),
              const SizedBox(height: 3),
              Text('Halo, ${_userName.isEmpty ? 'Kamu' : _userName}.',
                  style: CafeText.greeting),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _circleButton(
          Icons.wb_sunny_outlined,
          Colors.white,
          () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tema gelap segera hadir')),
          ),
        ),
        const SizedBox(width: 8),
        _circleButton(
          Icons.person_outline,
          CafeColors.cream,
          _showProfileSheet,
        ),
      ],
    );
  }

  Widget _circleButton(
    IconData icon,
    Color bg,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: CafeColors.ink),
      ),
    );
  }

  Widget _buildPromo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 252,
        width: double.infinity,
        color: CafeColors.cream,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/promo_coffee.jpg',
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('JEDA YANG KAMU BUTUHKAN',
                      style: CafeText.promoEyebrow),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 195,
                    child: Text('Kopi enak.\nHari hangat.',
                        style: CafeText.promoTitle),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 170,
                    child: Text(
                      'Racikan favorit, dibuat segar untuk setiap cerita.',
                      style: CafeText.promoDesc,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => Scrollable.ensureVisible(
                      _menuSectionKey.currentContext!,
                      duration: const Duration(milliseconds: 400),
                    ),
                    child: Text('Lihat menu  →', style: CafeText.promoLink),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 20,
          height: 5,
          decoration: BoxDecoration(
            color: CafeColors.accent,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        _dot(),
        const SizedBox(width: 5),
        _dot(),
      ],
    );
  }

  Widget _dot() {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: CafeColors.border,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildTableCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CafeColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _freeTables == null
                ? 'Meja tersedia'
                : '±$_freeTables meja tersedia',
            style: CafeText.cardTitle,
          ),
          const SizedBox(height: 4),
          Text(
            'Pembaruan ${_hhmm(DateTime.now())} · perkiraan, bukan jaminan',
            style: CafeText.cardSub,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kabari saya kalau ada meja',
                        style: CafeText.toggleTitle),
                    const SizedBox(height: 4),
                    Text('Notifikasi saja, bukan reservasi.',
                        style: CafeText.toggleSub),
                  ],
                ),
              ),
              Switch(
                value: _notifyMe,
                activeThumbColor: CafeColors.accent,
                onChanged: _onNotifyChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/scan'),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: Text('Scan QR meja untuk dine-in',
                  style: CafeText.buttonLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: CafeColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    final visible = _visibleMenus;
    final rows = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < visible.length; i += 2) {
      rows.add(visible.sublist(
        i,
        i + 2 > visible.length ? visible.length : i + 2,
      ));
    }
    return Column(
      key: _menuSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Mau pesan apa?', style: CafeText.sectionTitle),
            const Spacer(),
            IconButton(
              tooltip: 'Notifikasi',
              icon: const Icon(
                Icons.notifications_outlined,
                color: CafeColors.ink,
              ),
              onPressed: () => context.go('/notifications'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: CafeColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 18, color: CafeColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CafeColors.ink,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari kopi, makanan, atau favoritmu',
                    hintStyle: CafeText.searchHint,
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final f in _filters)
              InkWell(
                onTap: () => setState(() => _filter = f),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _filter == f ? CafeColors.accent : Colors.white,
                    border: _filter == f
                        ? null
                        : Border.all(color: CafeColors.border),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    f,
                    style: _filter == f
                        ? CafeText.chipActive
                        : CafeText.chipInactive,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Tidak ada menu yang cocok.',
                style: CafeText.cardSub,
              ),
            ),
          )
        else
          for (final row in rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _menuCard(row[0])),
                const SizedBox(width: 12),
                Expanded(
                  child: row.length > 1
                      ? _menuCard(row[1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        if (_activeOrder != null) ...[
          const SizedBox(height: 8),
          _buildActiveOrder(),
          const SizedBox(height: 20),
        ],
        ListenableBuilder(
          listenable: widget.cart,
          builder: (context, _) {
            if (widget.cart.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/cart'),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: Text(
                      'Keranjang · ${widget.cart.totalItems} item    '
                      '${_rupiah(widget.cart.totalPrice)}',
                      style: CafeText.buttonLabel,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CafeColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => context.go('/history'),
              child: Text('Riwayat transaksi →', style: CafeText.shortcut),
            ),
            InkWell(
              onTap: () => context.go('/profile'),
              child: Text('Profil saya →', style: CafeText.shortcut),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveOrder() {
    final order = _activeOrder!;
    final kode = order['kode'] as String? ?? '-';
    final status = _orderStatusLabel(order['status'] as String? ?? '');
    final estimasiRaw = order['estimasi_siap_pada'] as String?;
    final estimasi = estimasiRaw == null
        ? null
        : DateTime.tryParse(estimasiRaw)?.toLocal();
    return InkWell(
      onTap: () => context.go('/tracking/$kode'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CafeColors.softGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$kode · $status', style: CafeText.orderTitle),
            const SizedBox(height: 4),
            Text(
              estimasi == null
                  ? 'Lacak pesanan →'
                  : 'Paket siap sekitar ${_hhmm(estimasi)} · Lacak pesanan →',
              style: CafeText.orderSub,
            ),
          ],
        ),
      ),
    );
  }
}
