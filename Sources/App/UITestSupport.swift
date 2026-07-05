#if DEBUG
import Foundation
import SwiftData

/// Поддержка UI-тестов (аргумент `-uitest`): изолированный in-memory стор (реальные
/// данные устройства не трогаем), чистые defaults и детерминированные сиды состояний.
/// Карта сидов — docs/E2E-CASES.md.
enum UITestSupport {
    static var isActive: Bool { CommandLine.arguments.contains("-uitest") }

    private static var seed: String? {
        CommandLine.arguments
            .first { $0.hasPrefix("-uitest-seed=") }
            .map { String($0.dropFirst("-uitest-seed=".count)) }
    }

    static func prepare(_ context: ModelContext) {
        // Гейт дисклеймера должен быть предсказуем в каждом прогоне.
        UserDefaults.standard.removeObject(forKey: "disclaimer.acknowledged")
        guard let seed else { return }

        let cal = Calendar.current
        func days(_ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: Date()) ?? Date() }

        // Ребёнок есть во всех сидах (без сида — онбординг).
        let child = Child(name: "Ника",
                          birthDate: cal.date(byAdding: .month, value: -8, to: Date()) ?? Date())
        context.insert(child)

        func introduce(_ id: String, daysAgo: Int) {
            let s = IntroductionStatus(foodId: id, state: .introduced)
            s.completedAt = days(-daysAgo)
            context.insert(s)
        }
        func introducing(_ id: String, startedDaysAgo: Int) {
            let s = IntroductionStatus(foodId: id, state: .introducing)
            s.introStartedAt = days(-startedDaysAgo)
            context.insert(s)
            context.insert(FoodLog(foodId: id, date: days(-startedDaysAgo), type: .intro))
        }

        switch seed {
        case "child":
            break   // только ребёнок — пустой дневник

        case "introducing":
            introducing("broccoli", startedDaysAgo: 0)   // день 1 из 3

        case "window-done":
            introducing("broccoli", startedDaysAgo: 5)   // окно (3 дн) прошло → можно завершать

        case "introduced":
            introduce("broccoli", daysAgo: 10)
            context.insert(FoodLog(foodId: "broccoli", date: Date(),
                                   type: .maintenance, liking: .liked))

        case "rich":
            // Введён + кормления (сегодня с оценкой/заметкой, позавчера с реакцией).
            introduce("broccoli", daysAgo: 10)
            context.insert(FoodLog(
                foodId: "broccoli",
                date: cal.date(byAdding: .hour, value: -1, to: Date()) ?? Date(),
                type: .maintenance, liking: .liked, note: "обед"))
            context.insert(FoodLog(foodId: "broccoli", date: days(-2),
                                   type: .maintenance, reaction: .skin, note: "лёгкая сыпь"))
            // Вводится сейчас (для «Сейчас вводишь» на главной).
            introducing("zucchini", startedDaysAgo: 0)
            // Желток введён, давали 6 дней назад → «пора освежить» (интервал 4 дн).
            introduce("egg_yolk", daysAgo: 10)
            context.insert(FoodLog(foodId: "egg_yolk", date: days(-6), type: .maintenance))
            // Треска на паузе → активен лист «Не давать».
            context.insert(IntroductionStatus(foodId: "cod", state: .paused))
            // Планы: яблоко сегодня (дедуп + «Выполнено»), груша завтра (секция «Планы»).
            context.insert(FoodLog(foodId: "apple", date: Date(), type: .intro, planned: true))
            context.insert(FoodLog(foodId: "pear", date: days(1), type: .intro, planned: true))

        default:
            break
        }
        try? context.save()
    }
}
#endif
