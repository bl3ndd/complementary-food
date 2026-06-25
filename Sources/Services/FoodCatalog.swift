import Foundation

/// Загрузчик каталога продуктов из `foods.json` в бандле (офлайн-first, SPEC §8).
struct FoodCatalog {
    let foods: [Food]

    static let shared = FoodCatalog.load()

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

    /// Все продукты каталога.
    var all: [Food] { foods }

    func food(id: String) -> Food? {
        foods.first { $0.id == id }
    }

    var allergens: [Food] {
        foods.filter { $0.isAllergen }
    }

    func byCategory(_ category: FoodCategory) -> [Food] {
        foods.filter { $0.category == category }
    }

    /// Поиск по названию (без учёта регистра/диакритики); пустой запрос → весь каталог.
    func search(_ query: String) -> [Food] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return foods }
        return foods.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
