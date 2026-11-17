import 'package:supabase_flutter/supabase_flutter.dart';

class CafeOperationsService {
  static final SupabaseClient _db = Supabase.instance.client;

  static const staffRoles = {
    'manager': 'Manager',
    'cashier': 'Cashier',
    'chef': 'Chef / Kitchen Staff',
    'waiter': 'Waiter / Service Staff',
  };

  static Future<List<Map<String, dynamic>>> getProfiles() async {
    final rows = await _db
        .from('user_profiles')
        .select(
            'id, full_name, email, role, department, phone_number, status, created_at')
        .order('full_name');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> updateStaffRole({
    required String userId,
    required String role,
  }) async {
    final department = switch (role) {
      'manager' => 'Management',
      'cashier' => 'Sales & Billing',
      'chef' => 'Kitchen',
      'waiter' => 'Service',
      _ => 'Customer',
    };
    await _db.from('user_profiles').update({
      'role': role,
      'department': department,
      'status': 'approved',
    }).eq('id', userId);
  }

  static Future<List<Map<String, dynamic>>> getShifts() async {
    final rows = await _db
        .from('cafe_shifts')
        .select(
            '*, user_profiles!cafe_shifts_employee_id_fkey(full_name, email, role)')
        .order('starts_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> createShift({
    required String employeeId,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    String? notes,
  }) async {
    final currentUserId = _db.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('Please sign in again to schedule a shift.');
    }
    await _db.from('cafe_shifts').insert({
      'employee_id': employeeId,
      'title': title,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'notes': notes,
      'created_by': currentUserId,
    });
  }

  static Future<void> deleteShift(String shiftId) async {
    await _db.from('cafe_shifts').delete().eq('id', shiftId);
  }

  static Future<List<Map<String, dynamic>>> getAttendance({
    DateTime? workDate,
  }) async {
    final day = workDate ?? DateTime.now();
    final date = _dateKey(day);
    final rows = await _db
        .from('cafe_attendance')
        .select(
            '*, user_profiles!cafe_attendance_employee_id_fkey(full_name, email, role)')
        .eq('work_date', date)
        .order('check_in', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> recordCheckIn(String employeeId) async {
    final currentUserId = _db.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('Please sign in again to record attendance.');
    }
    await _db.from('cafe_attendance').insert({
      'employee_id': employeeId,
      'work_date': _dateKey(DateTime.now()),
      'recorded_by': currentUserId,
    });
  }

  static Future<void> recordCheckOut(String attendanceId) async {
    await _db
        .from('cafe_attendance')
        .update({
          'check_out': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', attendanceId)
        .isFilter('check_out', null);
  }

  static Future<List<Map<String, dynamic>>> getFeedback() async {
    final rows = await _db
        .from('cafe_feedback')
        .select('*, user_profiles(full_name, email)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> submitFeedback({
    required int rating,
    required String subject,
    required String message,
  }) async {
    final currentUserId = _db.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('Please sign in to send feedback.');
    }
    await _db.from('cafe_feedback').insert({
      'customer_id': currentUserId,
      'rating': rating,
      'subject': subject,
      'message': message,
    });
  }

  static Future<void> updateFeedback({
    required String feedbackId,
    required String status,
    String? adminNote,
  }) async {
    await _db.from('cafe_feedback').update({
      'status': status,
      'admin_note': adminNote,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', feedbackId);
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
