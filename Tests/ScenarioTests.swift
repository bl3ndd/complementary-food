import XCTest
import SwiftData
import UserNotifications
@testable import Prikorm

/// Сквозные (e2e-логические) сценарии: реальный in-memory `ModelContainer` +
/// настоящие сервисы (`FeedingService`, `AllergenMaintenance`,
/// `NotificationManager`) + реальный каталог `FoodCatalog.shared`.
/// Карта сценариев — `docs/TEST-CASES.md` (группа E).
final class ScenarioTests: XCTestCase {

    private let catalog = FoodCatalog.shared
    /// Держим контейнер живым на время теста — иначе `ModelContext` повисает и
    /// фетч ловит трап SwiftData (Swift 6.3).
    private var container: ModelContainer!

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Child.self, IntroductionStatus.self, FoodLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }

    private func food(_ id: String) throws -> Food {
        try XCTUnwrap(catalog.food(id: id), "в каталоге нет продукта \(id)")
    }

    private func fetchStatuses(_ ctx: ModelContext) -> [IntroductionStatus] {
        (try? ctx.fetch(FetchDescriptor<IntroductionStatus>())) ?? []
    }
    private func fetchLogs(_ ctx: ModelContext) -> [FoodLog] {
        (try? ctx.fetch(FetchDescriptor<FoodLog>())) ?? []
    }

    // MARK: - E1: новый овощ проходит весь путь до «введён»

    @MainActor
    func testE1_VegetableFullPathToIntroduced() throws {
        let ctx = try makeContext()
        let service = FeedingService(context: ctx)
        let broccoli = try food("broccoli")

        service.startIntroduction(broccoli)
        let s = service.status(for: broccoli.id)
        XCTAssertEqual(s.state, .introducing)
        let start = try XCTUnwrap(s.introStartedAt)

        // Окно ещё идёт — завершать рано (B4/B2).
        XCTAssertFalse(FeedingService.isObservationComplete(
            start: start, observationDays: 3, now: start))

        // Прошло окно — теперь можно завершить (B3).
        let after = Calendar.current.date(byAdding: .day, value: 3, to: start)!
        XCTAssertTrue(FeedingService.isObservationComplete(
            start: start, observationDays: 3, now: after))

        service.completeIntroduction(broccoli)
        XCTAssertEqual(service.status(for: broccoli.id).state, .introduced)
        XCTAssertNotNil(service.status(for: broccoli.id).completedAt)
    }

    // MARK: - E2: реакция при вводе аллергена → пауза, не «введён»

    @MainActor
    func testE2_ReactionDuringIntroPausesNotIntroduced() throws {
        let ctx = try makeContext()
        let service = FeedingService(context: ctx)
        let egg = try food("egg_yolk")

        service.startIntroduction(egg)
        service.logFeeding(egg, liking: nil, reaction: .skin)

        let state = service.status(for: egg.id).state
        XCTAssertEqual(state, .paused)
        XCTAssertNotEqual(state, .introduced)
    }

    // MARK: - E3: введённый аллерген без поддержки → due → строится напоминание

    @MainActor
    func testE3_IntroducedAllergenBecomesDueAndSchedules() throws {
        let ctx = try makeContext()
        let service = FeedingService(context: ctx)
        let egg = try food("egg_yolk")

        // Введён и завершён (логи создаются «сегодня»).
        service.startIntroduction(egg)
        service.completeIntroduction(egg)

        // Смотрим спустя 10 дней без поддержки → аллерген пора освежить.
        let later = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let maintenance = AllergenMaintenance(
            catalog: catalog, profile: .who,
            statuses: fetchStatuses(ctx), logs: fetchLogs(ctx), now: later)
        let due = maintenance.dueForDashboard()
        XCTAssertTrue(due.contains { $0.group == .egg },
                      "группа egg должна быть «пора дать»")

        // На основе due строится ровно одна заявка уведомления.
        let requests = NotificationManager(center: NoopCenter())
            .requests(for: due)
        XCTAssertTrue(requests.contains { $0.identifier == "allergen-egg" })
    }

    // MARK: - E4: аллергия на введённый → реинтродукция врачом

    @MainActor
    func testE4_AllergyThenReintroduce() throws {
        let ctx = try makeContext()
        let service = FeedingService(context: ctx)
        let egg = try food("egg_yolk")

        service.startIntroduction(egg)
        service.completeIntroduction(egg)
        service.logFeeding(egg, liking: nil, reaction: .skin)   // реакция на введённый
        XCTAssertEqual(service.status(for: egg.id).state, .allergy)

        service.reintroduce(egg)
        let s = service.status(for: egg.id)
        XCTAssertEqual(s.state, .introducing)
        XCTAssertNil(s.completedAt)
    }

    /// Заглушка центра уведомлений (E3 строит заявки, планировать не нужно).
    private final class NoopCenter: NotificationScheduling {
        func pendingIdentifiers() async -> [String] { [] }
        func removePending(identifiers: [String]) {}
        func add(_ request: UNNotificationRequest) {}
    }
}
