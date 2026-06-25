import XCTest
import SwiftData
@testable import Prikorm

/// Тесты сервиса введения прикорма (Task 3): переходы стейт-машины
/// (SPEC §4.4) и создание записей в журнале с корректным типом.
final class FeedingServiceTests: XCTestCase {

    /// Свежий in-memory контейнер на каждый тест — изоляция, без диска.
    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Child.self, IntroductionStatus.self, FoodLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
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
    func testLogFeedingWithReactionDuringIntroPauses() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.logFeeding(food, liking: nil, reaction: .skin)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .paused, "реакция при вводе → пауза")

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
    func testLogFeedingWithReactionOnIntroducedMarksAllergy() throws {
        let context = try makeContext()
        let service = FeedingService(context: context)
        let food = makeFood()

        service.startIntroduction(food)
        service.completeIntroduction(food)
        service.logFeeding(food, liking: nil, reaction: .gi)

        let s = service.status(for: food.id)
        XCTAssertEqual(s.state, .allergy, "реакция на введённый продукт → аллергия")

        let rows = try logs(context, foodId: food.id)
        let maintenance = rows.filter { $0.type == .maintenance }
        XCTAssertEqual(maintenance.count, 1)
        XCTAssertEqual(maintenance.first?.reaction, .gi)
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
}
