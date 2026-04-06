// ScheduleWidget.swift
import WidgetKit
import SwiftUI
import Foundation

// MARK: - Constants
private let supabaseURL = "https://olqqtmfokvnzrinmqmfy.supabase.co"
private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9scXF0bWZva3ZuenJpbm1xbWZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc1NTY4ODQsImV4cCI6MjA2MzEzMjg4NH0.ZsFmoAl26m4cRXKjaHHnVANgLaY8NHOB8GOsoJWa47Y"
private let appGroupID = "group.com.caffreywu.tableOrderingApp"

// MARK: - Color helpers
extension Color {
    init(hex: String) {
        var s = hex.replacingOccurrences(of: "#", with: "")
        if s.count == 6 { s = "FF" + s }
        let v = UInt64(s, radix: 16) ?? 0xFFFFFFFF
        self.init(
            red:     Double((v >> 16) & 0xFF) / 255,
            green:   Double((v >> 8)  & 0xFF) / 255,
            blue:    Double(v         & 0xFF) / 255,
            opacity: Double((v >> 24) & 0xFF) / 255
        )
    }
}

func hexToColor(_ hex: String) -> Color { Color(hex: hex) }

func isColorLight(_ color: Color) -> Bool {
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    return (0.299 * r + 0.587 * g + 0.114 * b) > 0.5
}

// MARK: - Week start (Sunday-based, matching Flutter logic)
func weekStartDate(for date: Date) -> Date {
    let cal = Calendar.current
    let wd = cal.component(.weekday, from: date) // 1=Sun...7=Sat
    let subtract = wd - 1  // 0 for Sunday, 1 for Monday, ... 6 for Saturday
    return cal.startOfDay(for: cal.date(byAdding: .day, value: -subtract, to: date)!)
}

// MARK: - Recurrence Rule (ported from Dart)
struct RecurrenceRule {
    let freq: String
    let interval: Int
    let byWeekDays: [Int]?   // 1=Mon...7=Sun (Dart style)
    let monthlyType: String?
    let byMonthDay: Int?
    let bySetPos: Int?
    let byDay: Int?

    init(json: [String: Any]) {
        freq        = json["freq"]          as? String ?? "daily"
        interval    = json["interval"]      as? Int    ?? 1
        byWeekDays  = json["by_days"]       as? [Int]
        monthlyType = json["monthly_type"]  as? String
        byMonthDay  = json["by_month_day"]  as? Int
        bySetPos    = json["by_set_pos"]    as? Int
        byDay       = json["by_day"]        as? Int
    }

    // Swift weekday (1=Sun) -> Dart weekday (1=Mon...7=Sun)
    private func dartWeekday(_ swiftWD: Int) -> Int {
        return swiftWD == 1 ? 7 : swiftWD - 1
    }

    func matches(checkDate: Date, startDate: Date) -> Bool {
        let cal = Calendar.current
        let target = cal.startOfDay(for: checkDate)
        let start  = cal.startOfDay(for: startDate)
        guard target >= start else { return false }

        switch freq {
        case "daily":
            let days = cal.dateComponents([.day], from: start, to: target).day ?? 0
            return days % interval == 0

        case "weekly":
            let targetWD = cal.component(.weekday, from: target)
            if let byWeekDays, !byWeekDays.contains(dartWeekday(targetWD)) { return false }
            let days = cal.dateComponents([.day], from: start, to: target).day ?? 0
            let startWD = cal.component(.weekday, from: start)
            let startOffset = startWD == 1 ? 6 : startWD - 2  // Mon=0
            let weekIndex = (days + startOffset) / 7
            return weekIndex % interval == 0

        case "monthly":
            let months = cal.dateComponents([.month], from: start, to: target).month ?? 0
            guard months % interval == 0 else { return false }
            if monthlyType == "date" {
                return cal.component(.day, from: target) == (byMonthDay ?? cal.component(.day, from: start))
            } else {
                let targetWD = dartWeekday(cal.component(.weekday, from: target))
                let startWD  = dartWeekday(cal.component(.weekday, from: start))
                guard targetWD == (byDay ?? startWD) else { return false }
                let dayOfMonth = cal.component(.day, from: target)
                let pos = (dayOfMonth - 1) / 7 + 1
                if bySetPos == -1 {
                    if let nextWeek = cal.date(byAdding: .day, value: 7, to: target) {
                        return cal.component(.month, from: nextWeek) != cal.component(.month, from: target)
                    }
                    return false
                }
                return pos == bySetPos
            }

        case "yearly":
            let years = cal.dateComponents([.year], from: start, to: target).year ?? 0
            guard years % interval == 0 else { return false }
            return cal.component(.month, from: target) == cal.component(.month, from: start)
                && cal.component(.day, from: target)   == cal.component(.day, from: start)

        default:
            return false
        }
    }
}

// MARK: - Models
struct ShiftDefinition {
    let name: String
    let startTime: String
    let endTime: String
    let color: Color
}

struct VisualEvent: Identifiable {
    let id: String
    let title: String
    let color: Color
    let dayIndex: Int
    let start: Date
    let end: Date
}

struct WeekData {
    let shiftColors: [Int: Color]          // dayIndex 0=Sun...6=Sat
    let todayShifts: [ShiftDefinition]
    let weekEvents: [Int: [VisualEvent?]]  // dayIndex -> row slots (nil = spacer)
}

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let weekData: WeekData?
    let isLoggedIn: Bool
}

// MARK: - Timeline Provider
struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), weekData: nil, isLoggedIn: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        Task { completion(await fetchEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetchEntry() async -> ScheduleEntry {
        let defaults = UserDefaults(suiteName: appGroupID)
        guard
            let jwt    = defaults?.string(forKey: "supabase_jwt"), !jwt.isEmpty,
            let userId = defaults?.string(forKey: "user_id"),      !userId.isEmpty,
            let shopId = defaults?.string(forKey: "shop_id"),      !shopId.isEmpty
        else {
            return ScheduleEntry(date: Date(), weekData: nil, isLoggedIn: false)
        }
        do {
            let data = try await SupabaseFetcher.fetchWeekData(jwt: jwt, userId: userId, shopId: shopId)
            return ScheduleEntry(date: Date(), weekData: data, isLoggedIn: true)
        } catch {
            return ScheduleEntry(date: Date(), weekData: nil, isLoggedIn: true)
        }
    }
}

// MARK: - Supabase Fetcher
struct SupabaseFetcher {

    static func fetchWeekData(jwt: String, userId: String, shopId: String) async throws -> WeekData {
        let now    = Date()
        let wStart = weekStartDate(for: now)
        let wEnd   = Calendar.current.date(byAdding: .day, value: 6, to: wStart)!

        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let startStr = fmt.string(from: wStart)
        let endStr   = fmt.string(from: wEnd)

        async let shiftResult = fetchShifts(jwt: jwt, userId: userId, shopId: shopId,
                                            start: startStr, end: endStr, weekStart: wStart)
        async let eventsResult = fetchEvents(jwt: jwt, userId: userId, shopId: shopId,
                                             weekStart: wStart, weekEnd: wEnd)

        let (shiftColors, todayShifts) = try await shiftResult
        let weekEvents = try await eventsResult
        return WeekData(shiftColors: shiftColors, todayShifts: todayShifts, weekEvents: weekEvents)
    }

    // MARK: Shifts
    static func fetchShifts(jwt: String, userId: String, shopId: String,
                            start: String, end: String, weekStart: Date) async throws -> ([Int: Color], [ShiftDefinition]) {
        // Fetch shift definitions
        let settingsURL = URL(string: "\(supabaseURL)/rest/v1/shop_shift_settings?select=id,shift_name,start_time,end_time,color&shop_id=eq.\(shopId)")!
        let settingsArr = try await get(url: settingsURL, jwt: jwt, cacheKey: "cache_settings_\(shopId)") as? [[String: Any]] ?? []

        var configMap: [String: (color: Color, name: String, start: String, end: String)] = [:]
        for item in settingsArr {
            guard let id = (item["id"] as? String) ?? (item["id"].map { "\($0)" }) else { continue }
            configMap[id] = (
                color: hexToColor(item["color"] as? String ?? "#808080"),
                name:  item["shift_name"] as? String ?? "Unknown",
                start: String((item["start_time"] as? String ?? "").prefix(5)),
                end:   String((item["end_time"]   as? String ?? "").prefix(5))
            )
        }

        // Fetch assignments
        let assignURL = URL(string: "\(supabaseURL)/rest/v1/schedule_assignments?select=shift_date,shift_type_id&shop_id=eq.\(shopId)&employee_id=eq.\(userId)&shift_date=gte.\(start)&shift_date=lte.\(end)")!
        let assignArr = try await get(url: assignURL, jwt: jwt, cacheKey: "cache_assign_\(userId)") as? [[String: Any]] ?? []

        var resultColors: [Int: Color] = [:]
        for i in 0...6 { resultColors[i] = .clear }

        let dayFmt = DateFormatter(); dayFmt.dateFormat = "yyyy-MM-dd"
        let todayStr = dayFmt.string(from: Date())
        var todayShiftIds: Set<String> = []

        for item in assignArr {
            guard
                let dateStr     = item["shift_date"]    as? String,
                let shiftTypeId = item["shift_type_id"] as? String ?? (item["shift_type_id"].map { "\($0)" }),
                let shiftDate   = dayFmt.date(from: dateStr)
            else { continue }

            let wd = Calendar.current.component(.weekday, from: shiftDate) - 1 // 0=Sun...6=Sat
            if let cfg = configMap[shiftTypeId] { resultColors[wd] = cfg.color }
            if dateStr == todayStr { todayShiftIds.insert(shiftTypeId) }
        }

        var todayShifts: [ShiftDefinition] = todayShiftIds.compactMap { id in
            guard let cfg = configMap[id] else { return nil }
            return ShiftDefinition(name: cfg.name, startTime: cfg.start, endTime: cfg.end, color: cfg.color)
        }
        todayShifts.sort { $0.startTime < $1.startTime }

        return (resultColors, todayShifts)
    }

    // MARK: Calendar Events
    static func fetchEvents(jwt: String, userId: String, shopId: String,
                            weekStart: Date, weekEnd: Date) async throws -> [Int: [VisualEvent?]] {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let endIso = isoFmt.string(from: weekEnd).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let selectFields = "title,start_time,end_time,color,all_day,repeat,recurrence_end_date,recurrence_rule,id,calendar_groups(name,user_id,visible_user_ids)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "\(supabaseURL)/rest/v1/calendar_events?select=\(selectFields)&shop_id=eq.\(shopId)&start_time=lte.\(endIso)"
        guard let url = URL(string: urlStr) else { return [:] }

        let eventsArr = try await get(url: url, jwt: jwt, cacheKey: "cache_events_\(shopId)") as? [[String: Any]] ?? []

        func parseDate(_ s: String) -> Date? {
            let f1 = ISO8601DateFormatter(); f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let f2 = ISO8601DateFormatter(); f2.formatOptions = [.withInternetDateTime]
            return f1.date(from: s) ?? f2.date(from: s)
        }

        let cal = Calendar.current
        var visualEvents: [VisualEvent] = []

        for event in eventsArr {
            guard let group = event["calendar_groups"] as? [String: Any] else { continue }

            let groupName    = group["name"]             as? String   ?? ""
            let groupOwner   = group["user_id"]          as? String   ?? ""
            let groupMembers = group["visible_user_ids"] as? [String] ?? []
            let amIMember    = (groupOwner == userId) || groupMembers.contains(userId)
            let isPersonal   = (groupName == "個人" || groupName == "Personal")

            if isPersonal { if groupOwner != userId { continue } }
            else          { if !amIMember            { continue } }

            guard
                let startStr = event["start_time"] as? String,
                let endStr   = event["end_time"]   as? String,
                let rawStart = parseDate(startStr),
                var rawEnd   = parseDate(endStr)
            else { continue }

            let eventId  = event["id"] as? String ?? UUID().uuidString
            let isAllDay = event["all_day"] as? Bool == true
            let repeat_  = event["repeat"]  as? String ?? "none"

            if isAllDay {
                let dc = cal.dateComponents([.year, .month, .day], from: rawEnd)
                rawEnd = cal.date(from: DateComponents(year: dc.year, month: dc.month, day: dc.day,
                                                       hour: 23, minute: 59, second: 59)) ?? rawEnd
            }

            var rule: RecurrenceRule? = nil
            var isRepeating = false
            if let ruleJson = event["recurrence_rule"] as? [String: Any] {
                rule = RecurrenceRule(json: ruleJson); isRepeating = true
            } else if repeat_ != "none" {
                isRepeating = true
            }

            var duration: TimeInterval
            if !isRepeating {
                duration = rawEnd.timeIntervalSince(rawStart)
            } else {
                var effEnd = cal.date(bySettingHour:   cal.component(.hour,   from: rawEnd),
                                      minute:          cal.component(.minute, from: rawEnd),
                                      second:          cal.component(.second, from: rawEnd),
                                      of: rawStart) ?? rawStart
                if effEnd < rawStart { effEnd = effEnd.addingTimeInterval(86400) }
                duration = min(effEnd.timeIntervalSince(rawStart), 86400)
            }

            let recurrenceEnd: Date? = (event["recurrence_end_date"] as? String).flatMap { parseDate($0) }

            for i in 0...6 {
                let checkDay = cal.date(byAdding: .day, value: i, to: weekStart)!
                let dayStart = cal.startOfDay(for: checkDay)
                let dayEnd   = dayStart.addingTimeInterval(86400 - 0.001)

                var shouldShow   = false
                var displayStart = rawStart
                var displayEnd   = rawEnd

                if !isRepeating {
                    shouldShow = rawStart <= dayEnd && rawEnd >= dayStart
                } else {
                    if let recEnd = recurrenceEnd,
                       cal.startOfDay(for: checkDay) > cal.startOfDay(for: recEnd) { continue }
                    if checkDay < cal.startOfDay(for: rawStart) { continue }

                    var matches = false
                    if let rule { matches = rule.matches(checkDate: checkDay, startDate: rawStart) }
                    else {
                        switch repeat_ {
                        case "daily":   matches = true
                        case "weekly":  matches = cal.component(.weekday, from: rawStart) == cal.component(.weekday, from: checkDay)
                        case "monthly": matches = cal.component(.day,     from: rawStart) == cal.component(.day,     from: checkDay)
                        case "yearly":  matches = cal.component(.month,   from: rawStart) == cal.component(.month,   from: checkDay)
                                                && cal.component(.day,    from: rawStart) == cal.component(.day,     from: checkDay)
                        default: break
                        }
                    }

                    if matches {
                        shouldShow   = true
                        displayStart = cal.date(bySettingHour:  cal.component(.hour,   from: rawStart),
                                                minute:         cal.component(.minute, from: rawStart),
                                                second:         cal.component(.second, from: rawStart),
                                                of: checkDay) ?? checkDay
                        displayEnd   = displayStart.addingTimeInterval(duration)
                    }
                }

                if shouldShow {
                    visualEvents.append(VisualEvent(
                        id: eventId, title: event["title"] as? String ?? "",
                        color: hexToColor(event["color"] as? String ?? "#0A84FF"),
                        dayIndex: i, start: displayStart, end: displayEnd
                    ))
                }
            }
        }

        // Sort: by start asc, then duration desc
        visualEvents.sort { a, b in
            if a.start != b.start { return a.start < b.start }
            return a.end.timeIntervalSince(a.start) > b.end.timeIntervalSince(b.start)
        }

        // Gravity layout (ported from Flutter)
        var resultMap:      [Int: [VisualEvent?]] = [:]
        var occupancy:      [Int: [Bool]]          = [:]
        var eventRowMap:    [String: Int]           = [:]
        var lastSeenDayMap: [String: Int]           = [:]
        for i in 0...6 { resultMap[i] = []; occupancy[i] = [] }

        for vEvent in visualEvents {
            let d = vEvent.dayIndex
            var assignedRow = -1

            if let prevRow = eventRowMap[vEvent.id], lastSeenDayMap[vEvent.id] == d - 1 {
                if isRowFree(occupancy, d, prevRow) { assignedRow = prevRow }
            }
            if assignedRow == -1 {
                var row = 0
                while !isRowFree(occupancy, d, row) { row += 1 }
                assignedRow = row
            }

            occupyRow(&occupancy, d, assignedRow)
            eventRowMap[vEvent.id]    = assignedRow
            lastSeenDayMap[vEvent.id] = d

            while resultMap[d]!.count <= assignedRow { resultMap[d]!.append(nil) }
            resultMap[d]![assignedRow] = vEvent
        }
        return resultMap
    }

    private static func isRowFree(_ occ: [Int: [Bool]], _ day: Int, _ row: Int) -> Bool {
        guard let rows = occ[day], row < rows.count else { return true }
        return !rows[row]
    }
    private static func occupyRow(_ occ: inout [Int: [Bool]], _ day: Int, _ row: Int) {
        while occ[day]!.count <= row { occ[day]!.append(false) }
        occ[day]![row] = true
    }

    // MARK: HTTP helper
    static func get(url: URL, jwt: String, cacheKey: String) async throws -> Any {
        var req = URLRequest(url: url)
        req.setValue(supabaseAnonKey,       forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(jwt)",       forHTTPHeaderField: "Authorization")
        req.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            UserDefaults(suiteName: appGroupID)?.set(data, forKey: cacheKey)
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            if let cachedData = UserDefaults(suiteName: appGroupID)?.data(forKey: cacheKey) {
                return try JSONSerialization.jsonObject(with: cachedData)
            }
            throw error
        }
    }
}

// MARK: - Event Bar Shape (handles connected edges)
struct EventBarShape: Shape {
    let connectsLeft: Bool
    let connectsRight: Bool
    let r: CGFloat = 2

    func path(in rect: CGRect) -> Path {
        let tl = connectsLeft  ? 0 : r
        let tr = connectsRight ? 0 : r
        let bl = connectsLeft  ? 0 : r
        let br = connectsRight ? 0 : r
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 { p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr),   control: CGPoint(x: rect.maxX, y: rect.minY)) }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 { p.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY),   control: CGPoint(x: rect.maxX, y: rect.maxY)) }
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 { p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl),   control: CGPoint(x: rect.minX, y: rect.maxY)) }
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 { p.addQuadCurve(to: CGPoint(x: rect.minX + tl, y: rect.minY),  control: CGPoint(x: rect.minX, y: rect.minY)) }
        p.closeSubpath()
        return p
    }
}

// MARK: - Views
struct ScheduleWidgetEntryView: View {
    var entry: ScheduleEntry
    @Environment(\.colorScheme) var colorScheme

    var isLight: Bool { colorScheme == .light }

    var body: some View {
        Group {
            if !entry.isLoggedIn {
                VStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 24)).foregroundColor(.secondary)
                    Text("請先開啟 App 登入")
                        .font(.caption).foregroundColor(.secondary)
                }
            } else if let data = entry.weekData {
                weekView(data)
            } else {
                VStack(spacing: 6) {
                    ProgressView()
                    Text("載入中...").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
    }

    func weekView(_ data: WeekData) -> some View {
        let now    = Date()
        let wStart = weekStartDate(for: now)
        let monthFmt = DateFormatter(); monthFmt.dateFormat = "MMMM"

        return VStack(alignment: .leading, spacing: 0) {
            // ── Header ──
            HStack(alignment: .center, spacing: 0) {
                Text(monthFmt.string(from: now))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isLight ? .black : Color(hex: "FAFCFA"))

                Spacer()

                if !isLight {
                    ForEach(data.todayShifts.prefix(2), id: \.name) { s in
                        HStack(spacing: 3) {
                            Circle().fill(s.color).frame(width: 5, height: 5)
                            Text("\(s.name) \(s.startTime)-\(s.endTime)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(Color(hex: "FAFCFA"))
                        }
                        .padding(.trailing, 2)
                    }
                }
            }
            .padding(.bottom, 6)

            // ── 7-day columns ──
            HStack(alignment: .top, spacing: 2) {
                ForEach(0..<7, id: \.self) { i in
                    let dayDate   = Calendar.current.date(byAdding: .day, value: i, to: wStart)!
                    let isToday   = Calendar.current.isDateInToday(dayDate)
                    let shiftCol  = data.shiftColors[i] ?? .clear
                    let hasShift  = shiftCol != .clear
                    let slots     = data.weekEvents[i] ?? []

                    DayColumnView(
                        dayDate:    dayDate,
                        isToday:    isToday,
                        shiftColor: shiftCol,
                        hasShift:   hasShift,
                        slots:      slots,
                        allWeekEvents: data.weekEvents,
                        dayIndex:   i,
                        isLight:    isLight
                    )
                    .zIndex(Double(7 - i))
                }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 10, bottom: 12, trailing: 10))
    }
}

struct DayColumnView: View {
    let dayDate:       Date
    let isToday:       Bool
    let shiftColor:    Color
    let hasShift:      Bool
    let slots:         [VisualEvent?]
    let allWeekEvents: [Int: [VisualEvent?]]
    let dayIndex:      Int
    let isLight:       Bool

    private let maxRows = 5

    var weekday: Int { Calendar.current.component(.weekday, from: dayDate) } // 1=Sun, 7=Sat

    var dayLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return String(f.string(from: dayDate).prefix(3)).uppercased()
    }

    var isBgLight: Bool { hasShift && isColorLight(shiftColor) }

    var dateTextColor: Color {
        if hasShift { return isBgLight ? .black : Color(hex: "FAFCFA") }
        if isToday  { return .white }
        if weekday == 7 { return Color(hex: "0044CC") }  // Saturday
        if weekday == 1 { return Color(hex: "CC0000") }  // Sunday
        return isLight ? .black : Color(hex: "FAFCFA")
    }

    var dayLabelColor: Color {
        isLight ? Color.gray.opacity(0.6) : Color(hex: "FAFCFA").opacity(0.7)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day name
            Text(dayLabel)
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(dayLabelColor)
                .frame(maxWidth: .infinity)

            Spacer().frame(height: 2)

            // Date circle
            ZStack {
                Circle()
                    .fill(hasShift ? shiftColor : (isToday ? Color.red : Color.clear))
                    .frame(width: 20, height: 20)
                Text("\(Calendar.current.component(.day, from: dayDate))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(dateTextColor)
            }

            Spacer().frame(height: 3)

            // Event rows
            VStack(spacing: 1) {
                ForEach(0..<min(slots.count, maxRows), id: \.self) { row in
                    eventRow(row: row)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func eventRow(row: Int) -> some View {
        let isLastRow   = row == maxRows - 1
        let hasOverflow = slots.count > maxRows
        let hiddenCount = isLastRow && hasOverflow
            ? slots[row...].compactMap { $0 }.count
            : 0

        if isLastRow && hasOverflow && hiddenCount > 0 {
            Text("+\(hiddenCount)")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, minHeight: 10, maxHeight: 10)
        } else {
            let event = row < slots.count ? slots[row] : nil
            if let event {
                let cLeft    = connectsLeft(event: event,  row: row)
                let cRight   = connectsRight(event: event, row: row)
                let span     = getSpanIfStart(event: event, row: row)
                
                EventBarShape(connectsLeft: cLeft, connectsRight: cRight)
                    .fill(event.color)
                    .frame(maxWidth: .infinity, minHeight: 14, maxHeight: 14)
                    .overlay(
                        GeometryReader { geo in
                            if let span = span {
                                let fullWidth = geo.size.width * CGFloat(span) + CGFloat(span - 1) * 2.0
                                Text(event.title)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 2)
                                    .frame(width: fullWidth, height: geo.size.height, alignment: .center)
                            }
                        }
                    )
                    .padding(.leading,  cLeft  ? -1 : 0)
                    .padding(.trailing, cRight ? -1 : 0)
            } else {
                Color.clear.frame(maxWidth: .infinity, minHeight: 10, maxHeight: 10)
            }
        }
    }

    func getSpanIfStart(event: VisualEvent, row: Int) -> Int? {
        var leftSpan = 0
        if dayIndex > 0 {
            for k in stride(from: dayIndex - 1, through: 0, by: -1) {
                let s = allWeekEvents[k] ?? []
                if row < s.count, let e = s[row], e.id == event.id { leftSpan += 1 } else { break }
            }
        }
        if leftSpan > 0 { return nil }

        var rightSpan = 0
        if dayIndex < 6 {
            for k in (dayIndex + 1)...6 {
                let s = allWeekEvents[k] ?? []
                if row < s.count, let e = s[row], e.id == event.id { rightSpan += 1 } else { break }
            }
        }
        return 1 + rightSpan
    }

    func connectsLeft(event: VisualEvent, row: Int) -> Bool {
        guard dayIndex > 0 else { return false }
        let prevSlots = allWeekEvents[dayIndex - 1] ?? []
        guard row < prevSlots.count, let prev = prevSlots[row] else { return false }
        return prev.id == event.id
    }

    func connectsRight(event: VisualEvent, row: Int) -> Bool {
        guard dayIndex < 6 else { return false }
        let nextSlots = allWeekEvents[dayIndex + 1] ?? []
        guard row < nextSlots.count, let next = nextSlots[row] else { return false }
        return next.id == event.id
    }
}

// MARK: - Widget definition
struct ScheduleWidget: Widget {
    let kind = "ScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(UIColor.systemBackground)
                }
        }
        .configurationDisplayName("週曆")
        .description("顯示本週班表與行事曆")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
