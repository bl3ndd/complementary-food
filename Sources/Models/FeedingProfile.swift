import Foundation

/// Методика прикорма как конфиг (SPEC §4.1). Весь core читает параметры отсюда,
/// никакого хардкода сроков в логике.
///
/// ⚠️ UNVERIFIED: цифры пресетов — черновик (SPEC §13). Перед релизом
/// верифицировать по официальным источникам.
struct FeedingProfile: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let startAgeMonths: Int
    let observationDays: Int
    let allergenFrequencyPerWeek: Int
    let allergenGroups: [AllergenGroup]
    let isPreset: Bool

    /// Интервал поддержки аллергена в днях, исходя из частоты в неделю.
    var maintenanceIntervalDays: Int {
        max(1, Int((7.0 / Double(allergenFrequencyPerWeek)).rounded()))
    }

    // MARK: - Пресеты (⚠️ UNVERIFIED)

    static let who = FeedingProfile(
        id: "who",
        name: "ВОЗ / ESPGHAN",
        startAgeMonths: 6,
        observationDays: 3,
        allergenFrequencyPerWeek: 2,
        allergenGroups: [.egg, .peanut, .dairy, .gluten, .fish, .soy, .treenut, .sesame],
        isPreset: true
    )

    static let aap = FeedingProfile(
        id: "aap",
        name: "AAP / NIAID (США)",
        startAgeMonths: 6,
        observationDays: 3,
        allergenFrequencyPerWeek: 3,
        allergenGroups: [.peanut, .egg, .dairy, .gluten, .fish, .shellfish, .soy, .treenut, .sesame],
        isPreset: true
    )

    static let russia = FeedingProfile(
        id: "russia",
        name: "Союз педиатров РФ",
        startAgeMonths: 5,
        observationDays: 7,
        allergenFrequencyPerWeek: 1,
        allergenGroups: [.egg, .dairy, .gluten, .fish],
        isPreset: true
    )

    static let presets: [FeedingProfile] = [who, aap, russia]

    static func preset(id: String) -> FeedingProfile {
        presets.first { $0.id == id } ?? who
    }
}
