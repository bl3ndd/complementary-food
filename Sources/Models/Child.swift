import Foundation
import SwiftData

/// Профиль ребёнка. В MVP один, но вынесен в отдельную сущность,
/// чтобы v2 с несколькими детьми не требовал миграции (SPEC §3).
/// Свойства с дефолтами — для совместимости с CloudKit (SPEC §8).
@Model
final class Child {
    var id: UUID = UUID()
    var name: String = ""
    var birthDate: Date = Date()
    /// id методики. Метод всегда «свой план», поле оставлено ради CloudKit-совместимости.
    var feedingProfileId: String = FeedingProfile.customId

    // MARK: - Параметры «своего плана» (custom). CloudKit-safe дефолты.
    var customStartAgeMonths: Int = 6
    /// Окно наблюдения для обычного продукта и для аллергена — раздельно (п.10).
    var customObservationDaysRegular: Int = 3
    var customObservationDaysAllergen: Int = 5
    var customAllergenFrequencyPerWeek: Int = 2
    /// Список групп аллергенов строкой rawValue через запятую (примитив — для CloudKit).
    var customAllergenGroupsRaw: String = "egg,peanut,dairy,gluten,fish,shellfish,soy,treenut,sesame"

    init(name: String = "", birthDate: Date = Date(), feedingProfileId: String = FeedingProfile.customId) {
        self.name = name
        self.birthDate = birthDate
        self.feedingProfileId = feedingProfileId
    }

    /// Группы аллергенов «своего плана» (парс/запись raw-строки).
    var customAllergenGroups: [AllergenGroup] {
        get { customAllergenGroupsRaw.split(separator: ",")
                .compactMap { AllergenGroup(rawValue: String($0)) } }
        set { customAllergenGroupsRaw = newValue.map(\.rawValue).joined(separator: ",") }
    }

    /// Приводит custom-параметры в допустимые границы (защита от мусора в сторе).
    func clampCustom() {
        customStartAgeMonths = customStartAgeMonths.clamped(to: FeedingProfile.CustomLimits.startAge)
        customObservationDaysRegular = customObservationDaysRegular.clamped(to: FeedingProfile.CustomLimits.observation)
        customObservationDaysAllergen = customObservationDaysAllergen.clamped(to: FeedingProfile.CustomLimits.observation)
        customAllergenFrequencyPerWeek = customAllergenFrequencyPerWeek.clamped(to: FeedingProfile.CustomLimits.frequency)
    }

    /// Возраст в полных месяцах.
    var ageInMonths: Int {
        ageInMonths(now: Date())
    }

    /// Возраст в полных месяцах на заданную дату (для детерминированных тестов).
    func ageInMonths(now: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.month], from: birthDate, to: now).month ?? 0
    }

    /// Методика всегда собирается из custom-полей (пресеты убраны, п.11).
    var feedingProfile: FeedingProfile {
        FeedingProfile.custom(from: self)
    }
}

extension Comparable {
    /// Зажимает значение в границах диапазона.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
