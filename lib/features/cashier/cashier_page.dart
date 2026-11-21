
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/service_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import 'receipt_preview_page.dart';

class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  late final ServiceRepository _serviceRepository;
  late final TransactionRepository _transactionRepository;

  final TextEditingController _searchController =
      TextEditingController();

  final TextEditingController _amountController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  List<Map<String, dynamic>> _services = [];

  final Map<String, _CartItem> _cart = {};

  String _paymentMethod = 'tunai';

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    final client = Supabase.instance.client;

    _serviceRepository = ServiceRepository(client);
    _transactionRepository = TransactionRepository(client);

    _loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  Future<void> _loadServices() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final result = await _serviceRepository.fetchAll();

      if (!mounted) return;

      setState(() {
        _services = result
            .where((service) => service['aktif'] == true)
            .toList();
      });
    } catch (error) {
      if (!mounted) return;

      _showMessage('Failed to load services: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredServices {
    final keyword =
        _searchController.text.trim().toLowerCase();

    if (keyword.isEmpty) {
      return _services;
    }

    return _services.where((service) {
      final name =
          (service['nama_layanan'] ?? '')
              .toString()
              .toLowerCase();

      return name.contains(keyword);
    }).toList();
  }

  double get _total {
    return _cart.values.fold(
      0,
      (sum, item) => sum + item.price * item.quantity,
    );
  }

  int? get _receivedAmount {
    return int.tryParse(_amountController.text.trim());
  }

  double get _change {
    final received = _receivedAmount ?? 0;
    return received - _total;
  }

  bool get _canCheckout {
    if (_cart.isEmpty || _isSubmitting) {
      return false;
    }

    if (_paymentMethod == 'tunai') {
      final received = _receivedAmount;

      return received != null && received >= _total;
    }

    return true;
  }

  void _addToCart(Map<String, dynamic> service) {
    final id = service['id_layanan']?.toString();

    if (id == null || id.isEmpty) {
      _showMessage('Invalid service.');
      return;
    }

    final name =
        (service['nama_layanan'] ?? '').toString();

    final unit =
        (service['satuan'] ?? '').toString();

    final rawPrice = service['harga'];

    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse('$rawPrice') ?? 0;

    setState(() {
      final existing = _cart[id];

      if (existing == null) {
        _cart[id] = _CartItem(
          id: id,
          name: name,
          unit: unit,
          price: price,
          quantity: 1,
        );
      } else {
        _cart[id] = existing.copyWith(
          quantity: existing.quantity + 1,
        );
      }
    });
  }

  void _decreaseQuantity(String serviceId) {
    final existing = _cart[serviceId];

    if (existing == null) return;

    setState(() {
      if (existing.quantity <= 1) {
        _cart.remove(serviceId);
      } else {
        _cart[serviceId] = existing.copyWith(
          quantity: existing.quantity - 1,
        );
      }
    });
  }

  void _increaseQuantity(String serviceId) {
    final existing = _cart[serviceId];

    if (existing == null) return;

    setState(() {
      _cart[serviceId] = existing.copyWith(
        quantity: existing.quantity + 1,
      );
    });
  }

  void _removeFromCart(String serviceId) {
    setState(() {
      _cart.remove(serviceId);
    });
  }

  Future<void> _checkout() async {
    if (_isSubmitting) return;

    if (_cart.isEmpty) {
      _showMessage('Please add at least one service.');
      return;
    }

    double? amountReceived;

    if (_paymentMethod == 'tunai') {
      final received = _receivedAmount;

      if (received == null || received < _total) {
        _showMessage('Received amount is insufficient.');
        return;
      }

      amountReceived = received.toDouble();
    }

    setState(() {
      _isSubmitting = true;
    });

    Map<String, dynamic>? checkoutResult;
    Map<String, dynamic>? savedTransaction;

    try {
      // Prepare checkout items.
      final items = _cart.values.map((item) {
        return {
          'id_layanan': item.id,
          'jumlah': item.quantity,
        };
      }).toList();

      // Save transaction through Supabase RPC.
      checkoutResult = await _transactionRepository.checkout(
        items: items,
        paymentMethod: _paymentMethod,
        amountReceived: amountReceived,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (!mounted) return;

      // Clear cart only after checkout succeeds.
      setState(() {
        _cart.clear();
        _amountController.clear();
        _notesController.clear();
      });

      // Retrieve complete transaction information.
      final transactionId =
          checkoutResult['id_transaksi']?.toString();

      if (transactionId != null && transactionId.isNotEmpty) {
        try {
          savedTransaction =
              await _transactionRepository.fetchById(
            transactionId,
          );
        } catch (error) {
          // Checkout has already succeeded.
          // Do not retry checkout if receipt loading fails.
          debugPrint('Receipt data loading failed: $error');
        }
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage('Checkout failed: $error');

      return;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }

    if (!mounted) return;

    // Read transaction result.
    final transactionCode =
        checkoutResult['kode_transaksi']?.toString() ?? '-';

    final transactionTotal =
        _toNum(checkoutResult['total']);

    final received =
        _toNum(checkoutResult['uang_diterima']);

    final change =
        _toNum(checkoutResult['kembalian']);

    // Display transaction success before opening PDF.
    final openReceipt = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Transaction Successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 64,
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Checkout Completed!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Transaction: $transactionCode'),
              const SizedBox(height: 8),
              Text(
                'Total: ${_formatCurrency(transactionTotal)}',
              ),
              Text(
                'Received: ${_formatCurrency(received)}',
              ),
              Text(
                'Change: ${_formatCurrency(change)}',
              ),
              const SizedBox(height: 16),
              if (savedTransaction != null)
                const Text(
                  'Your receipt is ready. You can preview and share it as a PDF.',
                )
              else
                const Text(
                  'Your transaction has been saved, but receipt details could not be loaded. You can access it later from Transaction History.',
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Done'),
            ),
            if (savedTransaction != null)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(
                  Icons.picture_as_pdf_outlined,
                ),
                label: const Text('View PDF Receipt'),
              ),
          ],
        );
      },
    );

    if (!mounted) return;

    // Open PDF only when the user selects the receipt button.
    if (openReceipt == true && savedTransaction != null) {
      try {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReceiptPreviewPage(
              transaction: savedTransaction!,
            ),
          ),
        );
      } catch (error) {
        if (!mounted) return;

        _showMessage(
          'Transaction was saved, but PDF preview could not be opened: $error',
        );
      }
    }
  }

  num _toNum(dynamic value) {
    if (value is num) {
      return value;
    }

    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatCurrency(num value) {
    final formatted = value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $formatted';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Widget _buildSectionTitle(
    String title, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceCard(
    Map<String, dynamic> service,
  ) {
    final name =
        (service['nama_layanan'] ?? '').toString();

    final unit =
        (service['satuan'] ?? '').toString();

    final rawPrice = service['harga'];

    final price = rawPrice is num
        ? rawPrice
        : num.tryParse('$rawPrice') ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(name),
        subtitle: Text(
          '$unit • ${_formatCurrency(price)}',
        ),
        trailing: IconButton.filledTonal(
          tooltip: 'Add to cart',
          onPressed: () => _addToCart(service),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildCartItem(_CartItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.quantity} × ${_formatCurrency(item.price)}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(
                      item.price * item.quantity,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Decrease quantity',
              visualDensity: VisualDensity.compact,
              onPressed: () => _decreaseQuantity(item.id),
              icon: const Icon(
                Icons.remove_circle_outline,
              ),
            ),
            Text(
              '${item.quantity}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              tooltip: 'Increase quantity',
              visualDensity: VisualDensity.compact,
              onPressed: () => _increaseQuantity(item.id),
              icon: const Icon(
                Icons.add_circle_outline,
              ),
            ),
            IconButton(
              tooltip: 'Remove item',
              visualDensity: VisualDensity.compact,
              onPressed: () => _removeFromCart(item.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Payment'),

            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'tunai',
                  child: Text('Cash'),
                ),
                DropdownMenuItem(
                  value: 'non_tunai',
                  child: Text('Non-cash'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _paymentMethod = value;
                  _amountController.clear();
                });
              },
            ),

            if (_paymentMethod == 'tunai') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Amount received',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                  hintText: 'Enter received amount',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Change'),
                  Text(
                    _formatCurrency(
                      _receivedAmount == null || _change < 0
                          ? 0
                          : _change,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = _filteredServices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadServices,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle(
              'Available Services',
              subtitle: 'Select services to add them to your cart.',
            ),

            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search services',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (services.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No active services found.'),
                ),
              )
            else
              ...services.map(_buildServiceCard),

            const SizedBox(height: 24),

            _buildSectionTitle(
              'Cart',
              subtitle:
                  '${_cart.length} different service(s) selected.',
            ),

            if (_cart.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('Your cart is empty.'),
                ),
              )
            else
              ..._cart.values.map(_buildCartItem),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatCurrency(_total),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            _buildPaymentSection(),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canCheckout ? _checkout : null,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.point_of_sale_outlined,
                      ),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : 'Complete Checkout',
                ),
              ),
            ),

            if (_paymentMethod == 'tunai' &&
                _cart.isNotEmpty &&
                (_receivedAmount == null ||
                    _receivedAmount! < _total))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Enter an amount equal to or greater than the total.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CartItem {
  const _CartItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.quantity,
  });

  final String id;
  final String name;
  final String unit;
  final double price;
  final int quantity;

  _CartItem copyWith({
    int? quantity,
  }) {
    return _CartItem(
      id: id,
      name: name,
      unit: unit,
      price: price,
      quantity: quantity ?? this.quantity,
    );
  }
}
