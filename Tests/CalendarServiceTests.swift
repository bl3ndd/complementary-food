import XCTest
@testable import Prikorm

/// Тесты календаря (Task 5): группировка журнала по дням, корректность границ
/// дня/таймзоны и обработка пустых дней (SPEC §7).
final class CalendarServiceTests: XCTestCase {

    private let catalog = FoodCatalog(foods: [
        Food(id: "broccoli", name: "Брокколи", category: .vegetable,
             emoji: "🥦", isAllergen: false, allergenGroup: nil, minAgeMonths: 4),
        Food(id: "egg_yolk", name: "Желток", category: .egg,
             emoji: "🥚", isAllergen: true, allergenGroup: .egg, minAgeMonths: 6),
    ])

    /// Фиксированный календарь UTC — границы дня не зависят от таймзоны машины.
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")!
        return f.date(from: iso)!
    }

    private func log(_ foodId: String, _ iso: String,
                     type: LogType = .intro,
                     reaction: ReactionType? = nil,
                     liking: Liking? = nil) -> FoodLog {
        FoodLog(foodId: foodId, date: date(iso), type: type,
                reaction: reaction, liking: liking)
    }

    // MARK: - Группировка по дням

    func testDaysGroupLogsByCalendarDayNewestFirst() {
        let logs = [
            log("broccoli", "2026-06-10T08:00:00Z"),
            log("broccoli", "2026-06-10T18:30:00Z", type: .maintenance),
            log("egg_yolk", "2026-06-12T09:00:00Z"),
        ]
        let service = CalendarService(catalog: catalog, logs: logs, calendar: utc)
        let days = service.days()

        XCTAssertEqual(days.count, 2, "две разные даты")
        // Новые дни сверху.
        XCTAssertEqual(utc.component(.day, from: days[0].date), 12)
        XCTAssertEqual(utc.component(.day, from: days[1].date), 10)

        let tenth = days[1]
        XCTAssertEqual(tenth.entries.count, 2)
        XCTAssertEqual(tenth.introCount, 1)
        XCTAssertEqual(tenth.maintenanceCount, 1)
        // Записи внутри дня — ранние сверху.
        XCTAssertEqual(utc.component(.hour, from: tenth.entries[0].date), 8)
        XCTAssertEqual(utc.component(.hour, from: tenth.entries[1].date), 18)
        // Имя продукта резолвится из каталога.
        XCTAssertEqual(tenth.entries[0].foodName, "Брокколи")
    }

    // MARK: - Граница дня / таймзона

    func testDayBoundaryGroupsLateAndEarlyAcrossMidnight() {
        // 23:30 десятого и 00:30 одиннадцатого — РАЗНЫЕ дни в UTC.
        let logs = [
            log("broccoli", "2026-06-10T23:30:00Z"),
            log("broccoli", "2026-06-11T00:30:00Z"),
        ]
        let service = CalendarService(catalog: catalog, logs: logs, calendar: utc)
        XCTAssertEqual(service.days().count, 2)
        XCTAssertEqual(service.activeDays().count, 2)
    }

    func testStartOfDayKeyIsMidnight() {
        let logs = [log("broccoli", "2026-06-10T08:00:00Z")]
        let service = CalendarService(catalog: catalog, logs: logs, calendar: utc)
        let key = service.days()[0].date
        XCTAssertEqual(utc.component(.hour, from: key), 0)
        XCTAssertEqual(utc.component(.minute, from: key), 0)
    }

    // MARK: - day(date)

    func testDayReturnsEntriesForThatDateOnly() {
        let logs = [
            log("broccoli", "2026-06-10T08:00:00Z"),
            log("egg_yolk", "2026-06-11T09:00:00Z"),
        ]
        let service = CalendarService(catalog: catalog, logs: logs, calendar: utc)

        let tenth = service.day(date("2026-06-10T15:00:00Z"))
        XCTAssertEqual(tenth.entries.count, 1)
        XCTAssertEqual(tenth.entries[0].foodName, "Брокколи")
    }

    func testEmptyDayHasNoActivity() {
        let logs = [log("broccoli", "2026-06-10T08:00:00Z")]
        let service = CalendarService(catalog: catalog, logs: logs, calendar: utc)

        let empty = service.day(date("2026-06-20T12:00:00Z"))
        XCTAssertTrue(empty.entries.isEmpty)
        XCTAssertFalse(empty.hasActivity)
        XCTAssertEqual(empty.introCount, 0)
        XCTAssertEqual(empty.maintenanceCount, 0)
    }

    func testNoLogsProducesNoDays() {
        let service = CalendarService(catalog: catalog, logs: [], calendar: utc)
        XCTAssertTrue(service.days().isEmpty)
        XCTAssertTrue(service.activeDays().isEmpty)
    }

    // MARK: - Реакция в сводке

    func testHasReactionReflectsEntries() {
        let calm = CalendarService(
            catalog: catalog,
            logs: [log("broccoli", "2026-06-10T08:00:00Z", reaction: ReactionType.none)],
            calendar: utc)
        XCTAssertFalse(calm.day(date("2026-06-10T08:00:00Z")).hasReaction)

        let reacted = CalendarService(
            catalog: catalog,
            logs: [log("egg_yolk", "2026-06-10T08:00:00Z", reaction: .skin)],
            calendar: utc)
        XCTAssertTrue(reacted.day(date("2026-06-10T08:00:00Z")).hasReaction)
    }

    // MARK: - Неизвестный продукт деградирует к foodId

    func testUnknownFoodFallsBackToFoodId() {
        let logs = [log("ghost_food", "2026-06-10T08:00:00Z")]
        let service = CalendarService(catalog: catalog, logs: logs, calendar: utc)
        XCTAssertEqual(service.day(date("2026-06-10T08:00:00Z")).entries[0].foodName,
                       "ghost_food")
    }
}
