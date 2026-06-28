import Foundation
import SwiftData

/// Запись в журнале: дал продукт (ввод или поддержка), опционально с реакцией.
/// Свойства с дефолтами/опциональные — для CloudKit (SPEC §8).
@Model
final class FoodLog {
    var foodId: String = ""
    var date: Date = Date()
    var typeRaw: String = LogType.intro.rawValue
    var reactionRaw: String?
    /// Вкусовая оценка: понравилось / нейтрально / не понравилось.
    var likingRaw: String?
    var note: String?
    /// Запланированный на будущее ввод (ещё не дан), п.21.
    var planned: Bool = false

    init(foodId: String,
         date: Date = Date(),
         type: LogType = .intro,
         reaction: ReactionType? = nil,
         liking: Liking? = nil,
         note: String? = nil,
         planned: Bool = false) {
        self.foodId = foodId
        self.date = date
        self.typeRaw = type.rawValue
        self.reactionRaw = reaction?.rawValue
        self.likingRaw = liking?.rawValue
        self.note = note
        self.planned = planned
    }

    var type: LogType {
        get { LogType(rawValue: typeRaw) ?? .intro }
        set { typeRaw = newValue.rawValue }
    }

    var reaction: ReactionType? {
        get { reactionRaw.flatMap(ReactionType.init) }
        set { reactionRaw = newValue?.rawValue }
    }

    var liking: Liking? {
        get { likingRaw.flatMap(Liking.init) }
        set { likingRaw = newValue?.rawValue }
    }
}
