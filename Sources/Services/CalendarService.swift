import Foundation

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
}

/// Сводка по одному календарному дню: что давали (ввод/поддержка), с реакциями.
struct DaySummary: Identifiable {
    let date: Date           // начало дня (00:00 в текущем календаре)
    let entries: [DayEntry]  // отсортированы по времени, ранние сверху

    var id: Date { date }
    var hasActivity: Bool { !entries.isEmpty }
    var introCount: Int { entries.filter { $0.type == .intro }.count }
    var maintenanceCount: Int { entries.filter { $0.type == .maintenance }.count }
    var hasReaction: Bool { entries.contains { ($0.reaction ?? .none) != .none } }
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
}
