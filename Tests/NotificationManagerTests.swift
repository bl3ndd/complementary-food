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
            removed = identifiers
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

        let requests = manager.requests(for: groups)

        XCTAssertEqual(requests.map(\.identifier), ["allergen-egg", "allergen-dairy"])
    }

    // MARK: - Триггер: еженедельный повтор по дню недели nextDue

    func testTriggerIsWeeklyRecurringOnNextDueWeekday() throws {
        let manager = NotificationManager(center: MockCenter())
        let due = Calendar.current.date(byAdding: .day, value: 4, to: now)!
        let groups = [group(.egg, introduced: true, allergy: false,
                            status: .overdue, nextDue: due)]

        let request = try XCTUnwrap(manager.requests(for: groups).first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)

        XCTAssertTrue(trigger.repeats, "напоминание должно повторяться еженедельно")
        XCTAssertEqual(trigger.dateComponents.weekday,
                       Calendar.current.component(.weekday, from: due))
        XCTAssertEqual(trigger.dateComponents.hour, 10)
        XCTAssertEqual(trigger.dateComponents.minute, 0)
        // Только день недели + время → недельный цикл (нет года/месяца/числа).
        XCTAssertNil(trigger.dateComponents.day)
        XCTAssertNil(trigger.dateComponents.month)
    }

    // MARK: - apply: снимает старые allergen-, ставит новые, чужие не трогает

    func testApplyClearsStaleAllergenRequestsAndSchedulesNew() async {
        let center = MockCenter()
        center.pending = ["allergen-egg", "allergen-old", "other-reminder"]
        let manager = NotificationManager(center: center)

        let groups = [group(.dairy, introduced: true, allergy: false,
                            status: .overdue, nextDue: now)]
        await manager.apply(groups)

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

        await manager.apply([
            group(.fish, introduced: true, allergy: false, status: .ok, nextDue: now)
        ])

        XCTAssertTrue(center.added.isEmpty)
    }
}
