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
    /// Чем полезен продукт и какие нутриенты содержит (п.12). Опциональны —
    /// заполняются в `foods.json` постепенно; для своих продуктов отсутствуют.
    let benefits: String?
    let nutrients: [String]?

    /// Локализованное имя для показа в UI. Для каталожных продуктов `name` —
    /// это ключ в String Catalog (en-перевод подставится); для своих продуктов
    /// пользователя ключ не найдётся и вернётся исходное имя как есть.
    var localizedName: String {
        String(localized: String.LocalizationValue(name))
    }

    /// Локализованное описание пользы (RU-текст из JSON — ключ String Catalog).
    var localizedBenefits: String? {
        benefits.map { String(localized: String.LocalizationValue($0)) }
    }

    init(id: String, name: String, category: FoodCategory, emoji: String,
         isAllergen: Bool, allergenGroup: AllergenGroup?, minAgeMonths: Int,
         benefits: String? = nil, nutrients: [String]? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.emoji = emoji
        self.isAllergen = isAllergen
        self.allergenGroup = allergenGroup
        self.minAgeMonths = minAgeMonths
        self.benefits = benefits
        self.nutrients = nutrients
    }
}
