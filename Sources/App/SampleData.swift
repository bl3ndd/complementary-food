#if DEBUG
import Foundation
import SwiftData

/// Тестовые данные для отладки. Включается аргументом запуска `-seedSample`.
enum SampleData {
    static func seed(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Child>())) ?? []
        guard existing.isEmpty else { return }

        let birth = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        context.insert(Child(name: "Маша", birthDate: birth, feedingProfileId: FeedingProfile.customId))

        // Брокколи — в процессе ввода (идёт окно наблюдения).
        let broc = IntroductionStatus(foodId: "broccoli", state: .introducing)
        let started = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        broc.introStartedAt = started
        context.insert(broc)
        context.insert(FoodLog(foodId: "broccoli", date: started, type: .intro, liking: .liked))

        // Яичный желток — введён, давно не давали → «пора дать аллерген».
        let egg = IntroductionStatus(foodId: "egg_yolk", state: .introduced)
        egg.completedAt = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        context.insert(egg)
        let given = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        context.insert(FoodLog(foodId: "egg_yolk", date: given, type: .maintenance, liking: .neutral))

        try? context.save()
    }
}
#endif
