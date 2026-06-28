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

    /// notIntroduced/paused → introducing. Дату старта можно задать задним числом
    /// (родитель отмечает, что реально начал раньше) — окно наблюдения считается от неё.
    func startIntroduction(_ food: Food, date: Date = Date()) {
        let s = status(for: food.id)
        s.state = .introducing
        s.introStartedAt = date
        s.completedAt = nil
        context.insert(FoodLog(foodId: food.id, date: date, type: .intro))
        save()
    }

    /// introducing → introduced (окно наблюдения прошло, реакции нет).
    func completeIntroduction(_ food: Food) {
        let s = status(for: food.id)
        s.state = .introduced
        s.completedAt = Date()
        save()
    }

    /// Запись кормления. Реакция — только запись в журнал и НЕ меняет статус ввода
    /// (остановку/паузу пользователь выбирает вручную, SPEC §4.4). Заметка пишется
    /// в этот же лог, а не отдельной записью.
    func logFeeding(_ food: Food, liking: Liking?, reaction: ReactionType?,
                    date: Date = Date(), note: String? = nil) {
        let s = status(for: food.id)
        let isMaintenance = (s.state == .introduced)
        context.insert(FoodLog(foodId: food.id,
                               date: date,
                               type: isMaintenance ? .maintenance : .intro,
                               reaction: reaction,
                               liking: liking,
                               note: note))
        // Бэкдейт кормления во время ввода тянет старт окна назад, чтобы запись
        // «за прошлую дату» реально засчитывалась в окно наблюдения (п.22).
        if s.state == .introducing, let start = s.introStartedAt, date < start {
            s.introStartedAt = date
        }
        save()
    }

    /// Ручная пометка аллергии (для уже введённого аллергена — гасит напоминания
    /// поддержки). Авто-перехода по реакции больше нет, только этот ручной выбор.
    func markAllergy(_ food: Food) {
        let s = status(for: food.id)
        s.state = .allergy
        save()
    }

    /// Пользователь вручную останавливает ввод (была реакция / решил отложить) → пауза.
    func stopIntroduction(_ food: Food) {
        let s = status(for: food.id)
        s.state = .paused
        s.retryAt = nil
        save()
    }

    /// Оставить продукт в паузе и поставить напоминание «попробовать снова через N
    /// месяцев» (по умолчанию 2). Дату хранит `IntroductionStatus.retryAt`.
    func scheduleRetry(_ food: Food, after months: Int = 2,
                       now: Date = Date(), calendar: Calendar = .current) {
        let s = status(for: food.id)
        s.state = .paused
        s.retryAt = calendar.date(byAdding: .month, value: months, to: now)
        save()
    }

    /// Вернуть продукт в оборот (возобновить ввод). Сбрасывает напоминание-retry.
    func reintroduce(_ food: Food, date: Date = Date()) {
        let s = status(for: food.id)
        s.state = .introducing
        s.introStartedAt = date
        s.completedAt = nil
        s.retryAt = nil
        save()
    }

    private func save() {
        try? context.save()
    }
}

// MARK: - Окно наблюдения (чистая логика, инъекция now/calendar ради детерминизма)

extension FeedingService {
    /// Номер дня наблюдения с момента старта ввода (день старта = 1).
    static func observationDay(start: Date, now: Date = Date(),
                               calendar: Calendar = .current) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        return max(0, days) + 1
    }

    /// Прошло ли окно наблюдения — только тогда можно отмечать «ввёл успешно».
    static func isObservationComplete(start: Date, observationDays: Int,
                                      now: Date = Date(),
                                      calendar: Calendar = .current) -> Bool {
        observationDay(start: start, now: now, calendar: calendar) >= observationDays
    }

    /// Начало окна наблюдения = самая ранняя из дат: отметка старта и любой intro-лог.
    /// Гарантирует, что записи задним числом «двигают» окно (п.22).
    static func windowStart(introStartedAt: Date?, introLogDates: [Date]) -> Date? {
        ([introStartedAt].compactMap { $0 } + introLogDates).min()
    }
}
