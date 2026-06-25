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
    /// id выбранной методики (FeedingProfile.preset). Custom-параметры — Pro.
    var feedingProfileId: String = FeedingProfile.who.id

    init(name: String = "", birthDate: Date = Date(), feedingProfileId: String = FeedingProfile.who.id) {
        self.name = name
        self.birthDate = birthDate
        self.feedingProfileId = feedingProfileId
    }

    /// Возраст в полных месяцах.
    var ageInMonths: Int {
        Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0
    }

    var feedingProfile: FeedingProfile {
        FeedingProfile.preset(id: feedingProfileId)
    }
}
