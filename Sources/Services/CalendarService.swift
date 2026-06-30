import Foundation

/// Фильтр-линза над журналом для экрана-ленты (SPEC §7): всё / ввод / поддержка /
/// реакции / планы. «Реакции» — это и есть журнал «покажи педиатру», только факты.
enum DiaryFilter: String, CaseIterable, Identifiable {
    case all, intro, maintenance, reaction, planned

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:         return String(localized: "Всё")
        case .intro:       return String(localized: "Ввод")
        case .maintenance: return String(localized: "maintenance.type", defaultValue: "Поддержка")
        case .reaction:    return String(localized: "Реакции")
        case .planned:     return String(localized: "Планы")
        }
    }
}

/// Одна запись журнала в дне, связанная с продуктом из каталога (SPEC §7).
struct DayEntry: Identifiable {
    let log: FoodLog
    let food: Food?

    /// Стабильный id на экземпляр лога — не требует вставки в контекст.
    var id: ObjectIdentifier { ObjectIdentifier(log) }

    var foodName: String { food?.name ?? log.foodId }
    var type: LogType { log.type }
    var reaction: ReactionType? { log.reaction }
    var liking: Liking? { log.liking }
    var date: Date { log.date }
    var planned: Bool { log.planned }
}

/// Сводка по одному календарному дню: что давали (ввод/поддержка), с реакциями.
struct DaySummary: Identifiable {
    let date: Date           // начало дня (00:00 в текущем календаре)
    let entries: [DayEntry]  // отсортированы по времени, ранние сверху

    var id: Date { date }
    var hasActivity: Bool { !entries.isEmpty }
    var introCount: Int { entries.filter { $0.type == .intro }.count }
    var maintenanceCount: Int { entries.filter { $0.type == .maintenance }.count }
    var hasReaction: Bool { entries.contains { !$0.planned && ($0.reaction ?? .none) != .none } }
    /// Есть ли запланированные на будущее вводы (п.21).
    var hasPlanned: Bool { entries.contains { $0.planned } }
    /// День состоит только из планов (фактических записей нет).
    var isPlannedOnly: Bool { !entries.isEmpty && entries.allSatisfy { $0.planned } }
}

/// Группирует записи журнала по календарным дням для экрана-таймлайна (SPEC §7).
/// Чистый сервис над данными каталога и логами — тестируется без UI.
struct CalendarService {
    let catalog: FoodCatalog
    let logs: [FoodLog]
    /// Календарь инъектируется ради корректности границ дня/таймзоны в тестах.
    var calendar: Calendar = .current

    private func entry(for log: FoodLog) -> DayEntry {
        DayEntry(log: log, food: catalog.food(id: log.foodId))
    }

    /// Все дни с активностью, новые сверху; записи внутри дня — ранние сверху.
    func days() -> [DaySummary] {
        let grouped = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { day, logs in
                DaySummary(date: day,
                           entries: logs.sorted { $0.date < $1.date }.map(entry))
            }
            .sorted { $0.date > $1.date }
    }

    /// Сводка за конкретный день (пустой `DaySummary`, если активности не было).
    func day(_ date: Date) -> DaySummary {
        let start = calendar.startOfDay(for: date)
        let entries = logs
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
            .map(entry)
        return DaySummary(date: start, entries: entries)
    }

    /// Множество дней (начало дня) с любой активностью — для подсветки в сетке.
    func activeDays() -> Set<Date> {
        Set(logs.map { calendar.startOfDay(for: $0.date) })
    }

    // MARK: - Лента-дневник (Concept A)

    /// Лента-дневник: дни новые сверху, записи внутри дня — ранние сверху, с
    /// фильтром-линзой и текстовым поиском. Пустые после фильтра дни отбрасываются.
    /// `query` ищет по имени продукта (каноническому и локализованному) и заметке.
    func feed(filter: DiaryFilter = .all, query: String = "") -> [DaySummary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matched = logs.filter { matches($0, filter: filter, query: q) }
        return Dictionary(grouping: matched) { calendar.startOfDay(for: $0.date) }
            .map { day, logs in
                DaySummary(date: day,
                           entries: logs.sorted { $0.date < $1.date }.map(entry))
            }
            .sorted { $0.date > $1.date }
    }

    /// Все реакции одной хронологической лентой (журнал «для педиатра»), новые
    /// сверху. Только факты: запись с реакцией, не план. Статус не выводим.
    func reactions(query: String = "") -> [DayEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return logs
            .filter { matches($0, filter: .reaction, query: q) }
            .sorted { $0.date > $1.date }
            .map(entry)
    }

    private func matches(_ log: FoodLog, filter: DiaryFilter, query q: String) -> Bool {
        guard passesFilter(log, filter) else { return false }
        guard !q.isEmpty else { return true }
        if let note = log.note?.lowercased(), note.contains(q) { return true }
        if let food = catalog.food(id: log.foodId),
           food.name.lowercased().contains(q) || food.localizedName.lowercased().contains(q) {
            return true
        }
        return log.foodId.lowercased().contains(q)
    }

    private func passesFilter(_ log: FoodLog, _ filter: DiaryFilter) -> Bool {
        switch filter {
        case .all:         return true
        case .intro:       return !log.planned && log.type == .intro
        case .maintenance: return !log.planned && log.type == .maintenance
        case .reaction:    return !log.planned && (log.reaction ?? .none) != .none
        case .planned:     return log.planned
        }
    }
}
