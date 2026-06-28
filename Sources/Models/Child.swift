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
    /// id выбранной методики (FeedingProfile.preset или FeedingProfile.customId).
    var feedingProfileId: String = FeedingProfile.who.id

    // MARK: - Параметры «своего плана» (custom). Дефолты — от ВОЗ; CloudKit-safe.
    var customStartAgeMonths: Int = 6
    var customObservationDays: Int = 3
    var customAllergenFrequencyPerWeek: Int = 2
    /// Список групп аллергенов строкой rawValue через запятую (примитив — для CloudKit).
    var customAllergenGroupsRaw: String = "egg,peanut,dairy,gluten,fish,soy,treenut,sesame"

    init(name: String = "", birthDate: Date = Date(), feedingProfileId: String = FeedingProfile.who.id) {
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
        customObservationDays = customObservationDays.clamped(to: FeedingProfile.CustomLimits.observation)
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

    var feedingProfile: FeedingProfile {
        feedingProfileId == FeedingProfile.customId
            ? FeedingProfile.custom(from: self)
            : FeedingProfile.preset(id: feedingProfileId)
    }
}

extension Comparable {
    /// Зажимает значение в границах диапазона.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
