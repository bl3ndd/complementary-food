import Foundation

/// Методика прикорма как конфиг (SPEC §4.1). Весь core читает параметры отсюда.
/// В приложении методика одна — «свой план», собираемый из custom-полей `Child`
/// (готовые пресеты убраны, п.11). Окно наблюдения раздельное: обычный продукт и
/// аллерген (п.10).
struct FeedingProfile: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let startAgeMonths: Int
    /// Окно наблюдения для обычного продукта (дни).
    let observationDaysRegular: Int
    /// Окно наблюдения для аллергена (дни) — обычно длиннее.
    let observationDaysAllergen: Int
    let allergenFrequencyPerWeek: Int
    let allergenGroups: [AllergenGroup]

    /// Интервал поддержки аллергена в днях, исходя из частоты в неделю.
    var maintenanceIntervalDays: Int {
        // max(1, …) в знаменателе: при частоте 0 иначе 7/0 = +Inf → Int(Inf) трап.
        max(1, Int((7.0 / Double(max(1, allergenFrequencyPerWeek))).rounded()))
    }

    /// Окно наблюдения для конкретного продукта: аллергену — длиннее (п.10).
    func observationDays(for food: Food) -> Int {
        food.isAllergen ? observationDaysAllergen : observationDaysRegular
    }

    // MARK: - Свой план (custom)

    /// id «своего плана» — параметры берутся из custom-полей `Child`.
    static let customId = "custom"

    /// Разумные границы для редактора своего плана.
    enum CustomLimits {
        static let startAge = 4...8
        static let observation = 1...14
        static let frequency = 1...7
    }

    /// Собирает методику из пользовательских настроек ребёнка.
    static func custom(from child: Child) -> FeedingProfile {
        FeedingProfile(
            id: customId,
            name: String(localized: "Свой план"),
            startAgeMonths: child.customStartAgeMonths,
            observationDaysRegular: child.customObservationDaysRegular,
            observationDaysAllergen: child.customObservationDaysAllergen,
            allergenFrequencyPerWeek: max(1, child.customAllergenFrequencyPerWeek),
            allergenGroups: child.customAllergenGroups)
    }
}
