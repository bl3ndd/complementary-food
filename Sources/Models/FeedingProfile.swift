import Foundation

/// Методика прикорма как конфиг (SPEC §4.1). Весь core читает параметры отсюда,
/// никакого хардкода сроков в логике.
///
/// Цифры пресетов сверены с первоисточниками (см. `docs/legal/methodology-sources.md`,
/// SPEC §13). Где значение — клинический консенсус (LEAP/EAT), а не прямая цифра
/// гайдлайна, это честно оговорено в `caveat` и показывается в UI (App Review 1.4.1).
struct FeedingProfile: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let startAgeMonths: Int
    let observationDays: Int
    let allergenFrequencyPerWeek: Int
    let allergenGroups: [AllergenGroup]
    let isPreset: Bool
    /// Заголовочный источник методики (человекочитаемо).
    let source: String
    /// Ссылка на первоисточник.
    let sourceURL: String
    /// Честная оговорка: что в пресете — буква гайда, а что — консенсус/экстраполяция.
    let caveat: String

    /// Интервал поддержки аллергена в днях, исходя из частоты в неделю.
    var maintenanceIntervalDays: Int {
        max(1, Int((7.0 / Double(allergenFrequencyPerWeek)).rounded()))
    }

    // MARK: - Пресеты (сверены, источники в docs/legal/methodology-sources.md)

    static let who = FeedingProfile(
        id: "who",
        name: "ВОЗ / ESPGHAN",
        startAgeMonths: 6,
        observationDays: 3,
        allergenFrequencyPerWeek: 2,
        allergenGroups: [.egg, .peanut, .dairy, .gluten, .fish, .soy, .treenut, .sesame],
        isPreset: true,
        source: "ВОЗ 2023 + ESPGHAN 2017 (JPGN)",
        sourceURL: "https://www.who.int/publications/i/item/9789240081864",
        caveat: "Старт по ВОЗ — 6 мес (ESPGHAN допускает с 4, окно 4–6). «3 дня наблюдения» — общий консенсус (вводить по одному продукту и следить за реакцией), а не прямая цифра ВОЗ/ESPGHAN. Частота поддержки аллергена — клинический консенсус из исследований LEAP/EAT, не буква гайдлайна."
    )

    static let aap = FeedingProfile(
        id: "aap",
        name: "AAP / NIAID (США)",
        startAgeMonths: 6,
        observationDays: 3,
        allergenFrequencyPerWeek: 3,
        allergenGroups: [.peanut, .egg, .dairy, .gluten, .fish, .shellfish, .soy, .treenut, .sesame],
        isPreset: true,
        source: "AAP (HealthyChildren) + NIAID 2017",
        sourceURL: "https://www.healthychildren.org/English/ages-stages/baby/feeding-nutrition/Pages/Starting-Solid-Foods.aspx",
        caveat: "Старт ~6 мес («around 6 months»). «3 дня» — низ официального диапазона AAP «3–5 дней». Список аллергенов = FDA «Big 9» (вкл. кунжут, FASTER Act). Частота 3×/нед — это пинат-протокол LEAP/NIAID, распространённый на другие аллергены как консенсус, а не отдельная цифра гайдлайна."
    )

    static let russia = FeedingProfile(
        id: "russia",
        name: "Союз педиатров РФ",
        startAgeMonths: 5,
        observationDays: 7,
        allergenFrequencyPerWeek: 1,
        allergenGroups: [.egg, .dairy, .gluten, .fish],
        isPreset: true,
        source: "Нац. программа оптимизации вскармливания детей 1-го года жизни в РФ",
        sourceURL: "https://zdravdeti.org/wp-content/uploads/2022/11/prog-vskarm.pdf",
        caveat: "Старт 5 мес — дословный оптимум программы для ГВ. Окно 7 дней — верх диапазона «вводить за 5–7 дней». Важно: регулярной «поддержки аллергена для толерантности» в программе РФ нет (она прямо считает раннее введение аллергенов требующим дальнейших исследований) — параметр оставлен как осторожный ориентир по западному консенсусу."
    )

    static let presets: [FeedingProfile] = [who, aap, russia]

    static func preset(id: String) -> FeedingProfile {
        presets.first { $0.id == id } ?? who
    }

    // MARK: - Свой план (custom)

    /// id «своего плана» — параметры берутся из custom-полей `Child`, не из пресетов.
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
            name: "Свой план",
            startAgeMonths: child.customStartAgeMonths,
            observationDays: child.customObservationDays,
            allergenFrequencyPerWeek: max(1, child.customAllergenFrequencyPerWeek),
            allergenGroups: child.customAllergenGroups,
            isPreset: false,
            source: "Свой план — настроен вами",
            sourceURL: "https://pudding-for-children.vercel.app/#method",
            caveat: "Это ваши собственные настройки, а не клиническая рекомендация. Сроки введения продуктов и аллергенов согласуйте с педиатром."
        )
    }
}
