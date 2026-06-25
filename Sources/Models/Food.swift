import Foundation

/// Элемент каталога продуктов. Загружается из `foods.json` (статика бандла),
/// в SwiftData/CloudKit НЕ синхронизируется (SPEC §8).
struct Food: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: FoodCategory
    let emoji: String
    let isAllergen: Bool
    let allergenGroup: AllergenGroup?
    let minAgeMonths: Int
}
