import XCTest
import SwiftData
@testable import Prikorm

/// Тесты слоя моделей: round-trip через in-memory ModelContainer
/// и арифметика возраста ребёнка (Task 1).
final class ModelTests: XCTestCase {

    /// Свежий in-memory контейнер на каждый тест — изоляция, без диска.
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Child.self, IntroductionStatus.self, FoodLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Round-trip

    @MainActor
    func testChildRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let birth = Date(timeIntervalSince1970: 1_600_000_000)
        let child = Child(name: "Маша", birthDate: birth, feedingProfileId: FeedingProfile.customId)
        context.insert(child)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Child>())
        XCTAssertEqual(fetched.count, 1)
        let loaded = try XCTUnwrap(fetched.first)
        XCTAssertEqual(loaded.name, "Маша")
        XCTAssertEqual(loaded.birthDate, birth)
        XCTAssertEqual(loaded.feedingProfileId, FeedingProfile.customId)
        XCTAssertEqual(loaded.feedingProfile.id, FeedingProfile.customId)
    }

    @MainActor
    func testIntroductionStatusRoundTripAndStateEnum() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let status = IntroductionStatus(foodId: "broccoli", state: .introducing)
        status.introStartedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(status)
        try context.save()

        let loaded = try XCTUnwrap(try context.fetch(FetchDescriptor<IntroductionStatus>()).first)
        XCTAssertEqual(loaded.foodId, "broccoli")
        XCTAssertEqual(loaded.state, .introducing)
        XCTAssertEqual(loaded.stateRaw, IntroState.introducing.rawValue)

        // мутация enum через computed property пишет в raw-хранилище
        loaded.state = .introduced
        XCTAssertEqual(loaded.stateRaw, IntroState.introduced.rawValue)
    }

    @MainActor
    func testFoodLogRoundTripWithOptionalEnums() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let date = Date(timeIntervalSince1970: 1_650_000_000)
        let log = FoodLog(foodId: "egg",
                          date: date,
                          type: .maintenance,
                          reaction: .skin,
                          liking: .liked,
                          note: "немного сыпи")
        context.insert(log)
        try context.save()

        let loaded = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodLog>()).first)
        XCTAssertEqual(loaded.foodId, "egg")
        XCTAssertEqual(loaded.date, date)
        XCTAssertEqual(loaded.type, .maintenance)
        XCTAssertEqual(loaded.reaction, .skin)
        XCTAssertEqual(loaded.liking, .liked)
        XCTAssertEqual(loaded.note, "немного сыпи")
    }

    @MainActor
    func testFoodLogNilOptionalsRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let log = FoodLog(foodId: "carrot")   // дефолтный intro, без реакции/оценки
        context.insert(log)
        try context.save()

        let loaded = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodLog>()).first)
        XCTAssertEqual(loaded.type, .intro)
        XCTAssertNil(loaded.reaction)
        XCTAssertNil(loaded.liking)
        XCTAssertNil(loaded.note)
    }

    // MARK: - Age math

    func testAgeInMonthsExactBoundary() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let birth = cal.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let child = Child(name: "Тест", birthDate: birth)

        // ровно 6 месяцев
        let sixMonths = cal.date(from: DateComponents(year: 2025, month: 7, day: 15))!
        XCTAssertEqual(child.ageInMonths(now: sixMonths, calendar: cal), 6)

        // на день меньше — ещё 5 полных месяцев
        let almostSix = cal.date(from: DateComponents(year: 2025, month: 7, day: 14))!
        XCTAssertEqual(child.ageInMonths(now: almostSix, calendar: cal), 5)
    }

    func testAgeInMonthsNewbornAndSameDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let birth = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let child = Child(name: "Тест", birthDate: birth)

        XCTAssertEqual(child.ageInMonths(now: birth, calendar: cal), 0)

        let twoWeeks = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        XCTAssertEqual(child.ageInMonths(now: twoWeeks, calendar: cal), 0)
    }

    // MARK: - FeedingProfile config (свой план)

    func testCustomFeedingProfileMaintenanceInterval() {
        let child = Child(feedingProfileId: FeedingProfile.customId)
        child.customAllergenFrequencyPerWeek = 2
        XCTAssertEqual(child.feedingProfile.maintenanceIntervalDays, 4)  // 7/2 ≈ 3.5 → 4
        child.customAllergenFrequencyPerWeek = 1
        XCTAssertEqual(child.feedingProfile.maintenanceIntervalDays, 7)  // 7/1 → 7
    }
}
