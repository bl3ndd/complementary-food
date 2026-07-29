import XCTest
import UserNotifications
@testable import Prikorm

/// Тесты планировщика напоминаний о поддержке аллергенов (Task 6):
/// одна заявка на каждую «просроченную/скоро» введённую группу, пропуск
/// ok/аллергия/не введён, корректный еженедельный повторяющийся триггер.
/// Системный центр заменён моком через протокол `NotificationScheduling`.
final class NotificationManagerTests: XCTestCase {

    /// Мок центра уведомлений: записывает добавленные/снятые заявки.
    private final class MockCenter: NotificationScheduling {
        var pending: [String] = []
        private(set) var added: [UNNotificationRequest] = []
        private(set) var removed: [String] = []

        func pendingIdentifiers() async -> [String] { pending }

        func removePending(identifiers: [String]) {
            removed.append(contentsOf: identifiers)
            pending.removeAll { identifiers.contains($0) }
        }

        func add(_ request: UNNotificationRequest) {
            added.append(request)
            pending.append(request.identifier)
        }
    }

    /// Фиксированная «сейчас» — без зависимости от системного времени.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func group(_ g: AllergenGroup,
                       introduced: Bool,
                       allergy: Bool,
                       status: AllergenStatus,
                       nextDue: Date?) -> AllergenGroupStatus {
        AllergenGroupStatus(group: g, foods: [], representativeFood: nil,
                            isIntroduced: introduced, hasAllergy: allergy,
                            lastGiven: nextDue, status: status, nextDue: nextDue)
    }

    // MARK: - Одна заявка на каждую «пора/скоро» группу, пропуск остальных

    func testRequestsOnePerDueGroupSkippingOthers() {
        let manager = NotificationManager(center: MockCenter())
        let groups = [
            group(.egg,    introduced: true,  allergy: false, status: .overdue, nextDue: now),
            group(.dairy,  introduced: true,  allergy: false, status: .dueSoon, nextDue: now),
            group(.fish,   introduced: true,  allergy: false, status: .ok,      nextDue: now), // пропуск: ok
            group(.peanut, introduced: true,  allergy: true,  status: .overdue, nextDue: now), // пропуск: аллергия
            group(.soy,    introduced: false, allergy: false, status: .overdue, nextDue: nil), // пропуск: не введён
        ]

        let requests = manager.requests(for: groups, intervalDays: 4)

        XCTAssertEqual(requests.map(\.identifier), ["allergen-egg", "allergen-dairy"])
    }

    // MARK: - Текст уведомления не палит конкретный аллерген на локскрине (4.5.4)

    func testNotificationBodyIsNonSensitive() {
        let manager = NotificationManager(center: MockCenter())
        let groups = [
            group(.egg, introduced: true, allergy: false, status: .overdue, nextDue: now),
        ]

        let content = manager.requests(for: groups, intervalDays: 4)[0].content
        // Не должно называть конкретную группу аллергена.
        for g in AllergenGroup.allCases {
            XCTAssertFalse(content.body.localizedCaseInsensitiveContains(g.title),
                           "тело уведомления не должно называть аллерген «\(g.title)»")
        }
        XCTAssertFalse(content.body.isEmpty)
    }

    // MARK: - Триггер: еженедельный повтор по дню недели nextDue

    /// `now` инжектим: без него тест зависел от текущего дня недели и проходил
    /// примерно раз в семь дней (просроченный срок якорится к «сегодня» — B8).
    func testTriggerIsWeeklyRecurringOnNextDueWeekday() throws {
        let manager = NotificationManager(center: MockCenter())
        let due = Calendar.current.date(byAdding: .day, value: 4, to: now)!
        let groups = [group(.egg, introduced: true, allergy: false,
                            status: .dueSoon, nextDue: due)]

        let request = try XCTUnwrap(
            manager.requests(for: groups, intervalDays: 4, now: now).first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)

        XCTAssertTrue(trigger.repeats, "напоминание должно повторяться еженедельно")
        XCTAssertEqual(trigger.dateComponents.weekday,
                       Calendar.current.component(.weekday, from: due),
                       "срок в будущем → день недели берём от него")
        XCTAssertEqual(trigger.dateComponents.hour, 10)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        // Только день недели + время → недельный цикл (нет года/месяца/числа).
        XCTAssertNil(trigger.dateComponents.day)
        XCTAssertNil(trigger.dateComponents.month)
    }

    /// B8: если срок уже прошёл, день недели берём от «сегодня», иначе первый пуш
    /// прилетит только через неделю.
    func testOverdueTriggerAnchorsToTodayNotPastDueDate() throws {
        let manager = NotificationManager(center: MockCenter())
        let overdue = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let groups = [group(.egg, introduced: true, allergy: false,
                            status: .overdue, nextDue: overdue)]

        let request = try XCTUnwrap(
            manager.requests(for: groups, intervalDays: 4, now: now).first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)

        XCTAssertEqual(trigger.dateComponents.weekday,
                       Calendar.current.component(.weekday, from: now),
                       "просрочка не должна ждать неделю до своего старого дня")
    }

    // MARK: - Триггер: ежедневный повтор для дневного аллергена (interval 1)

    func testTriggerIsDailyForDailyPlan() throws {
        let manager = NotificationManager(center: MockCenter())
        let groups = [group(.egg, introduced: true, allergy: false, status: .overdue, nextDue: now)]

        let request = try XCTUnwrap(manager.requests(for: groups, intervalDays: 1).first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)

        XCTAssertTrue(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 10)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        // Только время (без weekday/дня) → ежедневный цикл.
        XCTAssertNil(trigger.dateComponents.weekday, "дневной план → без привязки к дню недели")
        XCTAssertNil(trigger.dateComponents.day)
    }

    // MARK: - Deep-link: извлечение foodId из id пуша

    func testDeepLinkFoodIdExtraction() {
        XCTAssertEqual(NotificationRouter.foodId(fromNotificationId: "retry-broccoli"), "broccoli")
        XCTAssertEqual(NotificationRouter.foodId(fromNotificationId: "intro-broccoli-3"), "broccoli")
        // foodId своих продуктов содержит дефисы — режем только хвост «-<день>».
        XCTAssertEqual(NotificationRouter.foodId(fromNotificationId: "intro-custom-3F2A-uuid-2"),
                       "custom-3F2A-uuid")
        XCTAssertNil(NotificationRouter.foodId(fromNotificationId: "allergen-egg"))
    }

    // MARK: - apply: снимает старые allergen-, ставит новые, чужие не трогает

    func testApplyClearsStaleAllergenRequestsAndSchedulesNew() async {
        let center = MockCenter()
        center.pending = ["allergen-egg", "allergen-old", "other-reminder"]
        let manager = NotificationManager(center: center)

        let groups = [group(.dairy, introduced: true, allergy: false,
                            status: .overdue, nextDue: now)]
        await manager.apply(manager.requests(for: groups, intervalDays: 4))

        // Сняты только наши старые идентификаторы, чужой остался нетронутым.
        XCTAssertEqual(Set(center.removed), ["allergen-egg", "allergen-old"])
        XCTAssertFalse(center.removed.contains("other-reminder"))

        // Поставлена ровно одна новая заявка по группе.
        XCTAssertEqual(center.added.map(\.identifier), ["allergen-dairy"])
        XCTAssertTrue(center.pending.contains("other-reminder"))
        XCTAssertTrue(center.pending.contains("allergen-dairy"))
    }

    // MARK: - Пустой ввод → ничего не планируется

    func testApplyWithNoDueGroupsSchedulesNothing() async {
        let center = MockCenter()
        let manager = NotificationManager(center: center)

        await manager.apply(manager.requests(for: [
            group(.fish, introduced: true, allergy: false, status: .ok, nextDue: now)
        ], intervalDays: 4))

        XCTAssertTrue(center.added.isEmpty)
    }

    // MARK: - Окно ввода: ежедневные напоминания (intro-)

    private func utcCal() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func at(_ day: Int, _ hour: Int, _ cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour))!
    }

    /// Напоминаний столько, сколько дней с кормлением ещё не набрано.
    func testIntroRequestsCoverRemainingFeedingDays() {
        let cal = utcCal()
        let s = IntroductionStatus(foodId: "broccoli", state: .introducing)
        s.introStartedAt = at(10, 8, cal)               // старт: 10-е, 08:00
        // Одно кормление уже записано (день старта) → остаётся два дня из трёх.
        let logs = [FoodLog(foodId: "broccoli", date: at(10, 8, cal), type: .intro)]
        let reqs = NotificationManager(center: MockCenter())
            .introRequests(statuses: [s], observationDays: 3, logs: logs,
                           now: at(10, 9, cal), calendar: cal)

        XCTAssertEqual(reqs.count, 2, "осталось два дня — два напоминания")
        for r in reqs {
            XCTAssertEqual((r.trigger as? UNCalendarNotificationTrigger)?.repeats, false)
        }
    }

    /// Сегодня продукт уже давали — сегодняшнее напоминание не нужно, начинаем с завтра
    /// (день засчитывается один раз, сколько бы кормлений в нём ни было).
    func testIntroRequestsStartTomorrowWhenAlreadyFedToday() throws {
        let cal = utcCal()
        let s = IntroductionStatus(foodId: "broccoli", state: .introducing)
        s.introStartedAt = at(10, 8, cal)
        let logs = [FoodLog(foodId: "broccoli", date: at(10, 8, cal), type: .intro)]
        let reqs = NotificationManager(center: MockCenter())
            .introRequests(statuses: [s], observationDays: 2, logs: logs,
                           now: at(10, 9, cal), calendar: cal)

        let first = try XCTUnwrap(reqs.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(reqs.count, 1, "остался один день")
        XCTAssertEqual(first.dateComponents.day, 11, "напоминание — на завтра, не на сегодня")
    }

    /// Норма набрана — напоминания не ставим вовсе.
    func testIntroRequestsEmptyWhenEnoughFeedingDays() {
        let cal = utcCal()
        let s = IntroductionStatus(foodId: "broccoli", state: .introducing)
        s.introStartedAt = at(10, 8, cal)
        let logs = [FoodLog(foodId: "broccoli", date: at(10, 8, cal), type: .intro),
                    FoodLog(foodId: "broccoli", date: at(11, 19, cal), type: .intro)]
        let reqs = NotificationManager(center: MockCenter())
            .introRequests(statuses: [s], observationDays: 2, logs: logs,
                           now: at(11, 20, cal), calendar: cal)

        XCTAssertTrue(reqs.isEmpty)
    }

    func testIntroRequestsIgnoreNonIntroducing() {
        let cal = utcCal()
        let s = IntroductionStatus(foodId: "broccoli", state: .introduced)
        s.introStartedAt = at(10, 8, cal)
        let reqs = NotificationManager(center: MockCenter())
            .introRequests(statuses: [s], observationDays: 3, now: at(10, 8, cal), calendar: cal)

        XCTAssertTrue(reqs.isEmpty)
    }

    // MARK: - retry-: одноразовое напоминание «попробовать снова»

    func testRetryRequestsBuildOneShotForFutureRetryDateOnly() {
        let cal = utcCal()
        let future = IntroductionStatus(foodId: "egg", state: .paused)
        future.retryAt = at(20, 9, cal)               // в будущем → ставим
        let past = IntroductionStatus(foodId: "fish", state: .paused)
        past.retryAt = at(1, 9, cal)                  // в прошлом → пропуск
        let none = IntroductionStatus(foodId: "soy", state: .paused) // retryAt nil → пропуск

        let reqs = NotificationManager(center: MockCenter())
            .retryRequests(statuses: [future, past, none], now: at(10, 8, cal), calendar: cal)

        XCTAssertEqual(reqs.map(\.identifier), ["retry-egg"])
        let trigger = reqs.first?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.repeats, false)
        XCTAssertEqual(trigger?.dateComponents.day, 20)
        XCTAssertEqual(trigger?.dateComponents.hour, 10)
    }
}
