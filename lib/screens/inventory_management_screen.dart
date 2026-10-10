import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../services/inventory_service.dart';

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<Map<String, dynamic>>> _itemsFuture;
  late Future<List<Map<String, dynamic>>> _suppliersFuture;
  late Future<List<Map<String, dynamic>>> _purchasesFuture;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (_tabController.indexIsChanging) return;
        setState(() => _selectedTab = _tabController.index);
      });
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload() {
    _itemsFuture = InventoryService.getItems();
    _suppliersFuture = InventoryService.getSuppliers();
    _purchasesFuture = InventoryService.getPurchases();
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save changes: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Inventory & Purchasing',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stock'),
            Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Suppliers'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Purchases'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildItems(),
          _buildSuppliers(),
          _buildPurchases(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addForSelectedTab,
        icon: const Icon(Icons.add),
        label: Text(
          switch (_selectedTab) {
            0 => 'Add item',
            1 => 'Add supplier',
            _ => 'Record purchase',
          },
        ),
      ),
    );
  }

  Widget _buildItems() => _futureList(
        _itemsFuture,
        emptyMessage: 'No stock items yet. Add an item to begin tracking.',
        itemBuilder: (item) {
          final quantity = _asDouble(item['stock_quantity']);
          final reorderLevel = _asDouble(item['reorder_level']);
          final isLow = quantity <= reorderLevel;
          final supplier = item['suppliers'] as Map<String, dynamic>?;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    isLow ? Colors.orange.shade100 : Colors.green.shade100,
                child: Icon(
                  isLow ? Icons.warning_amber : Icons.inventory_2_outlined,
                  color: isLow ? Colors.deepOrange : Colors.green.shade800,
                ),
              ),
              title: Text(item['name']?.toString() ?? 'Unnamed item'),
              subtitle: Text(
                '${item['category'] ?? 'Other'} · Reorder at $reorderLevel ${item['unit'] ?? 'pcs'}'
                '${supplier == null ? '' : '\nSupplier: ${supplier['name']}'}',
              ),
              isThreeLine: supplier != null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$quantity ${item['unit'] ?? 'pcs'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (isLow)
                        const Text(
                          'LOW STOCK',
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Adjust stock',
                    onPressed: () => _adjustStock(item),
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
            ),
          );
        },
      );

  Widget _buildSuppliers() => _futureList(
        _suppliersFuture,
        emptyMessage: 'No suppliers yet. Add your first supplier.',
        itemBuilder: (supplier) => Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
            title: Text(supplier['name']?.toString() ?? 'Supplier'),
            subtitle: Text([
              if ((supplier['phone'] ?? '').toString().isNotEmpty)
                supplier['phone'].toString(),
              if ((supplier['email'] ?? '').toString().isNotEmpty)
                supplier['email'].toString(),
              if ((supplier['address'] ?? '').toString().isNotEmpty)
                supplier['address'].toString(),
            ].join('\n')),
            isThreeLine: [
                  supplier['phone'],
                  supplier['email'],
                  supplier['address'],
                ].where((value) => (value ?? '').toString().isNotEmpty).length >
                1,
          ),
        ),
      );

  Widget _buildPurchases() => _futureList(
        _purchasesFuture,
        emptyMessage: 'No purchases recorded yet.',
        itemBuilder: (purchase) {
          final supplier = purchase['suppliers'] as Map<String, dynamic>?;
          final lines = (purchase['purchase_items'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          final lineSummary = lines.map((line) {
            final item = line['inventory_items'] as Map<String, dynamic>?;
            return '${item?['name'] ?? 'Item'}: ${line['quantity']} ${item?['unit'] ?? ''}';
          }).join(', ');
          final purchasedAt = DateTime.tryParse(
            purchase['purchased_at']?.toString() ?? '',
          );
          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.shopping_cart_checkout),
              ),
              title: Text(supplier?['name']?.toString() ?? 'Supplier'),
              subtitle: Text(
                '${purchasedAt == null ? '' : '${purchasedAt.toLocal()} · '}$lineSummary',
              ),
              isThreeLine: lineSummary.length > 40,
              trailing: Text(
                '৳${_asDouble(purchase['total_amount']).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      );

  Widget _futureList(
    Future<List<Map<String, dynamic>>> future, {
    required String emptyMessage,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load data: ${snapshot.error}'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) return Center(child: Text(emptyMessage));
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            itemBuilder: (context, index) => itemBuilder(rows[index]),
          ),
        );
      },
    );
  }

  Future<void> _addForSelectedTab() async {
    switch (_selectedTab) {
      case 0:
        await _showAddItemDialog();
        return;
      case 1:
        await _showAddSupplierDialog();
        return;
      case 2:
        await _showRecordPurchaseDialog();
        return;
    }
  }

  Future<void> _showAddSupplierDialog() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final address = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final values = await showDialog<List<String?>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add supplier'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _textInput(name, 'Supplier name', requiredField: true),
                  _textInput(phone, 'Phone'),
                  _textInput(email, 'Email'),
                  _textInput(address, 'Address'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, [
                    name.text.trim(),
                    phone.text.trim(),
                    email.text.trim(),
                    address.text.trim(),
                  ]);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (values == null) return;
      await _runAction(
        () => InventoryService.addSupplier(
          name: values[0]!,
          phone: _nullable(values[1]!),
          email: _nullable(values[2]!),
          address: _nullable(values[3]!),
        ),
        'Supplier saved.',
      );
    } finally {
      name.dispose();
      phone.dispose();
      email.dispose();
      address.dispose();
    }
  }

  Future<void> _showAddItemDialog() async {
    List<Map<String, dynamic>> suppliers;
    try {
      suppliers = await InventoryService.getSuppliers();
    } catch (e) {
      _showError('Could not load suppliers: $e');
      return;
    }
    if (!mounted) return;
    final name = TextEditingController();
    final category = TextEditingController(text: 'Other');
    final unit = TextEditingController(text: 'pcs');
    final reorderLevel = TextEditingController(text: '0');
    final unitCost = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    String? supplierId;
    try {
      final values = await showDialog<List<String?>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add stock item'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _textInput(name, 'Item name', requiredField: true),
                    _textInput(category, 'Category', requiredField: true),
                    _textInput(unit, 'Unit (kg, litre, pcs)',
                        requiredField: true),
                    _textInput(reorderLevel, 'Low-stock threshold',
                        numeric: true),
                    _textInput(unitCost, 'Current unit cost (Tk)',
                        numeric: true),
                    DropdownButtonFormField<String?>(
                      initialValue: supplierId,
                      decoration: const InputDecoration(labelText: 'Supplier'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No supplier'),
                        ),
                        ...suppliers.map(
                          (row) => DropdownMenuItem<String?>(
                            value: row['id'].toString(),
                            child: Text(row['name'].toString()),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => supplierId = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, [
                      name.text.trim(),
                      category.text.trim(),
                      unit.text.trim(),
                      reorderLevel.text.trim(),
                      unitCost.text.trim(),
                      supplierId,
                    ]);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (values == null) return;
      await _runAction(
        () => InventoryService.addItem(
          name: values[0]!,
          category: values[1]!,
          unit: values[2]!,
          reorderLevel: double.parse(values[3]!),
          unitCost: double.parse(values[4]!),
          supplierId: values[5],
        ),
        'Stock item saved.',
      );
    } finally {
      name.dispose();
      category.dispose();
      unit.dispose();
      reorderLevel.dispose();
      unitCost.dispose();
    }
  }

  Future<void> _showRecordPurchaseDialog() async {
    List<Map<String, dynamic>> suppliers;
    List<Map<String, dynamic>> items;
    try {
      suppliers = await InventoryService.getSuppliers();
      items = await InventoryService.getItems();
    } catch (e) {
      _showError('Could not load purchase options: $e');
      return;
    }
    if (!mounted) return;
    if (suppliers.isEmpty || items.isEmpty) {
      _showError('Add at least one supplier and one stock item first.');
      return;
    }
    final quantity = TextEditingController();
    final unitCost = TextEditingController();
    final notes = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String supplierId = suppliers.first['id'].toString();
    String itemId = items.first['id'].toString();
    try {
      final values = await showDialog<List<String>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Record purchase'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: supplierId,
                      decoration: const InputDecoration(labelText: 'Supplier'),
                      items: suppliers
                          .map((row) => DropdownMenuItem(
                                value: row['id'].toString(),
                                child: Text(row['name'].toString()),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => supplierId = value!),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: itemId,
                      decoration: const InputDecoration(labelText: 'Item'),
                      items: items
                          .map((row) => DropdownMenuItem(
                                value: row['id'].toString(),
                                child: Text(
                                  '${row['name']} (${row['unit'] ?? 'pcs'})',
                                ),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => itemId = value!),
                    ),
                    _textInput(quantity, 'Quantity received', numeric: true),
                    _textInput(unitCost, 'Cost per unit (Tk)', numeric: true),
                    _textInput(notes, 'Notes'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, [
                      supplierId,
                      itemId,
                      quantity.text.trim(),
                      unitCost.text.trim(),
                      notes.text.trim(),
                    ]);
                  }
                },
                child: const Text('Save purchase'),
              ),
            ],
          ),
        ),
      );
      if (values == null) return;
      await _runAction(
        () => InventoryService.recordPurchase(
          supplierId: values[0],
          itemId: values[1],
          quantity: double.parse(values[2]),
          unitCost: double.parse(values[3]),
          notes: _nullable(values[4]),
        ),
        'Purchase saved and stock updated.',
      );
    } finally {
      quantity.dispose();
      unitCost.dispose();
      notes.dispose();
    }
  }

  Future<void> _adjustStock(Map<String, dynamic> item) async {
    final quantity = TextEditingController();
    final reason = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final values = await showDialog<List<String>>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Adjust ${item['name']} stock'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textInput(quantity, 'Change (+/-)', numeric: true),
                _textInput(reason, 'Reason', requiredField: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, [
                    quantity.text.trim(),
                    reason.text.trim(),
                  ]);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
      if (values == null) return;
      await _runAction(
        () => InventoryService.adjustStock(
          itemId: item['id'].toString(),
          quantityDelta: double.parse(values[0]),
          reason: values[1],
        ),
        'Stock adjusted.',
      );
    } finally {
      quantity.dispose();
      reason.dispose();
    }
  }

  Widget _textInput(
    TextEditingController controller,
    String label, {
    bool requiredField = false,
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          if (requiredField && (value == null || value.trim().isEmpty)) {
            return 'Required';
          }
          if (numeric) {
            final parsed = double.tryParse(value?.trim() ?? '');
            if (parsed == null ||
                !parsed.isFinite ||
                parsed < 0 && label != 'Change (+/-)') {
              return 'Enter a valid non-negative number';
            }
            if (label == 'Change (+/-)' && parsed == 0) {
              return 'Enter a non-zero value';
            }
          }
          return null;
        },
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  double _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  String? _nullable(String value) => value.isEmpty ? null : value;
}
