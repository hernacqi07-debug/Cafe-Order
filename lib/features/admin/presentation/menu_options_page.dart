import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/cafe_design.dart';
import '../../../core/utils/format.dart';
import '../data/admin_repository.dart';

/// Kelola opsi satu menu (C2): daftar grup opsi + nilainya,
/// tambah opsi (single/multiple, wajib/opsional) dan tambah nilai.
class MenuOptionsPage extends StatefulWidget {
  const MenuOptionsPage({super.key, required this.menu});

  final Map<String, dynamic> menu;

  @override
  State<MenuOptionsPage> createState() => _MenuOptionsPageState();
}

class _MenuOptionsPageState extends State<MenuOptionsPage> {
  final _repo = AdminRepository();
  List<Map<String, dynamic>> _options = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final options =
          await _repo.fetchMenuOptions(widget.menu['id'] as String);
      if (!mounted) return;
      setState(() {
        _options = options;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal memuat opsi: $e';
      });
    }
  }

  Future<void> _addOption() async {
    final nama = TextEditingController();
    var tipe = 'single';
    var wajib = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tambah opsi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nama,
                style: CafeText.body,
                decoration: const InputDecoration(
                  hintText: 'Nama opsi, mis. Ukuran',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipe,
                decoration: const InputDecoration(labelText: 'Tipe'),
                items: const [
                  DropdownMenuItem(
                    value: 'single',
                    child: Text('Single (pilih satu)'),
                  ),
                  DropdownMenuItem(
                    value: 'multiple',
                    child: Text('Multiple (boleh banyak)'),
                  ),
                ],
                onChanged: (v) =>
                    setDialogState(() => tipe = v ?? 'single'),
              ),
              Row(
                children: [
                  Checkbox(
                    value: wajib,
                    activeColor: CafeColors.accent,
                    onChanged: (v) =>
                        setDialogState(() => wajib = v ?? false),
                  ),
                  const Text('Wajib diisi'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: CafeColors.accent,
              ),
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || nama.text.trim().isEmpty) return;
    try {
      await _repo.addOption(
        menuId: widget.menu['id'] as String,
        nama: nama.text,
        tipe: tipe,
        wajib: wajib,
        urutan: _options.length + 1,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _addValue(Map<String, dynamic> option) async {
    final nama = TextEditingController();
    final harga = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah nilai — ${option['nama']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nama,
              style: CafeText.body,
              decoration: const InputDecoration(
                hintText: 'Nama nilai, mis. Large',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: harga,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: CafeText.body,
              decoration: const InputDecoration(
                hintText: 'Tambahan harga (Rp)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: CafeColors.accent,
            ),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (ok != true || nama.text.trim().isEmpty) return;
    try {
      await _repo.addOptionValue(
        optionId: option['id'] as String,
        nama: nama.text,
        tambahanHarga: int.tryParse(harga.text.trim()) ?? 0,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
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
        title: Text(
          'Opsi · ${widget.menu['nama']}',
          style: CafeText.pageTitle,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: CafeColors.ink),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOption,
        backgroundColor: CafeColors.accent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Tambah opsi',
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
              : _options.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Menu ini belum punya opsi. Tambah opsi '
                          'mis. Ukuran, Es, Gula, atau Tambahan.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: _options.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final option = _options[i];
                        final values =
                            (option['menu_option_values'] as List? ?? [])
                                .cast<Map<String, dynamic>>();
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
                                    child: Text(
                                      option['nama'] as String? ?? '',
                                      style: CafeText.toggleTitle,
                                    ),
                                  ),
                                  Text(
                                    '${option['tipe'] == 'multiple' ? 'Multiple' : 'Single'}'
                                    '${option['wajib'] == true ? ' · Wajib' : ''}',
                                    style: CafeText.cardSub,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: CafeColors.danger,
                                    ),
                                    onPressed: () async {
                                      await _repo.deleteOption(
                                        option['id'] as String,
                                      );
                                      await _load();
                                    },
                                  ),
                                ],
                              ),
                              for (final v in values) ...[
                                const Divider(color: CafeColors.border),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        v['nama'] as String? ?? '',
                                        style: CafeText.body,
                                      ),
                                    ),
                                    Text(
                                      (v['tambahan_harga'] as int? ?? 0) == 0
                                          ? '+Rp0'
                                          : '+${rupiah(v['tambahan_harga'] as int)}',
                                      style: CafeText.menuPrice,
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: CafeColors.danger,
                                      ),
                                      onPressed: () async {
                                        await _repo.deleteOptionValue(
                                          v['id'] as String,
                                        );
                                        await _load();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => _addValue(option),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Tambah nilai'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
