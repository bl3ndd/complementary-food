import Foundation

/// Сводный статус поддержки одной группы аллергенов (SPEC §4.3).
struct AllergenGroupStatus: Identifiable {
    let group: AllergenGroup
    let foods: [Food]
    let representativeFood: Food?
    let isIntroduced: Bool
    let hasAllergy: Bool
    let lastGiven: Date?
    let status: AllergenStatus
    let nextDue: Date?

    var id: String { group.rawValue }
}

/// Считает статусы поддержки по всем группам аллергенов из методики.
struct AllergenMaintenance {
    let catalog: FoodCatalog
    let profile: FeedingProfile
    let statuses: [IntroductionStatus]
    let logs: [FoodLog]
    /// «Сейчас» и календарь инъектируются ради детерминизма границ дня/таймзоны
    /// (CLAUDE.md: не читаем системные часы внутри тестируемой логики).
    var now: Date = Date()
    var calendar: Calendar = .current

    /// Один проход по каталогу, статусам и журналу вместо прохода НА КАЖДУЮ группу.
    /// Раньше это было O(групп × журнала) — на дневнике за пару месяцев тысячи
    /// обращений к SwiftData-полям за одну перерисовку главной (сводка считается и
    /// на дашборде, и в бейдже таба).
    func groups() -> [AllergenGroupStatus] {
        let tracker = AllergenTracker(profile: profile)
        let wanted = Set(profile.allergenGroups)

        // Каталог: продукты по группам (порядок каталога сохраняем — по нему
        // выбирается представитель) + обратный индекс продукт → группа.
        // `all`, а не `foods`: свои продукты пользователя тоже могут быть
        // помечены аллергеном — раньше они молча выпадали из трекера.
        var foodsByGroup: [AllergenGroup: [Food]] = [:]
        var groupOfFood: [String: AllergenGroup] = [:]
        for food in catalog.all {
            guard let g = food.allergenGroup, wanted.contains(g) else { continue }
            foodsByGroup[g, default: []].append(food)
            groupOfFood[food.id] = g
        }

        var statusesByGroup: [AllergenGroup: [IntroductionStatus]] = [:]
        for s in statuses {
            guard let g = groupOfFood[s.foodId] else { continue }
            statusesByGroup[g, default: []].append(s)
        }

        // «Последний приём» — только фактические чистые дозы: без планов, без
        // будущих дат и без реакций (реакция ≠ доза для поддержки толерантности).
        var cleanGivenByGroup: [AllergenGroup: Date] = [:]
        for log in logs {
            guard let g = groupOfFood[log.foodId], !log.planned, log.date <= now,
                  (log.reaction ?? .none) == .none else { continue }
            if let best = cleanGivenByGroup[g], best >= log.date { continue }
            cleanGivenByGroup[g] = log.date
        }

        return profile.allergenGroups.compactMap { group in
            guard let foods = foodsByGroup[group], !foods.isEmpty else { return nil }

            let groupStatuses = statusesByGroup[group] ?? []
            let hasAllergy = groupStatuses.contains { $0.state == .allergy }
            let introducedStatuses = groupStatuses.filter { $0.state == .introduced }
            // Если фактических доз нет (напр. «уже введено» из онбординга без логов),
            // базой берём дату завершения ввода — иначе аллерген сразу «просрочен».
            let introducedAt = introducedStatuses.compactMap { $0.completedAt }.max()
            let lastGiven = cleanGivenByGroup[group] ?? introducedAt

            // Представитель группы: первый введённый продукт, иначе первый из группы.
            let introducedFoodIds = Set(introducedStatuses.map(\.foodId))
            let representative = foods.first { introducedFoodIds.contains($0.id) } ?? foods.first

            return AllergenGroupStatus(
                group: group,
                foods: foods,
                representativeFood: representative,
                isIntroduced: !introducedStatuses.isEmpty,
                hasAllergy: hasAllergy,
                lastGiven: lastGiven,
                status: tracker.status(lastGiven: lastGiven, now: now, calendar: calendar),
                nextDue: tracker.nextDue(lastGiven: lastGiven, calendar: calendar)
            )
        }
    }

    /// Группы для блока «Пора дать аллерген» на дашборде: уже введены,
    /// без зафиксированной аллергии и срок поддержки подошёл (dueSoon/overdue).
    func dueForDashboard() -> [AllergenGroupStatus] {
        groups().filter { $0.isIntroduced && !$0.hasAllergy && $0.status != .ok }
    }
}
