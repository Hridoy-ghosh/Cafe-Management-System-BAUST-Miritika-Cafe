import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cafeteria_model.dart';

class CafeteriaService {
  static final SupabaseClient _db = Supabase.instance.client;
  static List<CafeteriaOrder> _cachedOrders = [];

  static Stream<List<CafeteriaOrder>> streamAllOrders() => _orderStream();

  static Stream<List<CafeteriaOrder>> streamOrdersByUser(String userId) =>
      _orderStream(userId: userId);

  static Stream<List<CafeteriaOrder>> _orderStream({String? userId}) {
    return Stream<List<CafeteriaOrder>>.multi((controller) {
      Future<void> emit() async {
        try {
          final rows = userId == null
              ? await _db
                  .from('cafe_orders')
                  .select()
                  .order('created_at', ascending: false)
              : await _db
                  .from('cafe_orders')
                  .select()
                  .eq('user_id', userId)
                  .order('created_at', ascending: false);
          final orders = List<Map<String, dynamic>>.from(rows)
              .map((row) => CafeteriaOrder.fromMap(
                    _fromDatabase(row),
                    row['id'].toString(),
                  ))
              .toList(growable: false);
          if (userId == null) _cachedOrders = orders;
          controller.add(orders);
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
        }
      }

      unawaited(emit());
      final timer = Timer.periodic(const Duration(seconds: 4), (_) => emit());
      controller.onCancel = timer.cancel;
    });
  }

  static Map<String, dynamic> _fromDatabase(Map<String, dynamic> row) => {
        'id': row['id'],
        'userId': row['user_id'],
        'userName': row['user_name'],
        'userDept': row['user_department'],
        'userPhone': row['user_phone'],
        'items': row['items'],
        'totalAmount': row['total_amount'],
        'paymentMethod': row['order_type'],
        'paymentChannel': row['payment_method'],
        'paymentStatus': row['payment_status'],
        'status': row['status'],
        'orderTime': row['created_at'],
        'token': row['token'],
        'transactionId': row['payment_reference'],
        if (row['payment_method'] == 'bkash')
          'bkashNumber': row['payment_number'],
        if (row['payment_method'] == 'nagad')
          'nagadNumber': row['payment_number'],
        'tableNumber': row['table_number'],
        'floor': row['floor'],
        'deliveredTime': row['delivered_at'],
      };

  static Future<void> addOrder(CafeteriaOrder order) async {
    final orderItems = order.items
        .map((item) => {
              'id': item['id'].toString(),
              'quantity': item['quantity'],
            })
        .toList(growable: false);
    await _db.rpc('place_cafe_order', params: {
      'p_items': orderItems,
      'p_order_type': order.paymentMethod,
      'p_payment_method': order.paymentChannel,
      'p_token': order.token,
      'p_table_number': order.tableNumber,
      'p_floor': order.floor,
      'p_payment_reference': order.transactionId,
      'p_payment_number': order.paymentChannel == 'bkash'
          ? order.bkashNumber
          : order.paymentChannel == 'nagad'
              ? order.nagadNumber
              : null,
    });
  }

  static Future<void> updateOrderStatus(
    String orderId,
    String newStatus,
  ) async {
    final updates = <String, dynamic>{'status': newStatus};
    if (newStatus == 'delivered') {
      updates['delivered_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _db.from('cafe_orders').update(updates).eq('id', orderId);
  }

  static Future<void> updatePaymentStatus(
    String orderId,
    String paymentStatus,
  ) async {
    await _db
        .from('cafe_orders')
        .update({'payment_status': paymentStatus}).eq('id', orderId);
  }

  static Future<void> deleteOrder(String orderId) async {
    await _db.from('cafe_orders').delete().eq('id', orderId);
  }

  static bool isTableBooked(String floor, String tableNumber) {
    final now = DateTime.now();
    return _cachedOrders.any((order) =>
        order.tableNumber == tableNumber &&
        order.floor == floor &&
        (order.status == 'pending' ||
            order.status == 'preparing' ||
            order.status == 'ready' ||
            (order.status == 'delivered' &&
                order.deliveredTime != null &&
                now.difference(order.deliveredTime!).inMinutes < 30)));
  }

  static List<String> getAvailableTables(String floor, List<String> allTables) {
    final busyTables = _cachedOrders
        .where((order) =>
            order.floor == floor &&
            order.tableNumber != null &&
            (order.status == 'pending' ||
                order.status == 'preparing' ||
                order.status == 'ready' ||
                (order.status == 'delivered' &&
                    order.deliveredTime != null &&
                    DateTime.now().difference(order.deliveredTime!).inMinutes <
                        30)))
        .map((order) => order.tableNumber)
        .toSet();
    return allTables.where((table) => !busyTables.contains(table)).toList();
  }

  static double calculateTotalRevenue(List<CafeteriaOrder> orders) => orders
      .where((order) => order.status == 'delivered')
      .fold(0, (sum, order) => sum + order.totalAmount);

  static double calculateTodayRevenue(List<CafeteriaOrder> orders) {
    final today = DateTime.now();
    return orders
        .where((order) =>
            order.status == 'delivered' &&
            order.orderTime.year == today.year &&
            order.orderTime.month == today.month &&
            order.orderTime.day == today.day)
        .fold(0, (sum, order) => sum + order.totalAmount);
  }

  static Map<String, int> calculateItemSalesCount(
    List<CafeteriaOrder> orders,
  ) {
    final sales = <String, int>{};
    for (final order in orders.where((item) => item.status == 'delivered')) {
      for (final item in order.items) {
        final name = item['name'] as String;
        final quantity = item['quantity'] as int;
        sales[name] = (sales[name] ?? 0) + quantity;
      }
    }
    return sales;
  }
}
