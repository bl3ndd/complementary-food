import Foundation
import SwiftData

/// Фото, прикреплённое к записи журнала (тарелка / сыпь-доказательство). Отдельная
/// сущность со связью к `FoodLog` — чтобы фото было несколько и они хранились вне
/// строки БД (external storage → CloudKit-ассеты, не раздувают запись, SPEC §8).
@Model
final class LogPhoto {
    @Attribute(.externalStorage) var data: Data = Data()
    /// Порядок в записи (как добавляли).
    var sortIndex: Int = 0
    /// Обратная связь к записи (для CloudKit — опциональна).
    var log: FoodLog?

    init(data: Data, sortIndex: Int = 0) {
        self.data = data
        self.sortIndex = sortIndex
    }
}
