import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/service_repository.dart';
import 'service_materials_page.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({required this.isAdmin, super.key});

  final bool isAdmin;

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  late final ServiceRepository _repository;
  late Future<List<Map<String, dynamic>>> _servicesFuture;

  final TextEditingController _searchController = TextEditingController();

  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();

    _repository = ServiceRepository(Supabase.instance.client);
    _servicesFuture = _repository.fetchAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _servicesFuture = _repository.fetchAll();
    });
  }

  Future<void> _refresh() async {
    final future = _repository.fetchAll();

    setState(() {
      _servicesFuture = future;
    });

    try {
      await future;
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

  Future<void> _openForm({Map<String, dynamic>? service}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return _ServiceFormDialog(initial: service, onSave: _repository.save);
      },
    );

    if (saved == true && mounted) {
      _reload();

      _showMessage(
        service == null
            ? 'Layanan berhasil ditambahkan.'
            : 'Layanan berhasil diperbarui.',
      );
    }
  }

  Future<void> _toggleActive({required String id, required bool aktif}) async {
    setState(() {
      _busyIds.add(id);
    });

    try {
      await _repository.setActive(id: id, aktif: aktif);

      if (!mounted) return;

      _reload();

      _showMessage(
        aktif
            ? 'Layanan berhasil diaktifkan.'
            : 'Layanan berhasil dinonaktifkan.',
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage('Gagal mengubah status layanan: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busyIds.remove(id);
        });
      }
    }
  }

  String _formatCurrency(num amount) {
    final value = amount.round().toString();

    final formatted = value.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );

    return 'Rp $formatted';
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    final id = service['id_layanan'] as String;
    final name = service['nama_layanan'] as String? ?? '-';
    final unit = service['satuan'] as String? ?? '-';
    final price = service['harga'] as num? ?? 0;
    final isActive = service['aktif'] == true;
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
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Harga: ${_formatCurrency(price)} / $unit'),
                const SizedBox(height: 4),
                Text(
                  isActive ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    color: isActive
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w500,
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
                    // Tombol mengatur bahan layanan.
                    IconButton(
                      tooltip: 'Atur bahan layanan',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ServiceMaterialsPage(
                              serviceId: id,
                              serviceName: name,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.inventory_2_outlined),
                    ),

                    // Tombol edit layanan.
                    IconButton(
                      tooltip: 'Edit layanan',
                      onPressed: () {
                        _openForm(service: service);
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),

                    // Tombol mengubah status layanan.
                    Switch.adaptive(
                      value: isActive,
                      onChanged: isBusy
                          ? null
                          : (value) {
                              _toggleActive(id: id, aktif: value);
                            },
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Layanan')),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Layanan'),
            )
          : null,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          final services = snapshot.data ?? [];

          final keyword = _searchController.text.trim().toLowerCase();

          final filteredServices = services.where((service) {
            final name = (service['nama_layanan'] as String? ?? '')
                .toLowerCase();

            final unit = (service['satuan'] as String? ?? '').toLowerCase();

            return name.contains(keyword) || unit.contains(keyword);
          }).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Master Data Layanan',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isAdmin
                      ? 'Kelola nama, satuan, harga, dan status layanan.'
                      : 'Lihat daftar layanan dan harga yang tersedia.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama layanan...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 18),

                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  _MessagePanel(
                    icon: Icons.cloud_off_outlined,
                    message: 'Gagal memuat layanan.\n${snapshot.error}',
                    actionLabel: 'Coba Lagi',
                    onAction: _reload,
                  )
                else if (filteredServices.isEmpty)
                  const _MessagePanel(
                    icon: Icons.design_services_outlined,
                    message: 'Belum ada layanan yang cocok dengan pencarian.',
                  )
                else ...[
                  Text(
                    '${filteredServices.length} layanan ditemukan',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 12),
                  ...filteredServices.map(_buildServiceCard),
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

class _ServiceFormDialog extends StatefulWidget {
  const _ServiceFormDialog({required this.onSave, this.initial});

  final Map<String, dynamic>? initial;

  final Future<void> Function({
    String? id,
    required String nama,
    required String satuan,
    required double harga,
    required bool aktif,
  })
  onSave;

  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _priceController;

  late bool _isActive;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final initial = widget.initial;

    _nameController = TextEditingController(
      text: initial?['nama_layanan'] as String? ?? '',
    );

    _unitController = TextEditingController(
      text: initial?['satuan'] as String? ?? '',
    );

    _priceController = TextEditingController(
      text: (initial?['harga'] as num?)?.toString() ?? '',
    );

    _isActive = initial?['aktif'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final price = double.parse(
      _priceController.text.trim().replaceAll(',', '.'),
    );

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(
        id: widget.initial?['id_layanan'] as String?,
        nama: _nameController.text,
        satuan: _unitController.text,
        harga: price,
        aktif: _isActive,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menyimpan layanan: $error';
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
      title: Text(isEditing ? 'Edit Layanan' : 'Tambah Layanan'),
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
                    labelText: 'Nama layanan',
                    hintText: 'Contoh: Fotokopi hitam putih',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama layanan wajib diisi.';
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
                    hintText: 'Contoh: Lembar, Paket, Jam',
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
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Harga',
                    prefixText: 'Rp ',
                    hintText: 'Contoh: 500',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(
                      (value ?? '').trim().replaceAll(',', '.'),
                    );

                    if (parsed == null || parsed < 0) {
                      return 'Masukkan harga berupa angka 0 atau lebih.';
                    }

                    return null;
                  },
                ),

                if (isEditing) ...[
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Layanan aktif'),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
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

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
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
