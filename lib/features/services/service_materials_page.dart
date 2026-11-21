
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/service_repository.dart';

class ServiceMaterialsPage extends StatefulWidget {
  const ServiceMaterialsPage({
    required this.serviceId,
    required this.serviceName,
    super.key,
  });

  final String serviceId;
  final String serviceName;

  @override
  State<ServiceMaterialsPage> createState() =>
      _ServiceMaterialsPageState();
}

class _ServiceMaterialsPageState
    extends State<ServiceMaterialsPage> {
  late final ServiceRepository _repository;
  late Future<_ServiceMaterialsData> _dataFuture;

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    _repository = ServiceRepository(
      Supabase.instance.client,
    );

    _dataFuture = _loadData();
  }

  Future<_ServiceMaterialsData> _loadData() async {
    final items = await _repository.fetchInventoryItems();

    final materials = await _repository.fetchMaterials(
      widget.serviceId,
    );

    return _ServiceMaterialsData(
      items: items,
      materials: materials,
    );
  }

  void _reload() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
  }

  Future<void> _openForm({
    required List<Map<String, dynamic>> items,
    Map<String, dynamic>? initial,
  }) async {
    if (items.isEmpty) {
      _showMessage(
        'Tambahkan barang inventaris terlebih dahulu.',
        isError: true,
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _ServiceMaterialFormDialog(
          items: items,
          initial: initial,
          onSave: ({
            required String itemId,
            required int quantity,
          }) {
            return _repository.saveMaterial(
              serviceId: widget.serviceId,
              itemId: itemId,
              quantity: quantity,
            );
          },
        );
      },
    );

    if (saved == true && mounted) {
      _reload();

      _showMessage(
        initial == null
            ? 'Bahan layanan berhasil ditambahkan.'
            : 'Pemakaian bahan berhasil diperbarui.',
      );
    }
  }

  Future<void> _removeMaterial(String itemId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus bahan layanan?'),
          content: const Text(
            'Barang ini tidak akan lagi tercatat sebagai '
            'kebutuhan untuk layanan tersebut.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await _repository.removeMaterial(
        serviceId: widget.serviceId,
        itemId: itemId,
      );

      if (!mounted) return;

      _reload();
      _showMessage('Bahan layanan berhasil dihapus.');
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Gagal menghapus bahan: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Widget _buildMaterialCard(
    Map<String, dynamic> material,
    List<Map<String, dynamic>> items,
  ) {
    final itemId = material['id_barang'] as String;
    final itemName =
        material['nama_barang'] as String? ?? '-';
    final unit = material['satuan'] as String? ?? '-';
    final quantity =
        (material['jumlah_per_layanan'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.inventory_2_outlined),
        ),
        title: Text(
          itemName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '$quantity $unit untuk setiap 1 ${widget.serviceName}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit pemakaian',
              onPressed: _isDeleting
                  ? null
                  : () {
                      _openForm(
                        items: items,
                        initial: material,
                      );
                    },
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Hapus bahan',
              onPressed: _isDeleting
                  ? null
                  : () => _removeMaterial(itemId),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bahan Layanan'),
      ),
      body: FutureBuilder<_ServiceMaterialsData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat bahan layanan.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _reload,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              _reload();

              try {
                await _dataFuture;
              } catch (_) {
                // Error ditampilkan oleh FutureBuilder.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.serviceName,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Atur jumlah barang yang digunakan untuk '
                  'setiap satuan layanan.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Contoh: jika satu layanan fotokopi '
                            'menggunakan 1 lembar kertas, isi '
                            'jumlah pemakaian 1 dengan satuan '
                            'Lembar. Stok akan dikurangi saat '
                            'transaksi disimpan.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daftar bahan',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${data.materials.length} bahan',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (data.materials.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_outlined,
                          size: 44,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Belum ada bahan yang diatur untuk layanan ini.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...data.materials.map(
                    (material) => _buildMaterialCard(
                      material,
                      data.items,
                    ),
                  ),

                if (data.items.isEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada barang inventaris. '
                    'Tambahkan barang terlebih dahulu di menu '
                    'Barang dan Stok.',
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 90),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            final data = await _dataFuture;

            if (!mounted) return;

            await _openForm(items: data.items);
          } catch (error) {
            if (mounted) {
              _showMessage(
                'Data inventaris belum dapat dimuat: $error',
                isError: true,
              );
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Bahan'),
      ),
    );
  }
}

class _ServiceMaterialsData {
  const _ServiceMaterialsData({
    required this.items,
    required this.materials,
  });

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> materials;
}

class _ServiceMaterialFormDialog extends StatefulWidget {
  const _ServiceMaterialFormDialog({
    required this.items,
    required this.onSave,
    this.initial,
  });

  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? initial;

  final Future<void> Function({
    required String itemId,
    required int quantity,
  }) onSave;

  @override
  State<_ServiceMaterialFormDialog> createState() =>
      _ServiceMaterialFormDialogState();
}

class _ServiceMaterialFormDialogState
    extends State<_ServiceMaterialFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController =
      TextEditingController();

  String? _selectedItemId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _selectedItemId =
        widget.initial?['id_barang'] as String? ??
        widget.items.first['id_barang'] as String;

    _quantityController.text =
        (widget.initial?['jumlah_per_layanan'] as num?)
                ?.toInt()
                .toString() ??
            '1';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final itemId = _selectedItemId;

    if (itemId == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        itemId: itemId,
        quantity: int.parse(
          _quantityController.text.trim(),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menyimpan bahan: $error';
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
      title: Text(
        isEditing ? 'Edit Pemakaian Bahan' : 'Tambah Bahan',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedItemId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pilih barang inventaris',
                ),
                items: widget.items.map((item) {
                  final id = item['id_barang'] as String;
                  final name =
                      item['nama_barang'] as String? ?? '-';
                  final unit =
                      item['satuan'] as String? ?? '-';

                  return DropdownMenuItem(
                    value: id,
                    child: Text(
                      '$name ($unit)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _selectedItemId = value;
                        });
                      },
                validator: (value) {
                  if (value == null) {
                    return 'Pilih barang terlebih dahulu.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah per satuan layanan',
                  hintText: 'Contoh: 1',
                ),
                validator: (value) {
                  final quantity = int.tryParse(
                    (value ?? '').trim(),
                  );

                  if (quantity == null || quantity <= 0) {
                    return 'Jumlah harus berupa bilangan bulat lebih dari 0.';
                  }

                  return null;
                },
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
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
