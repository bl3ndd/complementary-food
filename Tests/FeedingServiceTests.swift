import XCTest
import SwiftData
@testable import Prikorm

/// Тесты сервиса введения прикорма (Task 3): переходы стейт-машины
/// (SPEC §4.4) и создание записей в журнале с корректным типом.
final class FeedingServiceTests: XCTestCase {

    /// Контейнер держим в свойстве, чтобы он жил всю длину теста: `ModelContext`
    /// держит на контейнер невладеющую ссылку, и если контейнер деаллоцируется
    /// (был локальной переменной), фетч ловит трап SwiftData (Swift 6.3).
    private var container: ModelContainer!

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Child.self, IntroductionStatus.self, FoodLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }

    private func makeFood(id: String = "broccoli",
                          allergen: Bool = false,
                          group: AllergenGroup? = nil) -> Food {
        Food(id: id, name: id.capitalized, category: .vegetable,
             emoji: "🥦", isAllergen: allergen, allergenGroup: group, minAgeMonths: 4)
    }

    private func logs(_ context: ModelContext, foodId: String) throws -> [FoodLog] {
        try context.fetch(FetchDescriptor<FoodLog>())
            .filter { $0.foodId == foodId }
    }

    // MARK: - status(for:)

    @MainActor
    func testStatusCreatesNotIntroducedOnFirstAccess() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)

        let s = service.status(for: "broccoli")
        XCTAssertEqual(s.state, .notIntroduced)

        // повторный вызов возвращает тот же объект, а не дубль
        let again = service.status(for: "broccoli")
        XCTAssertEqual(again.persistentModelID, s.persistentModelID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<IntroductionStatus>()).count, 1)
    }

    // MARK: - notIntroduced → introducing

    @MainActor
    func testStartIntroductionTransitionsAndLogsIntro() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .introducing)
        XCTAssertNotNil(s.introStartedAt)
        XCTAssertNil(s.completedAt)

        let rows = try logs(context, foodId: food.id)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.type, .intro)
    }

    // MARK: - introducing → introduced

    @MainActor
    func testCompleteIntroductionMarksIntroduced() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.completeIntroduction(food)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .introduced)
        XCTAssertNotNil(s.completedAt)
    }

    // MARK: - logFeeding во время введения

    @MainActor
    func testLogFeedingWithoutReactionStaysIntroducing() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.logFeeding(food, liking: .liked, reaction: nil)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .introducing)

        let rows = try logs(context, foodId: food.id)
        XCTAssertEqual(rows.count, 2)               // intro при старте + это кормление
        XCTAssertTrue(rows.allSatisfy { $0.type == .intro })
        XCTAssertEqual(rows.filter { $0.liking == .liked }.count, 1)
    }

    @MainActor
    func testLogFeedingWithReactionDuringIntroDoesNotChangeState() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.logFeeding(food, liking: nil, reaction: .skin)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .introducing, "реакция — только запись, статус не меняется")

        let rows = try logs(context, foodId: food.id)
        XCTAssertTrue(rows.allSatisfy { $0.type == .intro })
        XCTAssertEqual(rows.filter { $0.reaction == .skin }.count, 1)
    }

    // MARK: - logFeeding на уже введённом (поддержка)

    @MainActor
    func testLogFeedingOnIntroducedCreatesMaintenanceRow() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.completeIntroduction(food)
        service.logFeeding(food, liking: .neutral, reaction: nil)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .introduced, "кормление без реакции не меняет статус")

        let rows = try logs(context, foodId: food.id)
        XCTAssertEqual(rows.filter { $0.type == .maintenance }.count, 1)
        XCTAssertEqual(rows.filter { $0.type == .intro }.count, 1)   // только стартовый
    }

    @MainActor
    func testLogFeedingWithReactionOnIntroducedKeepsIntroduced() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.completeIntroduction(food)
        service.logFeeding(food, liking: nil, reaction: .gi)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .introduced, "реакция — только запись, авто-аллергии больше нет")

        let rows = try logs(context, foodId: food.id)
        let maintenance = rows.filter { $0.type == .maintenance }
        XCTAssertEqual(maintenance.count, 1)
        XCTAssertEqual(maintenance.first?.reaction, .gi)
    }

    // MARK: - Расширенные теги реакции (ЖКТ → запор/диарея), без авто-переходов

    @MainActor
    func testGiReactionTagsAreRecordedWithoutStateChange() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.logFeeding(food, liking: nil, reaction: .constipation)
        service.logFeeding(food, liking: nil, reaction: .diarrhea)

        XCTAssertEqual(service.status(for: food.id).state, .introducing)
        let rows = try logs(context, foodId: food.id)
        XCTAssertEqual(rows.filter { $0.reaction == .constipation }.count, 1)
        XCTAssertEqual(rows.filter { $0.reaction == .diarrhea }.count, 1)
    }

    func testEveryReactionTypeHasNonEmptyTitle() {
        for r in ReactionType.allCases {
            XCTAssertFalse(r.title.isEmpty, "у реакции \(r.rawValue) пустой title")
            XCTAssertFalse(r.emoji.isEmpty)
        }
    }

    /// Старые логи с raw «gi»/«breathing» должны декодироваться (совместимость).
    func testLegacyReactionRawValuesStillDecode() {
        XCTAssertEqual(ReactionType(rawValue: "gi"), .gi)
        XCTAssertEqual(ReactionType(rawValue: "breathing"), .breathing)
    }

    // MARK: - Ручные переходы

    @MainActor
    func testMarkAllergySetsAllergyState() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.markAllergy(food)

        XCTAssertEqual(service.status(for: food.id).state, .allergy)
    }

    @MainActor
    func testReintroduceMovesAllergyBackToIntroducing() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.markAllergy(food)
        service.reintroduce(food)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .introducing)
        XCTAssertNotNil(s.introStartedAt)
        XCTAssertNil(s.completedAt)
    }

    // MARK: - Остановить / повторить через 2 месяца (ручное управление, п.16)

    @MainActor
    func testStopIntroductionPausesAndClearsRetry() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.stopIntroduction(food)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .paused)
        XCTAssertNil(s.retryAt)
    }

    @MainActor
    func testScheduleRetryKeepsPausedAndSetsRetryDate() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()
        let cal = utcCalendar()
        let now = day(1, cal)

        service.scheduleRetry(food, after: 2, now: now, calendar: cal)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .paused)
        XCTAssertEqual(s.retryAt, cal.date(byAdding: .month, value: 2, to: now))
    }

    @MainActor
    func testReintroduceClearsRetry() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.scheduleRetry(food)
        XCTAssertNotNil(service.status(for: food.id).retryAt)

        service.reintroduce(food)
        XCTAssertNil(service.status(for: food.id).retryAt)
    }

    // MARK: - Реакция .none трактуется как «нет реакции»

    @MainActor
    func testExplicitNoneReactionDoesNotChangeState() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.logFeeding(food, liking: .liked, reaction: ReactionType.none)

        XCTAssertEqual(service.status(for: food.id).state, .introducing)
    }

    // MARK: - Окно наблюдения (статическая чистая логика, инъекция now/calendar)

    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func day(_ d: Int, _ cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: d))!
    }

    func testObservationDayCountsFromStart() {
        let cal = utcCalendar()
        let start = day(1, cal)
        XCTAssertEqual(FeedingService.observationDay(start: start, now: start, calendar: cal), 1)
        XCTAssertEqual(FeedingService.observationDay(start: start, now: day(3, cal), calendar: cal), 3)
    }

    func testObservationIncompleteDuringWindow() {
        let cal = utcCalendar()
        let start = day(1, cal)
        // День 1 и день 2 при окне 3 — ещё нельзя «ввёл успешно».
        XCTAssertFalse(FeedingService.isObservationComplete(start: start, observationDays: 3,
                                                            now: start, calendar: cal))
        XCTAssertFalse(FeedingService.isObservationComplete(start: start, observationDays: 3,
                                                            now: day(2, cal), calendar: cal))
    }

    func testObservationCompleteAfterWindow() {
        let cal = utcCalendar()
        let start = day(1, cal)
        // День 3 и позже при окне 3 — окно пройдено.
        XCTAssertTrue(FeedingService.isObservationComplete(start: start, observationDays: 3,
                                                           now: day(3, cal), calendar: cal))
        XCTAssertTrue(FeedingService.isObservationComplete(start: start, observationDays: 3,
                                                           now: day(5, cal), calendar: cal))
    }

    // MARK: - Бэкдейт ввода и якорь окна (п.22)

    @MainActor
    func testStartIntroductionWithPastDateAnchorsWindow() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()
        let cal = utcCalendar()

        service.startIntroduction(food, date: day(1, cal))

        let s = service.status(for: food.id)
        XCTAssertEqual(s.introStartedAt, day(1, cal))
        let rows = try logs(context, foodId: food.id)
        XCTAssertEqual(rows.first?.date, day(1, cal))
    }

    @MainActor
    func testBackdatedFeedingPullsWindowStartBack() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()
        let cal = utcCalendar()

        service.startIntroduction(food, date: day(5, cal))
        service.logFeeding(food, liking: nil, reaction: nil, date: day(2, cal))

        // Кормление за 2-е число тянет старт окна назад к 2-му.
        XCTAssertEqual(service.status(for: food.id).introStartedAt, day(2, cal))
    }

    // MARK: - Засев «уже введённых» из онбординга (п.23)

    @MainActor
    func testMarkIntroducedCreatesIntroducedStatusesNoLogsNoDupes() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let a = makeFood(id: "apple"), b = makeFood(id: "pear")

        service.markIntroduced([a, b])
        XCTAssertEqual(service.status(for: "apple").state, .introduced)
        XCTAssertEqual(service.status(for: "pear").state, .introduced)
        XCTAssertNotNil(service.status(for: "apple").completedAt, "база для поддержки — completedAt")
        // Логи НЕ создаются — иначе попали бы в дневник как «дали сегодня».
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodLog>()).count, 0)

        // Повторный вызов не плодит статусы.
        service.markIntroduced([a])
        XCTAssertEqual(try context.fetch(FetchDescriptor<IntroductionStatus>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodLog>()).count, 0)
    }

    // MARK: - Подтверждение запланированного ввода (B1/B4)

    @MainActor
    func testConfirmPlannedStartsIntroductionReusingLog() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let cal = utcCalendar()
        let food = makeFood()

        let log = FoodLog(foodId: food.id, date: day(2, cal), type: .intro, planned: true)
        context.insert(log)
        try context.save()

        service.confirmPlanned(log, now: day(5, cal))

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .introducing)
        XCTAssertEqual(s.introStartedAt, day(2, cal))
        XCTAssertFalse(log.planned)
        // Лог переиспользован — дубля intro-записи нет.
        XCTAssertEqual(try context.fetch(FetchDescriptor<FoodLog>()).count, 1)
    }

    @MainActor
    func testConfirmPlannedClampsFutureDateToNow() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let cal = utcCalendar()
        let food = makeFood()

        let log = FoodLog(foodId: food.id, date: day(10, cal), type: .intro, planned: true)
        context.insert(log)
        try context.save()

        service.confirmPlanned(log, now: day(5, cal))

        XCTAssertFalse(log.planned)
        XCTAssertEqual(log.date, day(5, cal), "будущую дату клампим к now")
    }

    func testWindowStartTakesEarliestOfStartAndLogs() {
        let cal = utcCalendar()
        XCTAssertEqual(
            FeedingService.windowStart(introStartedAt: day(5, cal),
                                       introLogDates: [day(3, cal), day(8, cal)]),
            day(3, cal))
        XCTAssertEqual(
            FeedingService.windowStart(introStartedAt: nil, introLogDates: [day(4, cal)]),
            day(4, cal))
        XCTAssertNil(FeedingService.windowStart(introStartedAt: nil, introLogDates: []))
    }
}
