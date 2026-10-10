import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryService {
  static final SupabaseClient _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getItems() async {
    final rows = await _db
        .from('inventory_items')
        .select('*, suppliers(name)')
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> getSuppliers() async {
    final rows = await _db.from('suppliers').select().order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<List<Map<String, dynamic>>> getPurchases() async {
    final rows = await _db
        .from('inventory_purchases')
        .select(
            '*, suppliers(name), purchase_items(quantity, unit_cost, inventory_items(name, unit))')
        .order('purchased_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> addSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    await _db.from('suppliers').insert({
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
    });
  }

  static Future<void> addItem({
    required String name,
    required String category,
    required String unit,
    required double reorderLevel,
    required double unitCost,
    String? supplierId,
  }) async {
    await _db.from('inventory_items').insert({
      'name': name,
      'category': category,
      'unit': unit,
      'reorder_level': reorderLevel,
      'unit_cost': unitCost,
      'supplier_id': supplierId,
    });
  }

  static Future<void> recordPurchase({
    required String supplierId,
    required String itemId,
    required double quantity,
    required double unitCost,
    String? notes,
  }) async {
    await _db.rpc('record_inventory_purchase', params: {
      'p_supplier_id': supplierId,
      'p_items': [
        {
          'item_id': itemId,
          'quantity': quantity,
          'unit_cost': unitCost,
        },
      ],
      'p_notes': notes,
    });
  }

  static Future<void> adjustStock({
    required String itemId,
    required double quantityDelta,
    required String reason,
  }) async {
    await _db.rpc('adjust_inventory_stock', params: {
      'p_item_id': itemId,
      'p_quantity_delta': quantityDelta,
      'p_reason': reason,
    });
  }
}
