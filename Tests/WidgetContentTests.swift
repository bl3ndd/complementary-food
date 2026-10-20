import XCTest
@testable import Prikorm

/// Содержимое виджетов. Ошибка здесь тихая и публичная: на домашнем экране висит
/// не тот продукт, чужой прогресс или «совет», которого приложение не даёт.
final class WidgetContentTests: XCTestCase {

    private var cal = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_700_000_000)   // 14.11.2023 22:13 UTC

    override func setUp() {
        super.setUp()
        cal.timeZone = TimeZone(identifier: "UTC")!
    }

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let base = cal.date(byAdding: .day, value: offset, to: now)!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    private let profile = FeedingProfile(id: "test", name: "Test", startAgeMonths: 6,
                                         observationDaysRegular: 2, observationDaysAllergen: 3,
                                         allergenFrequencyPerWeek: 2, allergenGroups: [])

    private func food(_ id: String, allergen: Bool = false) -> Food {
        Food(id: id, name: id.capitalized, category: .vegetable, emoji: "🥦",
             isAllergen: allergen, allergenGroup: nil, minAgeMonths: 6)
    }

    private func status(_ id: String, _ state: IntroState, started: Date? = nil) -> IntroductionStatus {
        let s = IntroductionStatus(foodId: id, state: state)
        s.introStartedAt = started
        return s
    }

    private func content(statuses: [IntroductionStatus], logs: [FoodLog],
                         foods: [Food], isPro: Bool = true) -> WidgetContent {
        WidgetContent(catalog: FoodCatalog(foods: foods), profile: profile,
                      statuses: statuses, logs: logs, isPro: isPro, now: now, calendar: cal,
                      icon: { Data($0.id.utf8) })
    }

    // MARK: - Pro

    func testWithoutProSnapshotIsLockedAndCarriesNoDiary() {
        let snap = content(statuses: [status("apple", .introduced),
                                      status("pear", .introducing, started: day(-1))],
                           logs: [FoodLog(foodId: "plum", date: day(1), planned: true)],
                           foods: [food("apple"), food("pear"), food("plum")],
                           isPro: false).snapshot()

        XCTAssertEqual(snap.locked, true)
        XCTAssertTrue(snap.items.isEmpty, "без Pro дневник не должен утекать на домашний экран")
        XCTAssertEqual(snap.introducing ?? [], [])
        XCTAssertEqual(snap.planned ?? [], [])
    }

    func testWithProSnapshotIsUnlocked() {
        let snap = content(statuses: [status("apple", .introduced)], logs: [],
                           foods: [food("apple")]).snapshot()
        XCTAssertEqual(snap.locked, false)
        XCTAssertEqual(snap.items.map(\.id), ["apple"])
        XCTAssertEqual(snap.items.first?.icon, Data("apple".utf8), "иконка — из отрисовщика")
    }

    // MARK: - Сейчас вводишь

    func testIntroducingCountsFeedingDaysAndCapsAtWindow() {
        let statuses = [status("pear", .introducing, started: day(-3)),
                        status("egg", .introducing, started: day(-2))]
        let logs = [
            FoodLog(foodId: "pear", date: day(-3)),
            FoodLog(foodId: "pear", date: day(-3, hour: 18)),   // тот же день — не считается дважды
            FoodLog(foodId: "egg", date: day(-2)),
            FoodLog(foodId: "egg", date: day(-1)),
            FoodLog(foodId: "egg", date: day(0)),
            FoodLog(foodId: "egg", date: day(0, hour: 9)),
        ]
        let intros = content(statuses: statuses, logs: logs,
                             foods: [food("pear"), food("egg", allergen: true)]).introducing()

        XCTAssertEqual(intros.map(\.item.id), ["pear", "egg"], "раньше начатое — первым")
        XCTAssertEqual(intros[0].done, 1)
        XCTAssertEqual(intros[0].window, 2)
        XCTAssertEqual(intros[1].done, 3)
        XCTAssertEqual(intros[1].window, 3, "у аллергена своё окно")
    }

    func testIntroducingIsCappedAtLimit() {
        let statuses = (1...5).map { status("f\($0)", .introducing, started: day(-$0)) }
        let intros = content(statuses: statuses, logs: [],
                             foods: (1...5).map { food("f\($0)") }).introducing()
        XCTAssertEqual(intros.count, WidgetSnapshot.introLimit)
        XCTAssertEqual(intros.first?.item.id, "f5", "самый давний ввод — первым")
    }

    // MARK: - Дальше по плану

    func testPlannedIsOnlyUsersOwnFuturePlanSortedAndDeduped() {
        let logs = [
            FoodLog(foodId: "plum", date: day(3), planned: true),
            FoodLog(foodId: "pear", date: day(1), planned: true),
            FoodLog(foodId: "pear", date: day(2), planned: true),   // дубль продукта
            FoodLog(foodId: "kiwi", date: day(-2), planned: true),  // просроченный план
            FoodLog(foodId: "apple", date: day(1)),                 // не план, а кормление
        ]
        let planned = content(statuses: [], logs: logs,
                              foods: ["plum", "pear", "kiwi", "apple"].map { food($0) }).planned()

        XCTAssertEqual(planned.map(\.item.id), ["pear", "plum"])
        XCTAssertEqual(planned.first?.date, day(1))
    }

    func testPlanForLaterTodayStillShows() {
        let logs = [FoodLog(foodId: "pear", date: day(0, hour: 1), planned: true)]
        let planned = content(statuses: [], logs: logs, foods: [food("pear")]).planned()
        XCTAssertEqual(planned.map(\.item.id), ["pear"], "план на сегодня — ещё «дальше»")
    }

    // MARK: - Совместимость

    func testSnapshotFromPreviousVersionStillDecodes() throws {
        // Снимок прошлой версии: без имён, иконок, ввода, плана и замка.
        let old = #"{"items":[{"id":"apple","emoji":"🍎"}],"total":1,"updatedAt":721000000}"#
        let snap = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(old.utf8))
        XCTAssertEqual(snap.items.map(\.id), ["apple"])
        XCTAssertNil(snap.locked)
        XCTAssertNil(snap.introducing)
    }
}
