import XCTest
import SwiftData
import UserNotifications
@testable import Prikorm

/// Логика, которую нашёл аудит 20.10.2026. Каждый тест — сценарий, в котором
/// приложение раньше «врало» родителю: чужие кормления, реакция как успех,
/// запись с главной без ввода, правка без пересчёта.
final class AuditFixesTests: XCTestCase {

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchemaCurrent.models)
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    }

    /// Продукты из настоящего каталога: свипер ищет их в `FoodCatalog.shared`.
    private let regular = FoodCatalog.shared.all.first { !$0.isAllergen && !$0.id.hasPrefix("custom-") }!
    private let allergen = FoodCatalog.shared.all.first { $0.isAllergen }!

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    @MainActor
    private func child(_ ctx: ModelContext, regular: Int = 2, allergen: Int = 3) -> Child {
        let c = Child(name: "Ника", birthDate: .now)
        c.customObservationDaysRegular = regular
        c.customObservationDaysAllergen = allergen
        ctx.insert(c)
        try? ctx.save()
        return c
    }

    @MainActor
    private func state(_ ctx: ModelContext, _ foodId: String, _ childId: UUID) -> IntroState? {
        try? ctx.fetch(FetchDescriptor<IntroductionStatus>(
            predicate: #Predicate { $0.foodId == foodId && $0.childId == childId })).first?.state
    }

    // MARK: - Запись с главной начинает ввод

    @MainActor
    func testFirstFeedingOfNewFoodStartsIntroduction() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let kid = child(ctx)
        let service = FeedingService(context: ctx, childId: kid.id)

        service.logFeeding(regular, liking: .liked, reaction: nil, date: day(-1))
        XCTAssertEqual(state(ctx, regular.id, kid.id), .introducing,
                       "первое кормление — это и есть старт ввода")

        service.logFeeding(regular, liking: nil, reaction: nil, date: day(0))
        XCTAssertEqual(state(ctx, regular.id, kid.id), .introduced,
                       "два дня кормлений по плану — продукт введён")
    }

    @MainActor
    func testReactionDoesNotResumePausedFood() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let kid = child(ctx)
        let service = FeedingService(context: ctx, childId: kid.id)
        service.startIntroduction(regular, date: day(-5))
        service.stopIntroduction(regular)

        service.logFeeding(regular, liking: nil, reaction: .skin, date: day(0))
        XCTAssertEqual(state(ctx, regular.id, kid.id), .paused)

        service.logFeeding(regular, liking: nil, reaction: nil, date: day(0))
        XCTAssertEqual(state(ctx, regular.id, kid.id), .introducing, "дали снова — ввод снова идёт")
    }

    // MARK: - Реакция не засчитывается днём ввода

    @MainActor
    func testReactionDayDoesNotCompleteIntroduction() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let kid = child(ctx)
        let service = FeedingService(context: ctx, childId: kid.id)

        service.logFeeding(regular, liking: nil, reaction: nil, date: day(-1))
        service.logFeeding(regular, liking: nil, reaction: .skin, date: day(0))

        XCTAssertEqual(state(ctx, regular.id, kid.id), .introducing,
                       "сыпь на втором дне не должна закрывать ввод с поздравлением")
    }

    // MARK: - Дети не смешиваются

    @MainActor
    func testSiblingFeedingsDoNotCompleteAnotherChildsIntroduction() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let elder = child(ctx)
        let younger = child(ctx)
        let elderService = FeedingService(context: ctx, childId: elder.id)
        let youngerService = FeedingService(context: ctx, childId: younger.id)

        youngerService.logFeeding(regular, liking: nil, reaction: nil, date: day(-3))
        for d in -3...0 { elderService.logFeeding(regular, liking: nil, reaction: nil, date: day(d)) }
        youngerService.completeDueIntroductions(profile: younger.feedingProfile)

        XCTAssertEqual(state(ctx, regular.id, younger.id), .introducing,
                       "кормления старшего не засчитываются младшему")
        XCTAssertEqual(state(ctx, regular.id, elder.id), .introduced)
    }

    @MainActor
    func testEachChildCompletesByOwnPlan() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let first = child(ctx, allergen: 2)
        let second = child(ctx, allergen: 5)
        for kid in [first, second] {
            let service = FeedingService(context: ctx, childId: kid.id)
            for d in -2...0 { service.logFeeding(allergen, liking: nil, reaction: nil, date: day(d)) }
        }
        XCTAssertEqual(state(ctx, allergen.id, first.id), .introduced)
        XCTAssertEqual(state(ctx, allergen.id, second.id), .introducing,
                       "у второго окно аллергена 5 дней — три дня его не закрывают")
    }

    @MainActor
    func testRemindersAreBuiltPerChildWithDistinctIds() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let elder = child(ctx)
        let younger = child(ctx)
        for kid in [elder, younger] {
            FeedingService(context: ctx, childId: kid.id)
                .logFeeding(regular, liking: nil, reaction: nil, date: day(0, hour: 8))
        }
        let statuses = try ctx.fetch(FetchDescriptor<IntroductionStatus>())
        let logs = try ctx.fetch(FetchDescriptor<FoodLog>())
        let manager = NotificationManager(center: AuditNoopCenter())
        let ids = [elder, younger].flatMap { kid in
            manager.requests(forChild: kid.id, profile: kid.feedingProfile,
                             statuses: statuses.filter { $0.childId == kid.id },
                             logs: logs.filter { $0.childId == kid.id }).intro.map(\.identifier)
        }
        XCTAssertFalse(ids.isEmpty)
        XCTAssertEqual(Set(ids).count, ids.count, "напоминания двух детей не перетирают друг друга")
    }

    // MARK: - Правка и удаление пересчитывают статус

    @MainActor
    func testDeletingMistakenLogReopensIntroduction() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let kid = child(ctx)
        let service = FeedingService(context: ctx, childId: kid.id)
        service.logFeeding(regular, liking: nil, reaction: nil, date: day(-1))
        service.logFeeding(regular, liking: nil, reaction: nil, date: day(0))
        XCTAssertEqual(state(ctx, regular.id, kid.id), .introduced)

        let fid = regular.id
        let mistaken = try XCTUnwrap(try ctx.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.foodId == fid }, sortBy: [SortDescriptor(\.date)])).last)
        ctx.delete(mistaken)
        try ctx.save()
        service.revalidate(foodId: regular.id)

        XCTAssertEqual(state(ctx, regular.id, kid.id), .introducing,
                       "ввод, закрытый ошибочной записью, открывается снова")
    }

    @MainActor
    func testRevalidateKeepsIntroducedWhenFedAfterCompletion() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let kid = child(ctx)
        let service = FeedingService(context: ctx, childId: kid.id)
        service.logFeeding(regular, liking: nil, reaction: nil, date: day(-3))
        service.logFeeding(regular, liking: nil, reaction: nil, date: day(-2))
        // Давно введён и его продолжают давать — старую запись удалили.
        let fid = regular.id
        let s = try XCTUnwrap(try ctx.fetch(FetchDescriptor<IntroductionStatus>(
            predicate: #Predicate { $0.foodId == fid })).first)
        s.completedAt = day(-2)
        service.logFeeding(regular, liking: nil, reaction: nil, date: day(0))
        let oldest = try XCTUnwrap(try ctx.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.foodId == fid }, sortBy: [SortDescriptor(\.date)])).first)
        ctx.delete(oldest)
        try ctx.save()
        service.revalidate(foodId: regular.id)

        XCTAssertEqual(state(ctx, regular.id, kid.id), .introduced,
                       "после введения продукт уже давали — статус не откатываем")
    }

    @MainActor
    func testConfirmingPlanCompletesIntroductionImmediately() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let kid = child(ctx)
        let service = FeedingService(context: ctx, childId: kid.id)
        service.logFeeding(regular, liking: nil, reaction: nil, date: day(-1))
        service.plan([regular.id], on: day(0))
        let plan = try XCTUnwrap(try ctx.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.planned })).first)

        service.confirmPlanned(plan, now: day(0, hour: 13))

        XCTAssertEqual(state(ctx, regular.id, kid.id), .introduced,
                       "выполненный план — такое же кормление: ввод закрывается сразу")
    }

    // MARK: - Граница окна — по дню

    func testSameDayFeedingBeforeResumeCounts() {
        let cal = Calendar.current
        let log = FoodLog(foodId: "x", date: day(0, hour: 9))
        XCTAssertTrue(FeedingService.countsForIntro(log, since: day(0, hour: 12), calendar: cal),
                      "дали утром, возобновили днём — день в зачёт")
        let reaction = FoodLog(foodId: "x", date: day(0, hour: 9), reaction: .gi)
        XCTAssertFalse(FeedingService.countsForIntro(reaction, since: day(-1), calendar: cal))
    }

    // MARK: - План с нулевым окном не закрывает ввод мгновенно

    func testZeroObservationDaysAreClampedToOne() {
        let c = Child()
        c.customObservationDaysRegular = 0
        c.customObservationDaysAllergen = 0
        XCTAssertEqual(c.feedingProfile.observationDaysRegular, 1)
        XCTAssertEqual(c.feedingProfile.observationDaysAllergen, 1)
    }

    // MARK: - ProStore слушает транзакции мимо кнопки

    private final class UpdatesMock: ProPurchasing {
        var entitled = false
        let stream: AsyncStream<Void>
        let continuation: AsyncStream<Void>.Continuation
        init() { (stream, continuation) = AsyncStream.makeStream(of: Void.self) }
        func product(id: String) async throws -> ProProduct? { nil }
        func purchase(id: String) async throws -> ProPurchaseOutcome { .pending }
        func isEntitled(to id: String) async -> Bool { entitled }
        func restore() async throws {}
        func transactionUpdates() -> AsyncStream<Void> { stream }
    }

    @MainActor
    func testAskToBuyApprovalUnlocksWithoutRelaunch() async throws {
        let mock = UpdatesMock()
        let defaults = UserDefaults(suiteName: "audit-\(UUID().uuidString)")!
        let store = ProStore(purchasing: mock, defaults: defaults)
        XCTAssertFalse(store.isPurchased)

        mock.entitled = true
        mock.continuation.yield()
        for _ in 0..<50 where !store.isPurchased { try await Task.sleep(for: .milliseconds(20)) }

        XCTAssertTrue(store.isPurchased, "одобрение родителя открывает Pro сразу")
    }
}

private struct AuditNoopCenter: NotificationScheduling {
    func pendingIdentifiers() async -> [String] { [] }
    func removePending(identifiers: [String]) {}
    func add(_ request: UNNotificationRequest) {}
}
