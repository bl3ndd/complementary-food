import Foundation
import SwiftData

/// Операции над данными введения прикорма. Инкапсулирует переходы стейт-машины
/// (SPEC §4.4), чтобы вьюхи не дублировали логику.
struct FeedingService {
    let context: ModelContext

    /// Находит статус продукта или создаёт новый (notIntroduced).
    func status(for foodId: String) -> IntroductionStatus {
        var descriptor = FetchDescriptor<IntroductionStatus>(
            predicate: #Predicate { $0.foodId == foodId }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = IntroductionStatus(foodId: foodId)
        context.insert(created)
        return created
    }

    /// notIntroduced/paused → introducing.
    func startIntroduction(_ food: Food) {
        let s = status(for: food.id)
        s.state = .introducing
        s.introStartedAt = Date()
        s.completedAt = nil
        context.insert(FoodLog(foodId: food.id, type: .intro))
        save()
    }

    /// introducing → introduced (окно наблюдения прошло, реакции нет).
    func completeIntroduction(_ food: Food) {
        let s = status(for: food.id)
        s.state = .introduced
        s.completedAt = Date()
        save()
    }

    /// Запись кормления. Реакция двигает стейт-машину:
    /// реакция при вводе → paused; реакция на уже введённый → allergy (SPEC §4.4).
    func logFeeding(_ food: Food, liking: Liking?, reaction: ReactionType?) {
        let s = status(for: food.id)
        let isMaintenance = (s.state == .introduced)
        context.insert(FoodLog(foodId: food.id,
                               type: isMaintenance ? .maintenance : .intro,
                               reaction: reaction,
                               liking: liking))
        if let reaction, reaction != .none {
            s.state = isMaintenance ? .allergy : .paused
        }
        save()
    }

    /// Ручная пометка аллергии.
    func markAllergy(_ food: Food) {
        let s = status(for: food.id)
        s.state = .allergy
        save()
    }

    /// Вернуть продукт в оборот (только по решению врача, SPEC §4.4).
    func reintroduce(_ food: Food) {
        let s = status(for: food.id)
        s.state = .introducing
        s.introStartedAt = Date()
        s.completedAt = nil
        save()
    }

    private func save() {
        try? context.save()
    }
}
