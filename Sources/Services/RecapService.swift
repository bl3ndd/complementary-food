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

/// Постер коллекции: всё, что попробовали, в порядке знакомства.
struct CollectionPoster: Equatable {
    let foods: [Food]
    let count: Int

    var isEmpty: Bool { foods.isEmpty }
}

/// Достигнутая веха коллекции.
struct Milestone: Equatable {
    /// Планки, на которых есть смысл поздравлять.
    static let steps = [10, 25, 50, 100]

    let reached: Int
    let total: Int
}

/// Первое знакомство с продуктом — самая шэрибельная карточка.
struct FirstTime {
    let food: Food
    let date: Date
    let liking: Liking?
    /// Сама запись — из неё вьюха берёт фото и заметку.
    let log: FoodLog
}

/// Что зашло, а что нет.
struct TastesTop: Equatable {
    let liked: [Food]
    let disliked: [Food]

    var isEmpty: Bool { liked.isEmpty && disliked.isEmpty }
}

/// Карта месяца: в какие дни появлялся новый продукт.
struct TasteCalendar: Equatable {
    let month: Date
    /// Числа месяца (1...31), по возрастанию.
    let days: [Int]
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

    // MARK: - Карточки карусели (Pro)

    /// Постер коллекции: всё, что малыш попробовал, в порядке первого приёма.
    ///
    /// Что считать «введённым», решает вызывающий и передаёт `introducedFoodIds` —
    /// сервис не тянет `IntroductionStatus`, чтобы остаться чистым и совпадать с
    /// цифрой, которую показывает дашборд.
    func collectionPoster(introducedFoodIds: [String]) -> CollectionPoster {
        let firstSeen = firstDateByFood()
        let foods = introducedFoodIds
            .compactMap { catalog.food(id: $0) }
            .sorted { (firstSeen[$0.id] ?? .distantFuture) < (firstSeen[$1.id] ?? .distantFuture) }
        return CollectionPoster(foods: foods, count: foods.count)
    }

    /// Последняя достигнутая веха. Ниже первой планки — `nil`, хвастаться нечем.
    func milestone(introducedCount: Int) -> Milestone? {
        guard let step = Milestone.steps.last(where: { $0 <= introducedCount }) else { return nil }
        return Milestone(reached: step, total: introducedCount)
    }

    /// Самое свежее «первый раз»: продукт, который попробовали впервые позже всех
    /// остальных. Это и есть повод, ради которого карточку выкладывают.
    func latestFirstTime() -> FirstTime? {
        let real = logs.filter { !$0.planned }
        var earliest: [String: FoodLog] = [:]
        for log in real {
            if let known = earliest[log.foodId], known.date <= log.date { continue }
            earliest[log.foodId] = log
        }
        guard let log = earliest.values.max(by: { lhs, rhs in
            // При совпадении дат берём по id — иначе исход зависел бы от порядка словаря.
            lhs.date != rhs.date ? lhs.date < rhs.date : lhs.foodId > rhs.foodId
        }), let food = catalog.food(id: log.foodId) else { return nil }
        return FirstTime(food: food, date: log.date, liking: log.liking, log: log)
    }

    /// Топ понравившегося и непонравившегося по оценкам во всём журнале.
    func tastesTop(limit: Int = 5) -> TastesTop {
        let real = logs.filter { !$0.planned }
        return TastesTop(liked: rank(real.filter { $0.liking == .liked }, limit: limit),
                         disliked: rank(real.filter { $0.liking == .disliked }, limit: limit))
    }

    /// Дни месяца, в которые появился НОВЫЙ продукт — карта вкусов.
    func tasteCalendar(for month: Date) -> TasteCalendar {
        guard let interval = calendar.dateInterval(of: .month, for: month) else {
            return TasteCalendar(month: month, days: [])
        }
        let firstSeen = firstDateByFood()
        let days = Set(firstSeen.values
            .filter { interval.contains($0) }
            .map { calendar.component(.day, from: $0) })
        return TasteCalendar(month: interval.start, days: days.sorted())
    }

    // MARK: - Общее

    /// Дата первого фактического приёма по каждому продукту.
    private func firstDateByFood() -> [String: Date] {
        Dictionary(grouping: logs.filter { !$0.planned }, by: \.foodId)
            .compactMapValues { $0.map(\.date).min() }
    }

    /// Продукты по числу оценок. Ничья разводится по дате первой записи —
    /// без этого порядок менялся бы между запусками вместе с порядком словаря.
    private func rank(_ logs: [FoodLog], limit: Int) -> [Food] {
        var counts: [String: Int] = [:]
        var firstDate: [String: Date] = [:]
        for log in logs {
            counts[log.foodId, default: 0] += 1
            if let known = firstDate[log.foodId] {
                firstDate[log.foodId] = min(known, log.date)
            } else {
                firstDate[log.foodId] = log.date
            }
        }
        return counts.keys
            .sorted { lhs, rhs in
                let (cl, cr) = (counts[lhs] ?? 0, counts[rhs] ?? 0)
                if cl != cr { return cl > cr }
                let (dl, dr) = (firstDate[lhs] ?? .distantFuture, firstDate[rhs] ?? .distantFuture)
                return dl != dr ? dl < dr : lhs < rhs
            }
            .prefix(limit)
            .compactMap { catalog.food(id: $0) }
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
