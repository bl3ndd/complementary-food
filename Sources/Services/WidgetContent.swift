import Foundation

/// Собирает снимок для виджетов из дневника ребёнка. Чистая функция над данными —
/// тестируется без App Group и без WidgetKit.
///
/// «Дальше» — только то, что человек сам запланировал (`FoodLog.planned`).
/// Приложение ничего не советует, и виджет не должен угадывать «что дать следующим».
struct WidgetContent {
    let catalog: FoodCatalog
    let profile: FeedingProfile
    let statuses: [IntroductionStatus]
    /// Хвост журнала: для прогресса ввода и будущих планов весь дневник не нужен.
    let logs: [FoodLog]
    let isPro: Bool
    var now: Date = Date()
    var calendar: Calendar = .current
    /// Отрисовка иконки продукта в PNG. Инъектируется: в тестах — заглушка,
    /// в приложении — `FoodIcon` через ImageRenderer.
    var icon: (Food) -> Data? = { _ in nil }

    func snapshot() -> WidgetSnapshot {
        // Без Pro данные в снимок не кладём вовсе: виджет покажет заглушку, и
        // дневник не утечёт на домашний экран в обход права.
        guard isPro else { return .make(items: [], locked: true, now: now) }

        let collection = statuses
            .filter { $0.state == .introduced }
            .compactMap { catalog.food(id: $0.foodId) }
        // Иконки рисуем только для того, что влезет в сетку: остальное не покажут.
        let shown = Set(collection.suffix(WidgetSnapshot.limit).map(\.id))
        let items = collection.map { item($0, withIcon: shown.contains($0.id)) }

        return .make(items: items, introducing: introducing(), planned: planned(),
                     locked: false, now: now)
    }

    /// Что вводится сейчас — раньше начатое первым, с прогрессом по кормлениям.
    func introducing() -> [WidgetSnapshot.Intro] {
        let active = statuses
            .filter { $0.state == .introducing }
            .sorted { ($0.introStartedAt ?? .distantFuture) < ($1.introStartedAt ?? .distantFuture) }
            .prefix(WidgetSnapshot.introLimit)
        var starts: [String: Date] = [:]
        for s in active { if let start = s.introStartedAt { starts[s.foodId] = start } }
        let done = FeedingService.introFeedingDays(logs: logs, since: starts, calendar: calendar)

        return active.compactMap { s in
            guard let food = catalog.food(id: s.foodId) else { return nil }
            let window = profile.observationDays(for: food)
            return WidgetSnapshot.Intro(item: item(food, withIcon: true),
                                        done: min(done[s.foodId] ?? 0, window), window: window)
        }
    }

    /// Свой план на сегодня и дальше: по дате, один продукт — одна строка.
    func planned() -> [WidgetSnapshot.Planned] {
        let today = calendar.startOfDay(for: now)
        var seen = Set<String>()
        return logs
            .filter { $0.planned && $0.date >= today }
            .sorted { $0.date < $1.date }
            .filter { seen.insert($0.foodId).inserted }
            .prefix(WidgetSnapshot.plannedLimit)
            .compactMap { log in
                catalog.food(id: log.foodId).map {
                    WidgetSnapshot.Planned(item: item($0, withIcon: true), date: log.date)
                }
            }
    }

    private func item(_ food: Food, withIcon: Bool) -> WidgetSnapshot.Item {
        WidgetSnapshot.Item(id: food.id, emoji: food.emoji, name: food.localizedName,
                            icon: withIcon ? icon(food) : nil)
    }
}
