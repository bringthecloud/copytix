import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/inventory_repository.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({required this.isAdmin, super.key});

  final bool isAdmin;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final InventoryRepository _repository;

  late Future<List<Map<String, dynamic>>> _itemsFuture;
  Future<List<Map<String, dynamic>>>? _movementsFuture;

  final TextEditingController _searchController = TextEditingController();

  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();

    _repository = InventoryRepository(Supabase.instance.client);

    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    _itemsFuture = _repository.fetchAll();

    if (widget.isAdmin) {
      _movementsFuture = _repository.fetchRecentMovements();
    } else {
      _movementsFuture = null;
    }
  }

  void _reload() {
    setState(_loadData);
  }

  Future<void> _refresh() async {
    final itemsFuture = _repository.fetchAll();
    final movementsFuture = widget.isAdmin
        ? _repository.fetchRecentMovements()
        : null;

    setState(() {
      _itemsFuture = itemsFuture;
      _movementsFuture = movementsFuture;
    });

    try {
      await itemsFuture;

      if (movementsFuture != null) {
        await movementsFuture;
      }
    } catch (_) {
      // Error ditampilkan melalui FutureBuilder.
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _openItemForm({Map<String, dynamic>? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _InventoryFormDialog(
          initial: item,
          onSave: _repository.saveItem,
        );
      },
    );

    if (saved == true && mounted) {
      _reload();

      _showMessage(
        item == null
            ? 'Barang berhasil ditambahkan.'
            : 'Data barang berhasil diperbarui.',
      );
    }
  }

  Future<void> _openStockDialog({
    required String id,
    required String itemName,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _StockMovementDialog(
          itemName: itemName,
          onSave:
              ({
                required String jenis,
                required int jumlah,
                required String keterangan,
              }) {
                return _repository.recordMovement(
                  idBarang: id,
                  jenis: jenis,
                  jumlah: jumlah,
                  keterangan: keterangan,
                );
              },
        );
      },
    );

    if (saved == true && mounted) {
      _reload();

      _showMessage('Perubahan stok berhasil dicatat.');
    }
  }

  String _formatNumber(num value) {
    return value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null) return '-';

    final date = DateTime.tryParse(rawDate);

    if (date == null) return '-';

    final local = date.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day-$month-$year $hour:$minute';
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final id = item['id_barang'] as String;

    final name = item['nama_barang'] as String? ?? '-';

    final unit = item['satuan'] as String? ?? '-';

    final stock = (item['stok'] as num?)?.toInt() ?? 0;

    final minimumStock = (item['stok_minimum'] as num?)?.toInt() ?? 0;

    final isLowStock = stock <= minimumStock;
    final isBusy = _busyIds.contains(id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: ListTile(
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stok: ${_formatNumber(stock)} $unit'),
                const SizedBox(height: 4),
                Text(
                  'Stok minimum: '
                  '${_formatNumber(minimumStock)} $unit',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isLowStock
                        ? Colors.orange.withValues(alpha: 0.12)
                        : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLowStock ? 'Stok menipis' : 'Stok tersedia',
                    style: TextStyle(
                      color: isLowStock
                          ? Colors.orange.shade800
                          : Colors.green.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          isThreeLine: true,
          trailing: widget.isAdmin
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit barang',
                      onPressed: () {
                        _openItemForm(item: item);
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Catat perubahan stok',
                      onPressed: isBusy
                          ? null
                          : () {
                              _openStockDialog(id: id, itemName: name);
                            },
                      icon: const Icon(Icons.add_box_outlined),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildMovementHistory(Map<String, String> itemNames) {
    if (!widget.isAdmin || _movementsFuture == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _movementsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Riwayat mutasi tidak dapat dimuat: '
              '${snapshot.error}',
            ),
          );
        }

        final movements = snapshot.data ?? [];

        if (movements.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Belum ada riwayat perubahan stok.'),
          );
        }

        return Column(
          children: movements.map((movement) {
            final idBarang = movement['id_barang'] as String? ?? '';

            final jenis = movement['jenis'] as String? ?? '';

            final jumlah = (movement['jumlah'] as num?)?.toInt() ?? 0;

            final itemName = itemNames[idBarang] ?? 'Barang';

            final movementLabel = switch (jenis) {
              'masuk' => 'Stok masuk',
              'keluar' => 'Stok keluar',
              'penyesuaian' => 'Penyesuaian stok',
              'pembatalan' => 'Pembatalan',
              _ => jenis,
            };

            final amountLabel = jenis == 'penyesuaian'
                ? (jumlah > 0 ? '+$jumlah' : '$jumlah')
                : '$jumlah';

            final note = movement['keterangan'] as String? ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.history)),
                title: Text(itemName),
                subtitle: Text(
                  [
                    movementLabel,
                    if (note.isNotEmpty) note,
                    _formatDate(movement['tanggal_mutasi'] as String?),
                  ].join(' • '),
                ),
                trailing: Text(
                  amountLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Barang dan Stok')),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openItemForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Barang'),
            )
          : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];

          final keyword = _searchController.text.trim().toLowerCase();

          final filteredItems = items.where((item) {
            final name = (item['nama_barang'] as String? ?? '').toLowerCase();

            final unit = (item['satuan'] as String? ?? '').toLowerCase();

            return name.contains(keyword) || unit.contains(keyword);
          }).toList();

          final itemNames = {
            for (final item in items)
              item['id_barang'] as String:
                  item['nama_barang'] as String? ?? 'Barang',
          };

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text('Inventaris Barang', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  widget.isAdmin
                      ? 'Kelola barang dan catat setiap perubahan stok.'
                      : 'Lihat ketersediaan barang dan stok saat ini.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama barang...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),

                const SizedBox(height: 18),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  _InventoryMessagePanel(
                    icon: Icons.cloud_off_outlined,
                    message: 'Gagal memuat barang.\n${snapshot.error}',
                    actionLabel: 'Coba Lagi',
                    onAction: _reload,
                  )
                else if (filteredItems.isEmpty)
                  const _InventoryMessagePanel(
                    icon: Icons.inventory_2_outlined,
                    message: 'Belum ada barang yang cocok dengan pencarian.',
                  )
                else ...[
                  Text(
                    '${filteredItems.length} barang ditemukan',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  ...filteredItems.map(_buildItemCard),
                ],

                if (widget.isAdmin) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    'Riwayat Mutasi Stok',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildMovementHistory(itemNames),
                ],

                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InventoryFormDialog extends StatefulWidget {
  const _InventoryFormDialog({required this.onSave, this.initial});

  final Map<String, dynamic>? initial;

  final Future<void> Function({
    String? id,
    required String nama,
    required String satuan,
    required int stokMinimum,
  })
  onSave;

  @override
  State<_InventoryFormDialog> createState() => _InventoryFormDialogState();
}

class _InventoryFormDialogState extends State<_InventoryFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _minimumStockController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final initial = widget.initial;

    _nameController = TextEditingController(
      text: initial?['nama_barang'] as String? ?? '',
    );

    _unitController = TextEditingController(
      text: initial?['satuan'] as String? ?? '',
    );

    _minimumStockController = TextEditingController(
      text: (initial?['stok_minimum'] as num?)?.toInt().toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _minimumStockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        id: widget.initial?['id_barang'] as String?,
        nama: _nameController.text,
        satuan: _unitController.text,
        stokMinimum: int.parse(_minimumStockController.text.trim()),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menyimpan barang: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Barang' : 'Tambah Barang'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama barang',
                    hintText: 'Contoh: Kertas A4',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama barang wajib diisi.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _unitController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Satuan',
                    hintText: 'Contoh: Rim, Lembar, Botol',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Satuan wajib diisi.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _minimumStockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stok minimum',
                    hintText: 'Contoh: 5',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());

                    if (parsed == null || parsed < 0) {
                      return 'Masukkan bilangan bulat 0 atau lebih.';
                    }

                    return null;
                  },
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Stok awal barang dimulai dari 0. '
                    'Setelah disimpan, catat stok masuk melalui '
                    'menu perubahan stok.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

class _StockMovementDialog extends StatefulWidget {
  const _StockMovementDialog({required this.itemName, required this.onSave});

  final String itemName;

  final Future<void> Function({
    required String jenis,
    required int jumlah,
    required String keterangan,
  })
  onSave;

  @override
  State<_StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends State<_StockMovementDialog> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _quantityController = TextEditingController();

  final TextEditingController _noteController = TextEditingController();

  String _movementType = 'masuk';
  String _adjustmentDirection = 'tambah';

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quantity = int.parse(_quantityController.text.trim());

    final signedQuantity =
        _movementType == 'penyesuaian' && _adjustmentDirection == 'kurangi'
        ? -quantity
        : quantity;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        jenis: _movementType,
        jumlah: signedQuantity,
        keterangan: _noteController.text,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mencatat perubahan stok: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Perubahan Stok'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _movementType,
                  decoration: const InputDecoration(
                    labelText: 'Jenis perubahan',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'masuk', child: Text('Stok masuk')),
                    DropdownMenuItem(
                      value: 'penyesuaian',
                      child: Text('Penyesuaian stok'),
                    ),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;

                          setState(() {
                            _movementType = value;
                          });
                        },
                ),
                if (_movementType == 'penyesuaian') ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _adjustmentDirection,
                    decoration: const InputDecoration(
                      labelText: 'Arah penyesuaian',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'tambah',
                        child: Text('Tambah stok'),
                      ),
                      DropdownMenuItem(
                        value: 'kurangi',
                        child: Text('Kurangi stok'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;

                            setState(() {
                              _adjustmentDirection = value;
                            });
                          },
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Jumlah',
                    hintText: 'Masukkan jumlah barang',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());

                    if (parsed == null || parsed <= 0) {
                      return 'Jumlah harus berupa bilangan bulat lebih dari 0.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan (opsional)',
                    hintText: 'Contoh: Pembelian stok baru',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Catat'),
        ),
      ],
    );
  }
}

class _InventoryMessagePanel extends StatelessWidget {
  const _InventoryMessagePanel({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
