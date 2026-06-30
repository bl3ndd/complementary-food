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

    // MARK: - Планирование на будущее (п.21)

    func testPlannedFutureLogAppearsAsPlannedDay() {
        let planned = FoodLog(foodId: "broccoli", date: date("2026-07-01T09:00:00Z"),
                              type: .intro, planned: true)
        let service = CalendarService(catalog: catalog, logs: [planned], calendar: utc)

        let day = service.day(date("2026-07-01T12:00:00Z"))
        XCTAssertTrue(day.hasActivity)
        XCTAssertTrue(day.hasPlanned)
        XCTAssertTrue(day.isPlannedOnly)
        XCTAssertFalse(day.hasReaction, "план — не реакция")
        XCTAssertTrue(service.activeDays().contains(date("2026-07-01T00:00:00Z")))
    }

    // MARK: - Неизвестный продукт деградирует к foodId

    func testUnknownFoodFallsBackToFoodId() {
        let logs = [log("ghost_food", "2026-06-10T08:00:00Z")]
        let service = CalendarService(catalog: catalog, logs: logs, calendar: utc)
        XCTAssertEqual(service.day(date("2026-06-10T08:00:00Z")).entries[0].foodName,
                       "ghost_food")
    }

    // MARK: - Лента-дневник: фильтр-линза (Concept A)

    private func mixedFeedLogs() -> [FoodLog] {
        [
            log("broccoli", "2026-06-10T08:00:00Z", type: .intro),
            log("egg_yolk", "2026-06-11T09:00:00Z", type: .maintenance),
            log("egg_yolk", "2026-06-12T09:00:00Z", reaction: .skin),
            FoodLog(foodId: "broccoli", date: date("2026-07-01T09:00:00Z"),
                    type: .intro, planned: true),
        ]
    }

    func testFeedAllReturnsEveryDayNewestFirst() {
        let service = CalendarService(catalog: catalog, logs: mixedFeedLogs(), calendar: utc)
        let feed = service.feed()
        XCTAssertEqual(feed.count, 4)
        // План в июле — самый новый день, сверху.
        XCTAssertEqual(utc.component(.month, from: feed[0].date), 7)
        XCTAssertEqual(utc.component(.day, from: feed[3].date), 10)
    }

    func testFeedFilterIntroExcludesMaintenanceReactionAndPlanned() {
        let service = CalendarService(catalog: catalog, logs: mixedFeedLogs(), calendar: utc)
        let feed = service.feed(filter: .intro)
        // Только фактический ввод брокколи 10-го (план/поддержка/реакция отброшены).
        XCTAssertEqual(feed.count, 1)
        XCTAssertEqual(utc.component(.day, from: feed[0].date), 10)
        XCTAssertFalse(feed[0].entries[0].planned)
    }

    func testFeedFilterMaintenanceKeepsOnlyMaintenance() {
        let service = CalendarService(catalog: catalog, logs: mixedFeedLogs(), calendar: utc)
        let feed = service.feed(filter: .maintenance)
        XCTAssertEqual(feed.count, 1)
        XCTAssertEqual(feed[0].entries[0].type, .maintenance)
    }

    func testFeedFilterReactionKeepsOnlyReactions() {
        let service = CalendarService(catalog: catalog, logs: mixedFeedLogs(), calendar: utc)
        let feed = service.feed(filter: .reaction)
        XCTAssertEqual(feed.count, 1)
        XCTAssertEqual(feed[0].entries[0].reaction, .skin)
    }

    func testFeedFilterPlannedKeepsOnlyPlans() {
        let service = CalendarService(catalog: catalog, logs: mixedFeedLogs(), calendar: utc)
        let feed = service.feed(filter: .planned)
        XCTAssertEqual(feed.count, 1)
        XCTAssertTrue(feed[0].entries[0].planned)
        XCTAssertEqual(utc.component(.month, from: feed[0].date), 7)
    }

    // MARK: - Лента-дневник: текстовый поиск

    func testFeedQueryMatchesCanonicalFoodName() {
        let service = CalendarService(catalog: catalog, logs: mixedFeedLogs(), calendar: utc)
        // Канонические имена русские независимо от языка симулятора.
        let feed = service.feed(query: "брокк")
        XCTAssertEqual(feed.count, 2, "оба лога брокколи: факт 10-го и план в июле")
        XCTAssertTrue(feed.allSatisfy { $0.entries.allSatisfy { $0.foodName == "Брокколи" } })
    }

    func testFeedQueryMatchesNoteText() {
        var logs = mixedFeedLogs()
        logs.append(log("egg_yolk", "2026-06-15T08:00:00Z"))
        logs[logs.count - 1].note = "съел половину"
        let service = CalendarService(catalog: catalog, logs: logs, calendar: utc)
        let feed = service.feed(query: "полов")
        XCTAssertEqual(feed.count, 1)
        XCTAssertEqual(utc.component(.day, from: feed[0].date), 15)
    }

    func testFeedQueryNoMatchReturnsEmpty() {
        let service = CalendarService(catalog: catalog, logs: mixedFeedLogs(), calendar: utc)
        XCTAssertTrue(service.feed(query: "несуществует").isEmpty)
    }

    // MARK: - Журнал реакций «для педиатра»

    func testReactionsListsOnlyReactionsNewestFirst() {
        let logs = [
            log("broccoli", "2026-06-10T08:00:00Z"),                    // без реакции
            log("egg_yolk", "2026-06-11T09:00:00Z", reaction: .skin),
            log("egg_yolk", "2026-06-13T09:00:00Z", reaction: .gi),
            FoodLog(foodId: "broccoli", date: date("2026-07-01T09:00:00Z"),
                    type: .intro, reaction: .skin, planned: true),     // план — не считается
        ]
        let service = CalendarService(catalog: catalog, logs: logs, calendar: utc)
        let reactions = service.reactions()
        XCTAssertEqual(reactions.count, 2, "только фактические реакции, без планов")
        XCTAssertEqual(reactions[0].reaction, .gi, "новые сверху")
        XCTAssertEqual(reactions[1].reaction, .skin)
    }
}
