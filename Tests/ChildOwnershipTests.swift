import XCTest
import SwiftData
@testable import Prikorm

/// Бэкфилл трогает дневники живых пользователей — это самое опасное место всей
/// затеи с несколькими детьми. Ошибка здесь либо оставит человека с пустым
/// экраном (записи не привязались и отфильтровались), либо необратимо перемешает
/// два дневника.
final class ChildOwnershipTests: XCTestCase {

    /// Возвращаем КОНТЕЙНЕР, а не сразу `mainContext`: контейнер владеет контекстом,
    /// и если отдать наружу только контекст, контейнер освобождается на выходе из
    /// функции, а тест падает на первом же обращении.
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchemaCurrent.models)
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    @MainActor
    func testSingleChildAdoptsAllOrphanRecords() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let child = Child(name: "Эмма", birthDate: .now)
        ctx.insert(child)
        ctx.insert(FoodLog(foodId: "apple", date: .now, type: .intro))
        ctx.insert(FoodLog(foodId: "pear", date: .now, type: .intro))
        ctx.insert(IntroductionStatus(foodId: "apple", state: .introduced))
        try ctx.save()

        let touched = PlanMigration.ChildOwnership.apply(context: ctx)
        XCTAssertEqual(touched, 3)

        let logs = try ctx.fetch(FetchDescriptor<FoodLog>())
        XCTAssertTrue(logs.allSatisfy { $0.childId == child.id })
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<IntroductionStatus>()).first?.childId,
                       child.id)
    }

    /// Свипер зовётся при каждом запуске и возврате из фона — он обязан быть
    /// идемпотентным, иначе второй прогон угонит чужие записи активному ребёнку.
    @MainActor
    func testRepeatedRunChangesNothing() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let child = Child(name: "Эмма", birthDate: .now)
        ctx.insert(child)
        ctx.insert(FoodLog(foodId: "apple", date: .now, type: .intro))
        try ctx.save()

        XCTAssertEqual(PlanMigration.ChildOwnership.apply(context: ctx), 1)
        XCTAssertEqual(PlanMigration.ChildOwnership.apply(context: ctx), 0,
                       "второй прогон не должен трогать ничего")
    }

    /// Главное правило: при нескольких детях владельца не угадываем.
    @MainActor
    func testSeveralChildrenLeaveOrphansUntouched() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        ctx.insert(Child(name: "Эмма", birthDate: .now))
        ctx.insert(Child(name: "Лев", birthDate: .now))
        ctx.insert(FoodLog(foodId: "apple", date: .now, type: .intro))
        try ctx.save()

        XCTAssertEqual(PlanMigration.ChildOwnership.apply(context: ctx), 0)
        XCTAssertNil(try ctx.fetch(FetchDescriptor<FoodLog>()).first?.childId,
                     "угадывать владельца нельзя — это необратимо перемешало бы дневники")
    }

    @MainActor
    func testAlreadyOwnedRecordsAreNotReassigned() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let child = Child(name: "Эмма", birthDate: .now)
        ctx.insert(child)
        let foreign = UUID()
        let log = FoodLog(foodId: "apple", date: .now, type: .intro)
        log.childId = foreign
        ctx.insert(log)
        try ctx.save()

        XCTAssertEqual(PlanMigration.ChildOwnership.apply(context: ctx), 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FoodLog>()).first?.childId, foreign)
    }

    @MainActor
    func testEmptyStoreDoesNotCrash() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        XCTAssertEqual(PlanMigration.ChildOwnership.apply(context: ctx), 0)
    }

    @MainActor
    func testNoChildMeansNoAdoption() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        ctx.insert(FoodLog(foodId: "apple", date: .now, type: .intro))
        try ctx.save()

        XCTAssertEqual(PlanMigration.ChildOwnership.apply(context: ctx), 0)
        XCTAssertNil(try ctx.fetch(FetchDescriptor<FoodLog>()).first?.childId)
    }
}
