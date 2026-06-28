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

    /// Поиск по названию (без учёта регистра/диакритики, напр. ё≈е); пустой
    /// запрос → весь каталог.
    func search(_ query: String) -> [Food] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return combined }
        return combined.filter {
            $0.name.range(of: trimmed,
                          options: [.caseInsensitive, .diacriticInsensitive],
                          locale: .current) != nil
        }
    }
}
