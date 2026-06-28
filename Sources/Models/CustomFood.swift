import Foundation
import SwiftData

/// Свой продукт, добавленный пользователем (категория «Другое»). В отличие от
/// каталожных `Food` (статика из JSON) — хранится в SwiftData. Маппится в `Food`
/// с id-префиксом `custom-`, чтобы остальной флоу (ввод, журнал, история) работал
/// без изменений.
@Model
final class CustomFood {
    var id: String = ""
    var name: String = ""
    var emoji: String = "🍴"
    var minAgeMonths: Int = 6

    init(name: String, emoji: String, minAgeMonths: Int) {
        self.id = "custom-\(UUID().uuidString)"
        self.name = name
        self.emoji = emoji
        self.minAgeMonths = minAgeMonths
    }

    /// Представление в виде каталожного `Food` (категория «Другое», не аллерген).
    var asFood: Food {
        Food(id: id, name: name, category: .other, emoji: emoji,
             isAllergen: false, allergenGroup: nil, minAgeMonths: minAgeMonths)
    }
}
