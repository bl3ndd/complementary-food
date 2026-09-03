import Foundation
import SwiftData

/// Статус введения конкретного продукта. Привязка к продукту по `foodId`
/// (Food — из JSON, не @Model). Свойства с дефолтами — для CloudKit (SPEC §8).
@Model
final class IntroductionStatus {
    var foodId: String = ""
    /// Чей это дневник. Опциональное — требование CloudKit и условие того, что поле
    /// добавляется БЕЗ новой версии схемы (см. CLAUDE.md). У записей, сделанных до
    /// появления нескольких детей, тут `nil`, пока их не подхватит бэкфилл
    /// `PlanMigration.ChildOwnership`.
    var childId: UUID?
    var stateRaw: String = IntroState.notIntroduced.rawValue
    var introStartedAt: Date?
    var completedAt: Date?
    /// Если стоит — дата напоминания «попробовать продукт снова» (пауза + retry).
    var retryAt: Date?

    init(foodId: String, state: IntroState = .notIntroduced) {
        self.foodId = foodId
        self.stateRaw = state.rawValue
    }

    var state: IntroState {
        get { IntroState(rawValue: stateRaw) ?? .notIntroduced }
        set { stateRaw = newValue.rawValue }
    }
}
