import XCTest
@testable import Prikorm

/// Тесты поддержки аллергенов (Task 4): граничная математика статуса
/// ok/dueSoon/overdue по частоте методики (AllergenTracker) и агрегация
/// статусов/журнала по группам (AllergenMaintenance).
final class AllergenTests: XCTestCase {

    /// Фиксированная «сейчас» — без зависимости от системного времени.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: now)!
    }

    private func profile(frequencyPerWeek: Int,
                         groups: [AllergenGroup]) -> FeedingProfile {
        FeedingProfile(id: "test", name: "Test", startAgeMonths: 6,
                       observationDays: 3, allergenFrequencyPerWeek: frequencyPerWeek,
                       allergenGroups: groups, isPreset: false)
    }

    private func food(_ id: String, group: AllergenGroup) -> Food {
        Food(id: id, name: id.capitalized, category: .allergen,
             emoji: "🥚", isAllergen: true, allergenGroup: group, minAgeMonths: 6)
    }

    // MARK: - Интервал поддержки из частоты

    func testMaintenanceIntervalDaysFromFrequency() {
        XCTAssertEqual(profile(frequencyPerWeek: 1, groups: []).maintenanceIntervalDays, 7)
        XCTAssertEqual(profile(frequencyPerWeek: 2, groups: []).maintenanceIntervalDays, 4)  // round(3.5)
        XCTAssertEqual(profile(frequencyPerWeek: 3, groups: []).maintenanceIntervalDays, 2)  // round(2.33)
        XCTAssertEqual(profile(frequencyPerWeek: 7, groups: []).maintenanceIntervalDays, 1)
    }

    // MARK: - status: nil → overdue (никогда не давали)

    func testStatusNilLastGivenIsOverdue() {
        let tracker = AllergenTracker(profile: profile(frequencyPerWeek: 1, groups: []))
        XCTAssertEqual(tracker.status(lastGiven: nil, now: now), .overdue)
        XCTAssertNil(tracker.nextDue(lastGiven: nil))
    }

    // MARK: - Граница для интервала 7 (частота 1/нед)

    func testStatusBoundariesForWeeklyInterval() {
        let tracker = AllergenTracker(profile: profile(frequencyPerWeek: 1, groups: []))
        // interval = 7; ok при days <= 5, dueSoon при 6..7, overdue при > 7
        XCTAssertEqual(tracker.status(lastGiven: daysAgo(0), now: now), .ok)
        XCTAssertEqual(tracker.status(lastGiven: daysAgo(5), now: now), .ok)
        XCTAssertEqual(tracker.status(lastGiven: daysAgo(6), now: now), .dueSoon)
        XCTAssertEqual(tracker.status(lastGiven: daysAgo(7), now: now), .dueSoon)
        XCTAssertEqual(tracker.status(lastGiven: daysAgo(8), now: now), .overdue)
    }

    // MARK: - Граница для интервала 2 (частота 3/нед)

    func testStatusBoundariesForShortInterval() {
        let tracker = AllergenTracker(profile: profile(frequencyPerWeek: 3, groups: []))
        // interval = 2; ok при days 0, dueSoon при 1..2, overdue при > 2
        XCTAssertEqual(tracker.status(lastGiven: daysAgo(0), now: now), .ok)
        XCTAssertEqual(tracker.status(lastGiven: daysAgo(1), now: now), .dueSoon)
        XCTAssertEqual(tracker.status(lastGiven: daysAgo(2), now: now), .dueSoon)
        XCTAssertEqual(tracker.status(lastGiven: daysAgo(3), now: now), .overdue)
    }

    // MARK: - nextDue = lastGiven + interval

    func testNextDueAddsIntervalDays() throws {
        let tracker = AllergenTracker(profile: profile(frequencyPerWeek: 1, groups: []))
        let last = daysAgo(3)
        let due = try XCTUnwrap(tracker.nextDue(lastGiven: last))
        let expected = Calendar.current.date(byAdding: .day, value: 7, to: last)!
        XCTAssertEqual(due, expected)
    }

    // MARK: - Агрегация по группам

    func testMaintenanceAggregatesGroups() throws {
        let catalog = FoodCatalog(foods: [
            food("egg_yolk", group: .egg),
            food("egg_white", group: .egg),
            food("peanut", group: .peanut),
            food("cod", group: .fish),
        ])
        let prof = profile(frequencyPerWeek: 1, groups: [.egg, .peanut, .fish, .soy])

        let statuses = [
            IntroductionStatus(foodId: "egg_white", state: .introduced),
            IntroductionStatus(foodId: "peanut", state: .allergy),
        ]
        // egg_white: давали в поддержку 3 и 10 дней назад → lastGiven = 3 дня назад
        let logs = [
            FoodLog(foodId: "egg_white", date: daysAgo(10), type: .maintenance),
            FoodLog(foodId: "egg_white", date: daysAgo(3), type: .maintenance),
        ]

        let result = AllergenMaintenance(catalog: catalog, profile: prof,
                                         statuses: statuses, logs: logs).groups()

        // .soy в каталоге нет → группа пропущена
        XCTAssertEqual(result.map(\.group), [.egg, .peanut, .fish])

        let egg = try XCTUnwrap(result.first { $0.group == .egg })
        XCTAssertTrue(egg.isIntroduced)
        XCTAssertFalse(egg.hasAllergy)
        XCTAssertEqual(egg.lastGiven, daysAgo(3), "берётся самая поздняя дата по группе")
        XCTAssertEqual(egg.status, .ok)
        XCTAssertEqual(egg.representativeFood?.id, "egg_white", "введённый продукт — представитель")
        XCTAssertEqual(egg.foods.count, 2)

        let peanut = try XCTUnwrap(result.first { $0.group == .peanut })
        XCTAssertTrue(peanut.hasAllergy)
        XCTAssertFalse(peanut.isIntroduced)
        XCTAssertNil(peanut.lastGiven)
        XCTAssertEqual(peanut.status, .overdue)

        let fish = try XCTUnwrap(result.first { $0.group == .fish })
        XCTAssertFalse(fish.isIntroduced)
        XCTAssertFalse(fish.hasAllergy)
        XCTAssertNil(fish.lastGiven)
        XCTAssertEqual(fish.representativeFood?.id, "cod", "без введённых — первый из группы")
    }
}
