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
    /// Эмодзи-символ выбранной иконки (рендерится OpenMoji-картинкой по нему).
    var emoji: String = "🍎"
    var minAgeMonths: Int = 6
    var isAllergen: Bool = false

    init(name: String, emoji: String, minAgeMonths: Int, isAllergen: Bool = false) {
        self.id = "custom-\(UUID().uuidString)"
        self.name = name
        self.emoji = emoji
        self.minAgeMonths = minAgeMonths
        self.isAllergen = isAllergen
    }

    /// Представление в виде каталожного `Food` (категория «Другое»).
    var asFood: Food {
        Food(id: id, name: name, category: .other, emoji: emoji,
             isAllergen: isAllergen, allergenGroup: isAllergen ? .other : nil,
             minAgeMonths: minAgeMonths)
    }
}

/// Подборка OpenMoji-иконок для выбора при добавлении своего продукта.
/// `emoji` — хранимый символ, `code` — кодпоинт (ассет `pick_<code>`).
enum CustomFoodIcons {
    static let options: [(emoji: String, code: String)] = [
        ("🍎","1F34E"),("🍐","1F350"),("🍊","1F34A"),("🍌","1F34C"),("🍉","1F349"),
        ("🍇","1F347"),("🍓","1F353"),("🫐","1FAD0"),("🍒","1F352"),("🍑","1F351"),
        ("🥭","1F96D"),("🍍","1F34D"),("🥝","1F95D"),("🍅","1F345"),("🍆","1F346"),
        ("🥑","1F951"),("🥦","1F966"),("🥬","1F96C"),("🥒","1F952"),("🌽","1F33D"),
        ("🥕","1F955"),("🧅","1F9C5"),("🥔","1F954"),("🍠","1F360"),("🍞","1F35E"),
        ("🧀","1F9C0"),("🥚","1F95A"),("🍗","1F357"),("🥩","1F969"),("🐟","1F41F"),
        ("🍚","1F35A"),("🍝","1F35D"),("🥣","1F963"),("🍲","1F372"),("🥗","1F957"),
        ("🍮","1F36E"),("🍪","1F36A"),("🧃","1F9C3"),("🥛","1F95B"),("🍯","1F36F"),
    ]

    /// Имя ассета OpenMoji для эмодзи (если есть в подборке).
    static func asset(for emoji: String) -> String? {
        options.first { $0.emoji == emoji }.map { "pick_\($0.code)" }
    }
}
