import Foundation

/// Итоги месяца для шэр-карточки «Рекап» (bucket 3). Только факты из журнала —
/// сколько нового попробовали, что зашло. Чистый сервис, тестируется без UI.
struct MonthRecap {
    let month: Date            // начало месяца
    let childName: String
    let ageMonths: Int
    let triedFoods: [Food]     // попробованные в этом месяце (для сетки иконок)
    let newCount: Int          // из них впервые в жизни — в этом месяце
    let totalLogs: Int         // всего записей за месяц
    let favorite: Food?        // чаще всего «понравилось»

    var isEmpty: Bool { totalLogs == 0 }
}

struct RecapService {
    let catalog: FoodCatalog
    let logs: [FoodLog]
    var calendar: Calendar = .current

    /// Есть ли фактические записи в этом месяце (для доступности кнопки рекапа).
    func hasData(for month: Date) -> Bool {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return false }
        return logs.contains { !$0.planned && interval.contains($0.date) }
    }

    func recap(for month: Date, childName: String, ageMonths: Int) -> MonthRecap {
        let interval = calendar.dateInterval(of: .month, for: month)
        let start = interval?.start ?? calendar.startOfDay(for: month)
        let monthLogs = logs.filter { !$0.planned && (interval?.contains($0.date) ?? false) }

        // Попробованные в этом месяце — уникальные, в порядке первого приёма.
        let triedIds = orderedUnique(monthLogs.sorted { $0.date < $1.date }.map(\.foodId))
        let triedFoods = triedIds.compactMap { catalog.food(id: $0) }

        // «Новые» — чей самый ранний лог во всём журнале попал в этот месяц.
        let earliestByFood = Dictionary(grouping: logs.filter { !$0.planned }, by: \.foodId)
            .compactMapValues { $0.map(\.date).min() }
        let newCount = triedIds.filter { id in
            guard let earliest = earliestByFood[id] else { return false }
            return interval?.contains(earliest) ?? false
        }.count

        // Любимое — чаще всего «понравилось» за месяц.
        let likedIds = monthLogs.filter { $0.liking == .liked }.map(\.foodId)
        let favorite = mostFrequent(likedIds).flatMap { catalog.food(id: $0) }

        return MonthRecap(month: start, childName: childName, ageMonths: ageMonths,
                          triedFoods: triedFoods, newCount: newCount,
                          totalLogs: monthLogs.count, favorite: favorite)
    }

    private func orderedUnique(_ ids: [String]) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for id in ids where !seen.contains(id) { seen.insert(id); out.append(id) }
        return out
    }

    private func mostFrequent(_ ids: [String]) -> String? {
        guard !ids.isEmpty else { return nil }
        var counts: [String: Int] = [:], firstIndex: [String: Int] = [:]
        for (i, id) in ids.enumerated() {
            counts[id, default: 0] += 1
            if firstIndex[id] == nil { firstIndex[id] = i }
        }
        // Больше «понравилось» — победитель; при ничьей детерминированно берём того,
        // кто встретился раньше (иначе исход зависел от порядка словаря).
        return counts.max {
            $0.value != $1.value ? $0.value < $1.value
                                 : firstIndex[$0.key]! > firstIndex[$1.key]!
        }?.key
    }
}
