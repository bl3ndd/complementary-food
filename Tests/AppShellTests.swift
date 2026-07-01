import XCTest
import SwiftData
@testable import Prikorm

/// Тесты оболочки приложения (Task 7): онбординг создаёт валидного ребёнка
/// (на это завязан гейт RootView) и логика выбора «пора дать аллерген» на
/// дашборде (AllergenMaintenance.dueForDashboard).
final class AppShellTests: XCTestCase {

    /// Фиксированная «сейчас» — без зависимости от системного времени.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: now)!
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Child.self, IntroductionStatus.self, FoodLog.self, LogPhoto.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func profile(frequencyPerWeek: Int,
                         groups: [AllergenGroup]) -> FeedingProfile {
        FeedingProfile(id: "test", name: "Test", startAgeMonths: 6,
                       observationDaysRegular: 3, observationDaysAllergen: 5,
                       allergenFrequencyPerWeek: frequencyPerWeek, allergenGroups: groups)
    }

    private func food(_ id: String, group: AllergenGroup) -> Food {
        Food(id: id, name: id.capitalized, category: .other,
             emoji: "🥚", isAllergen: true, allergenGroup: group, minAgeMonths: 6)
    }

    // MARK: - Онбординг создаёт валидного ребёнка

    /// Повторяет OnboardingView.finish(): вставка Child делает RootView-гейт
    /// «есть ребёнок», а сам ребёнок валиден и читается обратно.
    @MainActor
    func testOnboardingCreatesValidQueryableChild() throws {
        let container = try makeContainer()
        let context = container.mainContext

        XCTAssertTrue(try context.fetch(FetchDescriptor<Child>()).isEmpty,
                      "до онбординга детей нет → показывается онбординг")

        let birth = Calendar.current.date(byAdding: .month, value: -6, to: now)!
        let child = Child(name: "Аня", birthDate: birth, feedingProfileId: FeedingProfile.customId)
        context.insert(child)
        try context.save()

        let children = try context.fetch(FetchDescriptor<Child>())
        XCTAssertEqual(children.count, 1, "RootView.children.first → MainTabView")
        let loaded = try XCTUnwrap(children.first)
        XCTAssertEqual(loaded.name, "Аня")
        XCTAssertEqual(loaded.birthDate, birth)
        XCTAssertEqual(loaded.feedingProfile.id, FeedingProfile.customId,
                       "методика всегда «свой план»")
        XCTAssertEqual(loaded.ageInMonths(now: now), 6)
    }

    /// Пустое имя (поле необязательно) — всё равно валидный ребёнок,
    /// методика по умолчанию резолвится в пресет.
    @MainActor
    func testOnboardingChildWithEmptyNameIsValid() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let child = Child(name: "", birthDate: now)
        context.insert(child)
        try context.save()

        let loaded = try XCTUnwrap(try context.fetch(FetchDescriptor<Child>()).first)
        XCTAssertEqual(loaded.name, "")
        XCTAssertEqual(loaded.feedingProfile.id, FeedingProfile.customId,
                       "методика по умолчанию — свой план")
    }

    // MARK: - Дашборд: выбор «пора дать аллерген»

    /// dueForDashboard включает только введённые группы без аллергии,
    /// у которых срок поддержки подошёл (dueSoon/overdue), и исключает
    /// «ok», «есть аллергия» и ещё не введённые.
    func testDashboardDueSelectsIntroducedDueGroupsOnly() throws {
        let catalog = FoodCatalog(foods: [
            food("egg_yolk", group: .egg),       // введён, overdue → попадает
            food("cod", group: .fish),           // введён, ok → НЕ попадает
            food("peanut", group: .peanut),      // аллергия → НЕ попадает
            food("yogurt", group: .dairy),       // не введён → НЕ попадает
        ])
        let prof = profile(frequencyPerWeek: 1, groups: [.egg, .fish, .peanut, .dairy])

        let statuses = [
            IntroductionStatus(foodId: "egg_yolk", state: .introduced),
            IntroductionStatus(foodId: "cod", state: .introduced),
            IntroductionStatus(foodId: "peanut", state: .allergy),
            // dairy: статуса нет → не введён
        ]
        let logs = [
            FoodLog(foodId: "egg_yolk", date: daysAgo(20), type: .maintenance), // давно → overdue
            FoodLog(foodId: "cod", date: daysAgo(1), type: .maintenance),       // недавно → ok
        ]

        let maintenance = AllergenMaintenance(catalog: catalog, profile: prof,
                                              statuses: statuses, logs: logs, now: now)
        let due = maintenance.dueForDashboard()

        XCTAssertEqual(due.map(\.group), [.egg], "только введённая просроченная группа")

        let egg = try XCTUnwrap(due.first)
        XCTAssertTrue(egg.isIntroduced)
        XCTAssertFalse(egg.hasAllergy)
        XCTAssertNotEqual(egg.status, .ok)
    }

    /// Группа введена, но дана недавно (ok) → дашборд её не показывает.
    func testDashboardDueExcludesRecentlyGiven() {
        let catalog = FoodCatalog(foods: [food("egg_yolk", group: .egg)])
        let prof = profile(frequencyPerWeek: 1, groups: [.egg])

        let statuses = [IntroductionStatus(foodId: "egg_yolk", state: .introduced)]
        let logs = [FoodLog(foodId: "egg_yolk", date: daysAgo(0), type: .maintenance)]

        let due = AllergenMaintenance(catalog: catalog, profile: prof,
                                      statuses: statuses, logs: logs, now: now).dueForDashboard()
        XCTAssertTrue(due.isEmpty, "ok-группа не попадает в «пора дать»")
    }

    /// Нет введённых аллергенов → блок «пора дать» пуст.
    func testDashboardDueEmptyWhenNothingIntroduced() {
        let catalog = FoodCatalog(foods: [food("egg_yolk", group: .egg)])
        let prof = profile(frequencyPerWeek: 1, groups: [.egg])

        let due = AllergenMaintenance(catalog: catalog, profile: prof,
                                      statuses: [], logs: [], now: now).dueForDashboard()
        XCTAssertTrue(due.isEmpty)
    }
}
