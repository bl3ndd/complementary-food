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
    /// Тяжесть реакции (лёгкая/средняя/сильная) — только когда есть реакция.
    var severityRaw: String?
    /// Вкусовая оценка: понравилось / нейтрально / не понравилось.
    var likingRaw: String?
    var note: String?
    /// Legacy: одиночное фото старых записей. Новые фото — в связи `photos`;
    /// поле оставлено, чтобы не потерять уже прикреплённые снимки (мигрируются
    /// при следующем сохранении записи). Читать через `photoDatas`.
    @Attribute(.externalStorage) var photo: Data?
    /// Несколько фото к записи (тарелка/сыпь-доказательство), external storage.
    @Relationship(deleteRule: .cascade, inverse: \LogPhoto.log)
    var photos: [LogPhoto]? = []
    /// Запланированный на будущее ввод (ещё не дан), п.21.
    var planned: Bool = false

    init(foodId: String,
         date: Date = Date(),
         type: LogType = .intro,
         reaction: ReactionType? = nil,
         liking: Liking? = nil,
         note: String? = nil,
         planned: Bool = false,
         severity: ReactionSeverity? = nil,
         photo: Data? = nil) {
        self.foodId = foodId
        self.date = date
        self.typeRaw = type.rawValue
        self.reactionRaw = reaction?.rawValue
        self.severityRaw = severity?.rawValue
        self.likingRaw = liking?.rawValue
        self.note = note
        self.planned = planned
        self.photo = photo
    }

    var type: LogType {
        get { LogType(rawValue: typeRaw) ?? .intro }
        set { typeRaw = newValue.rawValue }
    }

    var reaction: ReactionType? {
        get { reactionRaw.flatMap(ReactionType.init) }
        set { reactionRaw = newValue?.rawValue }
    }

    var severity: ReactionSeverity? {
        get { severityRaw.flatMap(ReactionSeverity.init) }
        set { severityRaw = newValue?.rawValue }
    }

    /// Все фото записи по порядку: сначала legacy-одиночное, затем relationship.
    var photoDatas: [Data] {
        let extra = (photos ?? []).sorted { $0.sortIndex < $1.sortIndex }.map(\.data)
        if let photo { return [photo] + extra }
        return extra
    }

    var liking: Liking? {
        get { likingRaw.flatMap(Liking.init) }
        set { likingRaw = newValue?.rawValue }
    }
}
