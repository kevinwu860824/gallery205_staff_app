import 'dart:convert';

class RecurrenceRule {
  final String freq; // 'daily', 'weekly', 'monthly', 'yearly'
  final int interval; // 每 n 週/月
  
  // Weekly
  final List<int>? byWeekDays; // 1=Mon...7=Sun
  
  // Monthly
  final String? monthlyType; // 'date', 'day'
  final int? byMonthDay; // 15 (15號)
  final int? bySetPos; // 2 (第2個), -1 (最後一個)
  final int? byDay; // 2 (週二)

  RecurrenceRule({
    required this.freq,
    this.interval = 1,
    this.byWeekDays,
    this.monthlyType,
    this.byMonthDay,
    this.bySetPos,
    this.byDay,
  });

  // 從 JSON 讀取
  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      freq: json['freq'] ?? 'daily',
      interval: json['interval'] ?? 1,
      byWeekDays: json['by_days'] != null ? List<int>.from(json['by_days']) : null,
      monthlyType: json['monthly_type'],
      byMonthDay: json['by_month_day'],
      bySetPos: json['by_set_pos'],
      byDay: json['by_day'],
    );
  }

  // 轉成 JSON 存檔
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'freq': freq,
      'interval': interval,
    };
    if (freq == 'weekly' && byWeekDays != null) {
      data['by_days'] = byWeekDays;
    }
    if (freq == 'monthly') {
      data['monthly_type'] = monthlyType;
      if (monthlyType == 'date') {
        data['by_month_day'] = byMonthDay;
      } else {
        data['by_set_pos'] = bySetPos;
        data['by_day'] = byDay;
      }
    }
    return data;
  }

  // 🔥 核心邏輯：判斷 checkDate 這一天，是否符合此規則
  bool matches(DateTime checkDate, DateTime startDate) {
    // 1. 先把時間統一歸零，只比對日期
    final target = DateTime(checkDate.year, checkDate.month, checkDate.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    if (target.isBefore(start)) return false;

    switch (freq) {
      case 'daily':
        // 計算天數差是否為 interval 的倍數
        int daysDiff = target.difference(start).inDays;
        return daysDiff % interval == 0;

      case 'weekly':
        // 1. 判斷星期幾是否吻合
        if (byWeekDays != null && !byWeekDays!.contains(target.weekday)) {
          return false;
        }
        // 2. 判斷是否為間隔週 (這是比較簡化的算法，以開始日所在的週為基準)
        // 為了精確，我們計算「總週數差」
        int daysSinceStart = target.difference(start).inDays;
        // 調整偏移量，讓 start 變成該週的第一天(假設週一)來計算
        int startWeekOffset = start.weekday - 1; 
        int targetWeekOffset = target.weekday - 1;
        // 算出這是第幾週 (0-based)
        int weekIndex = (daysSinceStart + startWeekOffset) ~/ 7;
        return weekIndex % interval == 0;

      case 'monthly':
        // 1. 計算月數差
        int monthDiff = (target.year - start.year) * 12 + target.month - start.month;
        if (monthDiff % interval != 0) return false;

        // 2. 比對規則
        if (monthlyType == 'date') {
          // 依日期：例如每個月 9 號
          // 注意：如果該月沒有 31 號，這會自動失效 (Dart DateTime 容錯需注意，但在此邏輯檢查即可)
          return target.day == (byMonthDay ?? start.day);
        } else {
          // 依星期：例如每個月第 2 個 週二
          if (target.weekday != (byDay ?? start.weekday)) return false;
          
          // 計算今天是該月的第幾個週X
          int pos = ((target.day - 1) / 7).floor() + 1;
          
          // 處理 "最後一個" (-1) 的情況
          if (bySetPos == -1) {
             // 檢查下週是否跨月，若跨月代表這是最後一個
             DateTime nextWeek = target.add(const Duration(days: 7));
             return nextWeek.month != target.month;
          }
          
          return pos == bySetPos;
        }

      case 'yearly':
        // 簡易版：每年同一天
        int yearDiff = target.year - start.year;
        if (yearDiff % interval != 0) return false;
        return target.month == start.month && target.day == start.day;

      default:
        return false;
    }
  }
}