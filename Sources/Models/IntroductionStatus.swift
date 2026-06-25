import Foundation
import SwiftData

/// Статус введения конкретного продукта. Привязка к продукту по `foodId`
/// (Food — из JSON, не @Model). Свойства с дефолтами — для CloudKit (SPEC §8).
@Model
final class IntroductionStatus {
    var foodId: String = ""
    var stateRaw: String = IntroState.notIntroduced.rawValue
    var introStartedAt: Date?
    var completedAt: Date?

    init(foodId: String, state: IntroState = .notIntroduced) {
        self.foodId = foodId
        self.stateRaw = state.rawValue
    }

    var state: IntroState {
        get { IntroState(rawValue: stateRaw) ?? .notIntroduced }
        set { stateRaw = newValue.rawValue }
    }
}
