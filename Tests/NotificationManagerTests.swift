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

    // MARK: - Поддержка: заранее на дату по плану, для каждой введённой группы

    func testRequestsForEveryIntroducedGroupIncludingOkSkippingOthers() {
        let manager = NotificationManager(center: MockCenter())
        let groups = [
            group(.egg,    introduced: true,  allergy: false, status: .overdue, nextDue: now),
            group(.fish,   introduced: true,  allergy: false, status: .ok,      nextDue: now), // «в норме» — тоже: заранее
            group(.peanut, introduced: true,  allergy: true,  status: .overdue, nextDue: now), // пропуск: аллергия
            group(.soy,    introduced: false, allergy: false, status: .overdue, nextDue: nil), // пропуск: не введён
        ]

        let requests = manager.requests(for: groups, now: now)

        XCTAssertEqual(requests.map(\.identifier),
                       ["allergen-egg-0", "allergen-egg-1", "allergen-fish-0", "allergen-fish-1"],
                       "на срок по плану и повтор через два дня; аллергия и невведённые — без напоминаний")
    }

    // MARK: - Текст уведомления не палит конкретный аллерген на локскрине (4.5.4)

    func testNotificationBodyIsNonSensitive() {
        let manager = NotificationManager(center: MockCenter())
        let groups = [
            group(.egg, introduced: true, allergy: false, status: .overdue, nextDue: now),
        ]

        let content = manager.requests(for: groups, now: now)[0].content
        for g in AllergenGroup.allCases {
            XCTAssertFalse(content.body.localizedCaseInsensitiveContains(g.title),
                           "тело уведомления не должно называть аллерген «\(g.title)»")
        }
        XCTAssertFalse(content.body.isEmpty)
    }

    // MARK: - Триггер: одноразовый, на день срока, 10:00

    private func fireDate(_ r: UNNotificationRequest) -> Date? {
        (r.trigger as? UNCalendarNotificationTrigger).flatMap {
            Calendar.current.date(from: $0.dateComponents)
        }
    }

    /// Срок в будущем → напоминание именно в этот день, а не когда человек сам
    /// откроет приложение (раньше строилось только для уже просроченных групп).
    func testFutureDueSchedulesOneShotOnDueDay() throws {
        let manager = NotificationManager(center: MockCenter())
        let due = Calendar.current.date(byAdding: .day, value: 4, to: now)!
        let groups = [group(.egg, introduced: true, allergy: false, status: .ok, nextDue: due)]

        let requests = manager.requests(for: groups, now: now)
        let first = try XCTUnwrap(requests.first)
        let trigger = try XCTUnwrap(first.trigger as? UNCalendarNotificationTrigger)

        XCTAssertFalse(trigger.repeats)
        XCTAssertEqual(trigger.dateComponents.hour, 10)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        XCTAssertTrue(Calendar.current.isDate(try XCTUnwrap(fireDate(first)), inSameDayAs: due))
        let second = try XCTUnwrap(fireDate(requests[1]))
        XCTAssertEqual(Calendar.current.dateComponents([.day], from: try XCTUnwrap(fireDate(first)),
                                                       to: second).day, 2)
    }

    /// Просрочено → ближайшие 10:00 в будущем, а не дата в прошлом (её iOS не покажет).
    func testOverdueFiresAtNextTenInFuture() throws {
        let manager = NotificationManager(center: MockCenter())
        let overdue = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let groups = [group(.egg, introduced: true, allergy: false, status: .overdue, nextDue: overdue)]

        let fire = try XCTUnwrap(fireDate(try XCTUnwrap(manager.requests(for: groups, now: now).first)))
        XCTAssertGreaterThan(fire, now)
        XCTAssertLessThanOrEqual(fire.timeIntervalSince(now), 24 * 3600, "не позже чем через сутки")
    }

    // MARK: - Deep-link: извлечение foodId из id пуша

    func testDeepLinkFoodIdExtraction() {
        XCTAssertEqual(NotificationRouter.foodId(fromNotificationId: "retry-broccoli"), "broccoli")
        XCTAssertEqual(NotificationRouter.foodId(fromNotificationId: "intro-broccoli-3"), "broccoli")
        // foodId своих продуктов содержит дефисы — режем только хвост «-<день>».
        XCTAssertEqual(NotificationRouter.foodId(fromNotificationId: "intro-custom-3F2A-uuid-2"),
                       "custom-3F2A-uuid")
        XCTAssertNil(NotificationRouter.foodId(fromNotificationId: "allergen-egg"))
        // Новый формат с тегом ребёнка.
        XCTAssertEqual(NotificationRouter.foodId(fromNotificationId: "retry-1A2B3C4D-broccoli"), "broccoli")
        XCTAssertEqual(NotificationRouter.foodId(fromNotificationId: "intro-1A2B3C4D-custom-3F2A-uuid-2"),
                       "custom-3F2A-uuid")
        XCTAssertEqual(NotificationRouter.childTag(fromNotificationId: "allergen-1A2B3C4D-egg-0"), "1A2B3C4D")
        XCTAssertNil(NotificationRouter.childTag(fromNotificationId: "retry-broccoli"),
                     "у пушей прошлых версий тега нет")
    }

    // MARK: - apply: снимает старые allergen-, ставит новые, чужие не трогает

    func testApplyClearsStaleAllergenRequestsAndSchedulesNew() async {
        let center = MockCenter()
        center.pending = ["allergen-egg", "allergen-old", "other-reminder"]
        let manager = NotificationManager(center: center)

        let groups = [group(.dairy, introduced: true, allergy: false,
                            status: .overdue, nextDue: now)]
        await manager.apply(manager.requests(for: groups, now: now))

        // Сняты только наши старые идентификаторы, чужой остался нетронутым.
        XCTAssertEqual(Set(center.removed), ["allergen-egg", "allergen-old"])
        XCTAssertFalse(center.removed.contains("other-reminder"))

        XCTAssertEqual(center.added.map(\.identifier), ["allergen-dairy-0", "allergen-dairy-1"])
        XCTAssertTrue(center.pending.contains("other-reminder"))
    }

    // MARK: - Пустой ввод → ничего не планируется

    func testApplyWithNoIntroducedGroupsSchedulesNothing() async {
        let center = MockCenter()
        let manager = NotificationManager(center: center)

        await manager.apply(manager.requests(for: [
            group(.fish, introduced: false, allergy: false, status: .ok, nextDue: nil)
        ], now: now))

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

    /// Напоминаний — сколько дней ещё не набрано, плюс два про запас: раньше после
    /// пропущенного дня напоминания просто кончались.
    func testIntroRequestsCoverRemainingFeedingDaysPlusSpare() {
        let cal = utcCal()
        let s = IntroductionStatus(foodId: "broccoli", state: .introducing)
        s.introStartedAt = at(10, 8, cal)               // старт: 10-е, 08:00
        // Одно кормление уже записано (день старта) → остаётся два дня из трёх.
        let logs = [FoodLog(foodId: "broccoli", date: at(10, 8, cal), type: .intro)]
        let reqs = NotificationManager(center: MockCenter())
            .introRequests(statuses: [s], observationDays: 3, logs: logs,
                           now: at(10, 9, cal), calendar: cal)

        XCTAssertEqual(reqs.count, 4, "осталось два дня — два напоминания и два про запас")
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
        XCTAssertEqual(reqs.count, 3, "остался один день + запас")
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
