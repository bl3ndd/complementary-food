import Foundation

/// Загрузчик каталога продуктов из `foods.json` в бандле (офлайн-first, SPEC §8).
struct FoodCatalog {
    let foods: [Food]

    static let shared = FoodCatalog.load()

    /// Свои продукты пользователя (из SwiftData), подмешиваются ко всем выборкам.
    /// Обновляется из `CustomFood` при запуске и изменениях каталога.
    nonisolated(unsafe) static var custom: [Food] = []

    static func setCustom(_ foods: [CustomFood]) {
        custom = foods.map(\.asFood)
    }

    /// Каталожные + свои продукты вместе.
    private var combined: [Food] { foods + FoodCatalog.custom }

    private struct Wrapper: Codable {
        let foods: [Food]
    }

    static func load(bundle: Bundle = .main) -> FoodCatalog {
        guard let url = bundle.url(forResource: "foods", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("foods.json не найден в бандле")
            return FoodCatalog(foods: [])
        }
        do {
            return try decode(data)
        } catch {
            assertionFailure("Не удалось распарсить foods.json: \(error)")
            return FoodCatalog(foods: [])
        }
    }

    /// Чистый разбор данных каталога — удобно для юнит-тестов.
    static func decode(_ data: Data) throws -> FoodCatalog {
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
        return FoodCatalog(foods: wrapper.foods)
    }

    /// Все продукты каталога (включая свои).
    var all: [Food] { combined }

    func food(id: String) -> Food? {
        combined.first { $0.id == id }
    }

    func byCategory(_ category: FoodCategory) -> [Food] {
        combined.filter { $0.category == category }
    }

    /// Нечёткий ранжированный поиск (п.1/17): точное вхождение > префикс > подстрока >
    /// fuzzy (опечатки, как в fuse.js — через подпоследовательность и расстояние
    /// Левенштейна). Плюс поиск по группе: «овощи»/«рыба»/«арахис» → вся категория или
    /// группа аллергена. Пустой запрос → весь каталог.
    func search(_ query: String) -> [Food] {
        let q = Self.normalize(query)
        guard !q.isEmpty else { return combined }

        var ranked: [(food: Food, score: Int)] = []
        var seen = Set<String>()

        for food in combined {
            if let s = Self.nameScore(Self.normalize(food.name), q) {
                ranked.append((food, s))
                seen.insert(food.id)
            }
        }

        // Поиск по названию категории/группы аллергена (для запросов от 3 букв).
        if q.count >= 3 {
            for food in combined where !seen.contains(food.id) {
                let catHit = Self.normalize(food.category.title).contains(q)
                let grpHit = food.allergenGroup.map { Self.normalize($0.title).contains(q) } ?? false
                if catHit || grpHit {
                    ranked.append((food, 5))
                    seen.insert(food.id)
                }
            }
        }

        return ranked
            .sorted { $0.score != $1.score ? $0.score < $1.score : $0.food.name < $1.food.name }
            .map(\.food)
    }

    /// Нормализация: без регистра/диакритики (ё≈е), обрезка пробелов.
    static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
         .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    /// Оценка совпадения имени с запросом (меньше — лучше), `nil` — не совпало.
    static func nameScore(_ name: String, _ q: String) -> Int? {
        if name == q { return 0 }
        if name.hasPrefix(q) { return 1 }
        if name.split(separator: " ").contains(where: { String($0).hasPrefix(q) }) { return 2 }
        if name.contains(q) { return 3 }
        if fuzzyMatches(name, q) { return 4 }
        return nil
    }

    /// Fuzzy: подпоследовательность (пропуски букв) или малое расстояние Левенштейна
    /// к слову/префиксу (замены/перестановки букв — опечатки).
    static func fuzzyMatches(_ name: String, _ q: String) -> Bool {
        if isSubsequence(q, of: name) { return true }
        let maxDist = q.count <= 4 ? 1 : 2
        let words = name.split(separator: " ").map(String.init) + [name]
        return words.contains { w in
            levenshtein(q, String(w.prefix(q.count + maxDist))) <= maxDist
                || levenshtein(q, w) <= maxDist
        }
    }

    /// Является ли `q` подпоследовательностью `s` (буквы по порядку, с пропусками).
    static func isSubsequence(_ q: String, of s: String) -> Bool {
        let qc = Array(q)
        var i = 0
        for c in s where i < qc.count && c == qc[i] { i += 1 }
        return i == qc.count
    }

    /// Расстояние Левенштейна (вставки/удаления/замены).
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if x.isEmpty { return y.count }
        if y.isEmpty { return x.count }
        var prev = Array(0...y.count)
        var cur = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            cur[0] = i
            for j in 1...y.count {
                let cost = x[i - 1] == y[j - 1] ? 0 : 1
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            }
            swap(&prev, &cur)
        }
        return prev[y.count]
    }
}
