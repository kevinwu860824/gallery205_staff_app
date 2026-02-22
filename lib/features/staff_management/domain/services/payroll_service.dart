import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class PayrollService {
  final SupabaseClient _supabase;

  PayrollService(this._supabase);

  // ---------------------------------------------------------------------------
  // Stage 1 & 2: Calculate Payroll Draft (Live Calculation)
  // ---------------------------------------------------------------------------
  
  /// Calculates the estimated payroll for a specific month.
  Future<List<PayrollReportItem>> calculateMonthlyPayroll({
    required String shopId,
    required int year,
    required int month,
  }) async {
    // 1. Define Period
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1)); // End of current month
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);

    // 2. Fetch Users & Salary Settings
    final userRes = await _supabase
        .from('user_shop_map')
        .select('user_id, salary_type, base_wage, users(name)')
        .eq('shop_code', shopId);

    final List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(userRes);

    // 3. Fetch Work Logs
    final logRes = await _supabase
        .from('work_logs')
        .select()
 
        .gte('date', startDate.toIso8601String())
        .lt('date', DateTime(year, month + 1, 1).toIso8601String())
        .order('clock_in');

    final List<Map<String, dynamic>> logs = List<Map<String, dynamic>>.from(logRes);

    // [NEW] 3.5 Fetch Leaves for Calculation
    final leavesRes = await _supabase.from('leave_records')
        .select()
        .eq('shop_id', shopId) 
        .gte('start_time', startDate.toIso8601String()) 
        .lt('start_time', DateTime(year, month + 1, 1).toIso8601String());
        // Note: Better to filter in-memory if query is complex.
    
    // Fetch all leaves for this shop/month to be safe
    // Ideally we should use user_id filter inside loop, but bulk fetch is better.
    // Let's rely on in-memory filtering for leaves as the dataset is small per month.

    final List<Map<String, dynamic>> allLeaves = List<Map<String, dynamic>>.from(leavesRes);
    
    // [NEW] 3.6 Fetch Saved Payroll Records (Settlements)
    final savedRes = await _supabase.from('payroll_records')
        .select('user_id, final_total, status, manual_overtime_hours') // Added manual_overtime_hours
        .eq('shop_id', shopId)
        .eq('period', startStr); // period is DATE type, so String match is fine
    
    final savedMap = {
      for (var r in savedRes) r['user_id']: r
    };

    // [NEW] 3.7 Fetch Shifts (For Smart Logic)
    final shiftsRes = await _supabase.from('schedule_assignments')
        .select('shift_date, shift_type_id, employee_id')
        .eq('shop_id', shopId)
        .gte('shift_date', startStr)
        .lte('shift_date', endStr);
        
    final shiftSettingsRes = await _supabase.from('shop_shift_settings')
        .select('id, shift_name, start_time, end_time')
        .eq('shop_id', shopId);

    final shiftDefs = {for (var s in shiftSettingsRes) s['id'].toString(): s};
    
    // [NEW] 3.8 Fetch OT Reports
    final otRes = await _supabase.from('work_reports')
        .select()
        .eq('shop_id', shopId)
        .gte('work_date', startDate.toIso8601String())
        .lt('work_date', DateTime(year, month + 1, 1).toIso8601String())
        .gt('hours', 0); 

    // 4. Calculation Engine
    List<PayrollReportItem> report = [];
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    for (var user in users) {
      final userId = user['user_id'];
      final userName = user['users']?['name'] ?? 'Unknown';
      final salaryType = user['salary_type'] ?? 'hourly';
      final baseWage = (user['base_wage'] as num? ?? 0).toDouble();

      // Filter Data
      final userLogs = logs.where((l) => l['user_id'] == userId).toList();
      final userLeaves = allLeaves.where((l) => l['user_id'] == userId).toList();
      final userShifts = (shiftsRes as List).where((s) => s['employee_id'] == userId).toList();
      final userOTs = (otRes as List).where((o) => o['user_id'] == userId).toList();
      
      // Lookups for Day loop
      // Lookups for Day loop
      // final logMap = {for (var l in userLogs) l['date']: l}; // [Removed] Map overwrites duplicates with Last. Detail view uses First.
      final shiftMap = {for (var s in userShifts) s['shift_date']: s};
      // Leave Map needs better handling for ranges, but for now assuming single day or start_time match
      // Simplification: Check if leave touches the day.
      // Optimization: Filter list inside loop is O(N*30), acceptable.
      final otMap = {for (var o in userOTs) o['work_date']: o};
      
      double totalRegularHours = 0;
      double totalOvertimeHours = 0;


      int attendanceDays = 0;
      Set<String> uniqueWorkDays = {};
      
      // Calculate per day
      for (int i = 1; i <= daysInMonth; i++) {
        final currentDay = DateTime(year, month, i);
        final currentDayStr = DateFormat('yyyy-MM-dd').format(currentDay);
        
        // Find Shift
        final shift = shiftMap[currentDayStr];
        DateTime? shiftStart, shiftEnd;
        String? shiftName;
        
        if (shift != null) {
          final def = shiftDefs[shift['shift_type_id']?.toString()];
           if (def != null) {
             shiftName = def['shift_name'];
             if (def['start_time'] != null && def['end_time'] != null) {
               final tStart = TimeOfDay.fromDateTime(DateFormat('HH:mm:ss').parse(def['start_time']));
               final tEnd = TimeOfDay.fromDateTime(DateFormat('HH:mm:ss').parse(def['end_time']));
               shiftStart = DateTime(year, month, i, tStart.hour, tStart.minute);
               shiftEnd = DateTime(year, month, i, tEnd.hour, tEnd.minute);
               if (shiftEnd.isBefore(shiftStart)) shiftEnd = shiftEnd.add(const Duration(days: 1));
             }
           }
        }
        

        
        // [Fixed] Use First Log (Match Detail View logic)
        final log = userLogs.where((l) => l['date'] == currentDayStr).firstOrNull;
        
        final status = _calculateSmartStatus(
           currentDay: currentDay,
           shiftStart: shiftStart,
           shiftEnd: shiftEnd,
           shiftName: shiftName,
           log: log,
           leave: userLeaves.where((l) {
               final t = DateTime.parse(l['start_time']).toLocal();
               return t.year == currentDay.year && t.month == currentDay.month && t.day == currentDay.day;
           }).firstOrNull,
           ot: otMap[currentDayStr]
        );
        
        totalRegularHours += status.regularHours;
        totalOvertimeHours += status.overtimeHours;
        
        if (status.actualIn != null) {
          uniqueWorkDays.add(currentDayStr);
        }
      }
      attendanceDays = uniqueWorkDays.length;
      
      // Add Manual OT from Saved Record
      final saved = savedMap[userId];
      final manualOt = saved != null ? (saved['manual_overtime_hours'] as num? ?? 0).toDouble() : 0.0;
      
      // Total Hours for Display = Regular + Tracked OT + Manual OT
      // Note: This aligns with User expectation "110.5" (108.5 + 2)
      final totalHours = totalRegularHours + totalOvertimeHours + manualOt;
      
      // Calculate Wage
      double estimatedWage = 0;
      
      if (salaryType == 'monthly') {
        final hourlyRate = baseWage / 240.0;
        double leaveDeduction = 0;
        
        // Need to loop days again? No, we didn't store day statuses.
        // Quick Fix: Re-loop leaves or accumulate deduction inside the day loop?
        // Since we refactored, let's just loop leaves again for deduction logic
        for (var leave in userLeaves) {
          final type = leave['leave_type'];
          final hours = (leave['hours'] as num? ?? 0).toDouble();
          if (type == 'sick') leaveDeduction += hours * hourlyRate * 0.5;
          else if (type == 'personal') leaveDeduction += hours * hourlyRate * 1.0;
        }
        
        estimatedWage = baseWage - leaveDeduction;
        estimatedWage += (totalOvertimeHours + manualOt) * hourlyRate * 1.33; // Add OT Pay
        
      } else {
        // Hourly
        // estimatedWage = (Regular + Tracked OT + Manual OT) * BaseWage
        estimatedWage = totalHours * baseWage;
      }

      report.add(PayrollReportItem(
        userId: userId,
        userName: userName,
        salaryType: salaryType,
        baseWage: baseWage,
        totalHours: totalHours,
        attendanceDays: attendanceDays,
        calculatedWage: estimatedWage,
        logs: userLogs,
        finalWage: saved != null ? (saved['final_total'] as num).toDouble() : null,
        settlementStatus: saved != null ? saved['status'] : null,
      ));
    }

    return report;
  }

  /// Calculates payroll for a SINGLE user (Live Re-calculation).
  /// Used by Detail Screen to update figures after fixes.
  Future<PayrollReportItem> calculateSingleUserPayroll({
    required String shopId,
    required String userId,
    required int year,
    required int month,
  }) async {
    // 0. Prep Dates
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1).subtract(const Duration(milliseconds: 1));
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);

    // 1. Get Smart Daily Statuses (The Source of Truth)
    final dailyStatuses = await getAttendanceReconciliation(
      userId: userId, 
      shopId: shopId, 
      year: year, 
      month: month
    );

    // 2. Fetch User Info
    final userRes = await _supabase.from('user_shop_map')
        .select('user_id, salary_type, base_wage, users(name)')
        .eq('shop_code', shopId)
        .eq('user_id', userId)
        .single();
    
    final userName = userRes['users']?['name'] ?? 'Unknown';
    final salaryType = userRes['salary_type'] ?? 'hourly';
    final baseWage = (userRes['base_wage'] as num? ?? 0).toDouble();

    // [Fixed Scope]: Fetch settlement FIRST if exists to get Manual OT
    final savedRecord = await getPayrollRecord(shopId: shopId, userId: userId, period: startDate);
    final manualOt = savedRecord != null ? (savedRecord['manual_overtime_hours'] as num? ?? 0).toDouble() : 0.0;
    
    // 3. Aggregate Hours
    double totalRegularHours = 0;
    double totalOvertimeHours = 0;
    int attendanceDays = 0;
    Set<DateTime> workDays = {};

    for (var status in dailyStatuses) {
      totalRegularHours += status.regularHours;
      totalOvertimeHours += status.overtimeHours;
      
      if (status.actualIn != null) {
        workDays.add(DateUtils.dateOnly(status.date));
      }
    }
    attendanceDays = workDays.length;
    
    // Total Hours = Regular + Tracked OT + Manual OT
    final totalHours = totalRegularHours + totalOvertimeHours + manualOt;

    // 4. Calculate Wage
    double estimatedWage = 0;
    
    if (salaryType == 'monthly') {
       final hourlyRate = baseWage / 240.0;
       double leaveDeduction = 0;
       
       for (var status in dailyStatuses) {
         if (status.leaveType != null) {
           final hours = status.leaveHours;
           if (status.leaveType == 'sick') {
             leaveDeduction += hours * hourlyRate * 0.5;
           } else if (status.leaveType == 'personal') {
             leaveDeduction += hours * hourlyRate * 1.0;
           }
         }
       }
       estimatedWage = baseWage - leaveDeduction;
       
       // Add Overtime Pay (Tracked + Manual)
       estimatedWage += (totalOvertimeHours + manualOt) * hourlyRate * 1.33; 
       
    } else {
       // Hourly: Pay for all hours (Regular + OT)
       estimatedWage = totalHours * baseWage;
    }

    // Fetch Logs
    final logsRes = await _supabase.from('work_logs')
            .select()
            .eq('shop_id', shopId)
            .eq('user_id', userId) 
            .gte('date', startStr)
            .lte('date', endStr);

    return PayrollReportItem(
      userId: userId,
      userName: userName,
      salaryType: salaryType,
      baseWage: baseWage,
      totalHours: totalHours,
      attendanceDays: attendanceDays,
      calculatedWage: estimatedWage,
      logs: List<Map<String, dynamic>>.from(logsRes),
      finalWage: savedRecord != null ? (savedRecord['final_total'] as num).toDouble() : null,
      settlementStatus: savedRecord != null ? savedRecord['status'] : null,
    );
  }

  // ---------------------------------------------------------------------------
  // [NEW] Intelligent Reconciliation (For Detail View)
  // ---------------------------------------------------------------------------

  // Refactored Helper: Pure Smart Logic
  DailyAttendanceStatus _calculateSmartStatus({
    required DateTime currentDay,
    required DateTime? shiftStart,
    required DateTime? shiftEnd,
    required String? shiftName,
    required Map<String, dynamic>? log,
    required Map<String, dynamic>? leave,
    required Map<String, dynamic>? ot,
  }) {
      // --- SMART CALCULATION LOGIC ---
      DateTime? actualIn = log != null ? DateTime.parse(log['clock_in']).toLocal() : null;
      DateTime? actualOut = log != null && log['clock_out'] != null ? DateTime.parse(log['clock_out']).toLocal() : null;
      
      DateTime? snappedIn;
      DateTime? snappedOut;
      double regularHours = 0;
      double otHours = 0;
      bool isLate = false;
      bool isEarlyLeave = false;
      bool isException = false;
      
      // Default Config (could be passed in)
      const int bufferMinutes = 30;
      const double breakHours = 0.5;
      
      if (shiftStart != null && shiftEnd != null && actualIn != null && actualOut != null) {
        // A. Start Time Logic
        final startDiff = actualIn.difference(shiftStart).inMinutes;
        
        if (startDiff.abs() <= bufferMinutes) {
          snappedIn = shiftStart;
        } else if (startDiff > bufferMinutes) {
          snappedIn = actualIn;
          isLate = true;
          isException = true;
        } else {
          snappedIn = shiftStart;
        }
        
        // B. End Time Logic
        final endDiff = actualOut.difference(shiftEnd).inMinutes;
        
        if (endDiff.abs() <= bufferMinutes) {
          snappedOut = shiftEnd;
        } else if (endDiff < -bufferMinutes) {
          snappedOut = actualOut;
          isEarlyLeave = true; 
          isException = true;
        } else {
          // Late Out > 30m
          if (ot != null) {
            snappedOut = shiftEnd;
            otHours = switch (ot['hours']) {
              int i => i.toDouble(),
              double d => d,
              num n => n.toDouble(),
              _ => 0.0,
            };
          } else {
             snappedOut = shiftEnd;
          }
        }
        
        // C. Duration Calculation
        if (snappedIn != null && snappedOut != null) {
          double duration = snappedOut.difference(snappedIn).inMinutes / 60.0;
          
          if (duration < 0) duration = 0; 
          
          if (duration < 0) duration = 0; 
          
          if (duration >= 4.0) {
            duration -= breakHours; // Deduct Break
          }
          
          // Prevent negative after break
          if (duration < 0) duration = 0;
          
          regularHours = duration;
        }
      } else if (actualIn != null && actualOut != null) {
         // No Shift (Work on Off Day?)
         regularHours = actualOut.difference(actualIn).inMinutes / 60.0;
         if (regularHours >= 4.0) regularHours -= breakHours; 
      }
      
      // D. Exception Logic (Missing Punch)
      if (shiftStart != null && (actualIn == null || actualOut == null) && leave == null) {
        isException = true;
      }

      return DailyAttendanceStatus(
        date: currentDay,
        shiftName: shiftName,
        shiftStart: shiftStart,
        shiftEnd: shiftEnd,
        actualIn: actualIn,
        actualOut: actualOut,
        
        snappedIn: snappedIn,
        snappedOut: snappedOut,
        regularHours: regularHours,
        overtimeHours: otHours,
        isLate: isLate,
        isEarlyLeave: isEarlyLeave,
        isException: isException,
        
        logId: log != null ? log['id'] : null,
        leaveType: leave != null ? leave['leave_type'] : null,
        leaveHours: leave != null ? (leave['hours'] as num).toDouble() : 0,
        leaveId: leave != null ? leave['id'] : null,
      );
  }

  // Smart Reconciliation using Helper
  Future<List<DailyAttendanceStatus>> getAttendanceReconciliation({
    required String userId,
    required String shopId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end.subtract(const Duration(days: 1)));

    // A. Fetch Shifts (Plan)
    final shiftsRes = await _supabase.from('schedule_assignments')
        .select('shift_date, shift_type_id')
        .eq('shop_id', shopId)
        .eq('employee_id', userId)
        .gte('shift_date', startStr)
        .lte('shift_date', endStr);

    final shiftSettingsRes = await _supabase.from('shop_shift_settings')
        .select('id, shift_name, start_time, end_time')
        .eq('shop_id', shopId);

    // B. Fetch Work Logs (Actual)
    final logsRes = await _supabase.from('work_logs')
        .select()
        .eq('user_id', userId)
        .eq('shop_id', shopId)
        .gte('date', startStr)
        .lte('date', endStr);
    
    // C. Fetch Leave Records (Exception)
    final leavesRes = await _supabase.from('leave_records')
        .select()
        .eq('user_id', userId)
        .eq('shop_id', shopId)
        .gte('start_time', start.toIso8601String())
        .lt('start_time', end.toIso8601String());

    // D. Fetch Overtime Records (From Work Reports)
    final otRes = await _supabase.from('work_reports')
        .select()
        .eq('user_id', userId)
        .eq('shop_id', shopId)
        .gte('work_date', startStr)
        .lte('work_date', endStr)
        .gt('hours', 0); 

    // Prepare lookups
    final Map<String, Map<String, dynamic>> shiftDefs = {
      for (var s in shiftSettingsRes) s['id'].toString(): s
    };
    
    final otLookup = {
      for (var o in otRes) o['work_date']: o
    };

    List<DailyAttendanceStatus> result = [];
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    for (int i = 1; i <= daysInMonth; i++) {
      final currentDay = DateTime(year, month, i);
      final currentDayStr = DateFormat('yyyy-MM-dd').format(currentDay);

      // 1. Find Shift
      final shift = (shiftsRes as List).where(
        (s) => s['shift_date'] == currentDayStr
      ).firstOrNull;
      
      DateTime? shiftStart;
      DateTime? shiftEnd;
      String? shiftName;

      if (shift != null) {
        final def = shiftDefs[shift['shift_type_id']?.toString()];
        if (def != null) {
           shiftName = def['shift_name'];
           if (def['start_time'] != null && def['end_time'] != null) {
             final tStart = TimeOfDay.fromDateTime(DateFormat('HH:mm:ss').parse(def['start_time']));
             final tEnd = TimeOfDay.fromDateTime(DateFormat('HH:mm:ss').parse(def['end_time']));
             shiftStart = DateTime(year, month, i, tStart.hour, tStart.minute);
             shiftEnd = DateTime(year, month, i, tEnd.hour, tEnd.minute);
             if (shiftEnd.isBefore(shiftStart)) {
               shiftEnd = shiftEnd.add(const Duration(days: 1));
             }
           }
        }
      }

      // 2. Find Logs
      final log = (logsRes as List).where(
        (l) => l['date'] == currentDayStr
      ).firstOrNull;

      // 3. Find Leave
      final leave = (leavesRes as List).where((l) {
        final t = DateTime.parse(l['start_time']).toLocal();
        return t.year == currentDay.year && t.month == currentDay.month && t.day == currentDay.day;
      }).firstOrNull;
      
      // 4. Find One-off OT
      final ot = otLookup[currentDayStr];

      result.add(_calculateSmartStatus(
        currentDay: currentDay, 
        shiftStart: shiftStart, 
        shiftEnd: shiftEnd, 
        shiftName: shiftName, 
        log: log, 
        leave: leave, 
        ot: ot
      ));
    }
    return result;
  }

  Future<void> _fixPunchFromSchedule({
    required String shopId,
    required String userId,
    required DateTime date,
    required DateTime shiftStart,
    required DateTime shiftEnd,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    
    // Strategy: Delete-Then-Insert
    // This handles cases where duplicates (multiple rows) might exist (causing error 406),
    // effectively "cleaning up" the day while setting the correct time.
    
    // 1. Delete any/all existing logs for this day
    await _supabase.from('work_logs').delete()
        .eq('shop_id', shopId)
        .eq('user_id', userId)
        .eq('date', dateStr);

    // 2. Insert the single correct record
    await _supabase.from('work_logs').insert({
      'shop_id': shopId,
      'user_id': userId,
      'date': dateStr,
      'clock_in': shiftStart.toUtc().toIso8601String(),
      'clock_out': shiftEnd.toUtc().toIso8601String(),
      'source': 'auto_fix', 
      'note': 'Auto-fixed from Schedule'
    });
  }

  // Public wrapper
  Future<void> fixPunchFromSchedule({
      required String shopId,
      required String userId,
      required DateTime date,
      required DateTime shiftStart,
      required DateTime shiftEnd,
  }) async {
      await _fixPunchFromSchedule(
          shopId: shopId, 
          userId: userId, 
          date: date, 
          shiftStart: shiftStart, 
          shiftEnd: shiftEnd
      );
  }

  // Helper to add leave record
  Future<void> addLeaveRecord({
    required String shopId,
    required String userId,
    required DateTime date,
    required String leaveType,
    required DateTime start,
    required DateTime end,
    required double hours,
  }) async {
    await _supabase.from('leave_records').insert({
      'shop_id': shopId,
      'user_id': userId,
      'leave_type': leaveType,
      'start_time': start.toUtc().toIso8601String(),
      'end_time': end.toUtc().toIso8601String(),
      'hours': hours,
      'status': 'approved',
    });
  }

  // ---------------------------------------------------------------------------
  // Stage 3: Settlement Management
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getPayrollRecord({
    required String shopId,
    required String userId,
    required DateTime period, 
  }) async {
    final periodStr = DateFormat('yyyy-MM-dd').format(period);
    
    final res = await _supabase
        .from('payroll_records')
        .select()
        .eq('shop_id', shopId)
        .eq('user_id', userId)
        .eq('period', periodStr)
        .maybeSingle();
        
    return res;
  }

  Future<void> savePayrollRecord({
    required String shopId,
    required String userId,
    required DateTime period,
    required double totalHours,
    required double baseWage,
    required double calculatedAmount,
    required List<Map<String, dynamic>> adjustments,
    required double finalTotal,
    required double manualOvertimeHours, // NEW
    String status = 'draft',
  }) async {
    final periodStr = DateFormat('yyyy-MM-dd').format(period);

    await _supabase.from('payroll_records').upsert({
      'shop_id': shopId,
      'user_id': userId,
      'period': periodStr,
      'total_hours': totalHours,
      'base_wage': baseWage,
      'calculated_amount': calculatedAmount,
      'adjustments': adjustments, 
      'manual_overtime_hours': manualOvertimeHours, // NEW
      'final_total': finalTotal,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'shop_id, user_id, period'); 
  }
}

// ---------------------------------------------------------------------------
// Entities
// ---------------------------------------------------------------------------

class PayrollReportItem {
  final String userId;
  final String userName;
  final String salaryType;
  final double baseWage;
  final double totalHours;
  final int attendanceDays;
  final double calculatedWage;
  final List<Map<String, dynamic>> logs;
  
  // Settlement Info (Merged from payroll_records)
  final double? finalWage;
  final String? settlementStatus;

  PayrollReportItem({
    required this.userId,
    required this.userName,
    required this.salaryType,
    required this.baseWage,
    required this.totalHours,
    required this.attendanceDays,
    required this.calculatedWage,
    required this.logs,
    this.finalWage,
    this.settlementStatus,
  });
}

class DailyAttendanceStatus {
  final DateTime date;
  final String? shiftName;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;
  final DateTime? actualIn;
  final DateTime? actualOut;
  
  // Smart Logic Fields
  final DateTime? snappedIn;
  final DateTime? snappedOut;
  final double regularHours;
  final double overtimeHours;
  final bool isLate;
  final bool isEarlyLeave;
  final bool isException;
  
  final String? logId;
  final String? leaveType;
  final double leaveHours;
  final String? leaveId;

  DailyAttendanceStatus({
    required this.date,
    this.shiftName,
    this.shiftStart,
    this.shiftEnd,
    this.actualIn,
    this.actualOut,
    
    this.snappedIn,
    this.snappedOut,
    this.regularHours = 0,
    this.overtimeHours = 0,
    this.isLate = false,
    this.isEarlyLeave = false,
    this.isException = false,
    
    this.logId,
    this.leaveType,
    this.leaveHours = 0,
    this.leaveId,
  });

  // Logic: Has Shift but Missed Log
  bool get isMissingPunch => shiftStart != null && actualIn == null && leaveType == null;
  
  // Logic: Has Leave
  bool get isLeave => leaveType != null;
  
  // Logic: Normal Work
  bool get isProperlWork => actualIn != null;

  // Logic: Abnormal (Missing, Late, Early, Exception)
  bool get isAbnormal => isMissingPunch || isLate || isEarlyLeave || isException;
}
