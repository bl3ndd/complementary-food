#if DEBUG
import Foundation
import SwiftData
import UIKit

/// Тестовые данные для отладки.
/// - `-seedSample` — минимальный сид поверх пустого стора (как было).
/// - `-demo` — полноценный дневник за ~4 месяца в **in-memory** сторе: реальные
///   данные и их копия в iCloud не трогаются, после выхода демо исчезает.
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

    // MARK: - Демо-дневник за ~4 месяца (`-demo`)

    /// Живой дневник: ребёнок 10 месяцев, прикорм идёт 120 дней. Всё детерминировано
    /// (никакого `random`) — прогон повторяем и одинаков на любом устройстве.
    static func seedDiary(_ context: ModelContext, days: Int = 120, now: Date = Date()) {
        let cal = Calendar.current
        func day(_ offset: Int, hour: Int = 12, minute: Int = 0) -> Date {
            let base = cal.date(byAdding: .day, value: offset, to: now) ?? now
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        let child = Child(name: "Ника",
                          birthDate: cal.date(byAdding: .month, value: -10, to: now) ?? now)
        context.insert(child)

        // Порядок ввода — как в жизни: овощи → каши → фрукты → мясо → остальное.
        let catalog = FoodCatalog.shared
        let order: [FoodCategory] = [.vegetable, .porridge, .fruit, .meat, .fish, .dairy, .egg, .other]
        let queue: [Food] = order.flatMap { cat in
            catalog.foods.filter { $0.category == cat }.sorted { $0.id < $1.id }
        }

        // Новый продукт примерно каждые 3 дня.
        let step = 3
        let introduced = min(queue.count, days / step)
        var logs: [FoodLog] = []

        for i in 0..<introduced {
            let food = queue[i]
            let startOffset = -days + i * step
            let window = food.isAllergen ? 5 : 3

            // Хвост очереди оставляем в разных состояниях, чтобы на экранах
            // встречались все ветки стейт-машины, а не только «введён».
            let role: IntroState
            switch introduced - 1 - i {
            case 0, 1: role = .introducing
            case 2:    role = .paused
            case 7:    role = .allergy
            default:   role = .introduced
            }

            let status = IntroductionStatus(foodId: food.id, state: role)
            status.introStartedAt = day(startOffset)
            if role == .introduced || role == .allergy {
                status.completedAt = day(startOffset + window)
            }
            if role == .paused {
                status.retryAt = cal.date(byAdding: .month, value: 2, to: now)
            }
            context.insert(status)

            // Окно наблюдения: кормление каждый день окна.
            for d in 0..<(role == .introducing ? 1 : window) {
                let liking: Liking = [.liked, .neutral, .liked, .disliked][(i + d) % 4]
                logs.append(FoodLog(foodId: food.id,
                                    date: day(startOffset + d, minute: (i * 7) % 60),
                                    type: .intro, liking: liking))
            }

            // Дальше продукт иногда повторяют.
            guard role == .introduced else { continue }
            var offset = startOffset + window + 5
            while offset < 0 {
                let liking: Liking = [.liked, .liked, .neutral][abs(i + offset) % 3]
                logs.append(FoodLog(foodId: food.id,
                                    date: day(offset, hour: 18, minute: abs(offset * 11) % 60),
                                    type: .maintenance, liking: liking))
                offset += (i % 3 == 0) ? 6 : 9
            }
        }

        // Реакции — редкие, разные, с выраженностью и заметкой (это и идёт в PDF врачу).
        let reactions: [(idx: Int, offset: Int, type: ReactionType, sev: ReactionSeverity, note: String)] = [
            (3,  -96, .skin,         .mild,     "Щёки порозовели к вечеру, к утру прошло"),
            (9,  -74, .gi,           .moderate, "Срыгнул через полчаса"),
            (14, -52, .constipation, .mild,     "Два дня без стула"),
            (18, -35, .skin,         .severe,   "Сыпь на животе и руках, звонили врачу"),
            (22, -21, .diarrhea,     .moderate, "Жидко, весь день"),
            (26, -9,  .skin,         .mild,     "Небольшое покраснение вокруг рта"),
        ]
        for r in reactions where r.idx < introduced {
            logs.append(FoodLog(foodId: queue[r.idx].id, date: day(r.offset, hour: 14),
                                type: .maintenance, reaction: r.type, liking: .disliked,
                                note: r.note, severity: r.sev))
        }

        // Пара записей за сегодня — иначе главная на «живом» дневнике встречает
        // пустым «Записей сегодня ещё нет».
        for (n, hour) in [9, 13].enumerated() where n < introduced {
            let food = queue[(introduced - 1 - n + queue.count) % introduced]
            logs.append(FoodLog(foodId: food.id, date: day(0, hour: hour, minute: 20),
                                type: .maintenance, liking: n == 0 ? .liked : .neutral))
        }

        logs.forEach { context.insert($0) }

        // Фото к части записей — раздел «Фото» в PDF и лента миниатюр в UI.
        for (n, log) in logs.enumerated() where n > 0 && n % 37 == 0 {
            let photo = LogPhoto(data: swatch(index: n), sortIndex: 0)
            context.insert(photo)
            log.photos = [photo]
        }

        // Поддержка аллергенов: разводим группы по статусам ok / скоро / просрочено.
        let statuses = (try? context.fetch(FetchDescriptor<IntroductionStatus>())) ?? []
        for (group, daysAgo) in [(AllergenGroup.egg, 1), (.gluten, 2), (.peanut, 4),
                                 (.sesame, 6), (.fish, 13), (.soy, 16)] {
            guard let food = catalog.foods.first(where: { $0.allergenGroup == group }) else { continue }
            if let existing = statuses.first(where: { $0.foodId == food.id }) {
                existing.state = .introduced
            } else {
                let created = IntroductionStatus(foodId: food.id, state: .introduced)
                created.completedAt = day(-daysAgo - 5)
                context.insert(created)
            }
            context.insert(FoodLog(foodId: food.id, date: day(-daysAgo, hour: 9),
                                   type: .maintenance, liking: .neutral))
        }

        // Планы на будущее — в ленте и календаре появляется секция «Планы».
        for (n, offset) in [1, 3, 6].enumerated() where introduced + n < queue.count {
            context.insert(FoodLog(foodId: queue[introduced + n].id,
                                   date: day(offset), type: .intro, planned: true))
        }

        // Свои продукты: обычный и помеченный аллергеном (проверяем группу «Другое»).
        let soup = CustomFood(name: "Тыквенный крем-суп", emoji: "🍲")
        let cheese = CustomFood(name: "Козий творог", emoji: "🧀", isAllergen: true)
        [soup, cheese].forEach { context.insert($0) }
        FoodCatalog.setCustom([soup, cheese])
        for cf in [soup, cheese] {
            let s = IntroductionStatus(foodId: cf.id, state: .introduced)
            s.completedAt = day(-20)
            context.insert(s)
            context.insert(FoodLog(foodId: cf.id, date: day(-3, hour: 13),
                                   type: .maintenance, liking: .liked))
        }

        try? context.save()
    }

    /// Цветной прямоугольник вместо реального фото (детерминированно от индекса).
    private static func swatch(index: Int) -> Data {
        let hues: [CGFloat] = [0.08, 0.33, 0.55, 0.92]
        let color = UIColor(hue: hues[index % hues.count], saturation: 0.45,
                            brightness: 0.92, alpha: 1)
        let size = CGSize(width: 240, height: 240)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
#endif
