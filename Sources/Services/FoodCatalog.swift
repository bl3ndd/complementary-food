import Foundation

/// Загрузчик каталога продуктов из `foods.json` в бандле (офлайн-first, SPEC §8).
struct FoodCatalog {
    let foods: [Food]

    static let shared = FoodCatalog.load()

    private struct Wrapper: Codable {
        let foods: [Food]
    }

    static func load() -> FoodCatalog {
        guard let url = Bundle.main.url(forResource: "foods", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("foods.json не найден в бандле")
            return FoodCatalog(foods: [])
        }
        do {
            let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
            return FoodCatalog(foods: wrapper.foods)
        } catch {
            assertionFailure("Не удалось распарсить foods.json: \(error)")
            return FoodCatalog(foods: [])
        }
    }

    func food(id: String) -> Food? {
        foods.first { $0.id == id }
    }

    var allergens: [Food] {
        foods.filter { $0.isAllergen }
    }

    func byCategory(_ category: FoodCategory) -> [Food] {
        foods.filter { $0.category == category }
    }
}
