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

    func groups() -> [AllergenGroupStatus] {
        let tracker = AllergenTracker(profile: profile)

        return profile.allergenGroups.compactMap { group in
            let foods = catalog.foods.filter { $0.allergenGroup == group }
            guard !foods.isEmpty else { return nil }

            let foodIds = Set(foods.map { $0.id })
            let groupStatuses = statuses.filter { foodIds.contains($0.foodId) }
            let hasAllergy = groupStatuses.contains { $0.state == .allergy }
            let isIntroduced = groupStatuses.contains { $0.state == .introduced }
            // «Последний приём» — только фактические чистые дозы: без планов, без
            // будущих дат и без реакций (реакция ≠ доза для поддержки толерантности).
            let cleanGiven = logs.filter {
                foodIds.contains($0.foodId) && !$0.planned && $0.date <= now
                    && ($0.reaction ?? .none) == .none
            }.map(\.date).max()
            // Если фактических доз нет (напр. «уже введено» из онбординга без логов),
            // базой берём дату завершения ввода — иначе аллерген сразу «просрочен».
            let introducedAt = groupStatuses.filter { $0.state == .introduced }
                .compactMap { $0.completedAt }.max()
            let lastGiven = cleanGiven ?? introducedAt

            // Представитель группы: первый введённый продукт, иначе первый из группы.
            let introducedFoodIds = Set(groupStatuses.filter { $0.state == .introduced }.map(\.foodId))
            let representative = foods.first { introducedFoodIds.contains($0.id) } ?? foods.first

            return AllergenGroupStatus(
                group: group,
                foods: foods,
                representativeFood: representative,
                isIntroduced: isIntroduced,
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
