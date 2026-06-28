import Foundation

/// Элемент каталога продуктов. Загружается из `foods.json` (статика бандла),
/// в SwiftData/CloudKit НЕ синхронизируется (SPEC §8).
struct Food: Codable, Identifiable, Hashable {
    let id: String
    /// Каноническое (русское) имя из `foods.json` — ключ локализации и основа поиска.
    let name: String
    let category: FoodCategory
    let emoji: String
    let isAllergen: Bool
    let allergenGroup: AllergenGroup?
    let minAgeMonths: Int

    /// Локализованное имя для показа в UI. Для каталожных продуктов `name` —
    /// это ключ в String Catalog (en-перевод подставится); для своих продуктов
    /// пользователя ключ не найдётся и вернётся исходное имя как есть.
    var localizedName: String {
        String(localized: String.LocalizationValue(name))
    }
}
