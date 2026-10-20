import XCTest
import SwiftData
@testable import Prikorm

/// Разделение дневников — то, ради чего вся затея. Ошибка здесь показывает
/// родителю чужие записи или «съедает» его собственные, и оба случая выглядят
/// как потеря данных.
final class MultiChildTests: XCTestCase {

    /// Контейнер отдаём наружу целиком: он владеет контекстом, и если вернуть
    /// только `mainContext`, контейнер освободится и тест умрёт молча.
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(AppSchemaCurrent.models)
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    }

    private func food(_ id: String) -> Food {
        Food(id: id, name: id.capitalized, category: .vegetable,
             emoji: "🥦", isAllergen: false, allergenGroup: nil, minAgeMonths: 6)
    }

    // MARK: - Карточка продукта видит то, что сама записала

    /// UI-тест «Начать введение» на устройстве: после тапа карточка осталась
    /// «Не введён». Здесь — путь карточки один в один: сервис с владельцем
    /// пишет статус, затем выборка с ТЕМ ЖЕ предикатом, что у `@Query` карточки,
    /// и из ДРУГОГО контекста — так видит стор, а не кэш контекста.
    @MainActor
    func testStartedIntroductionIsVisibleThroughCardPredicate() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let child = Child(name: "Ника", birthDate: .now)
        ctx.insert(child)
        try ctx.save()

        FeedingService(context: ctx, childId: child.id).startIntroduction(food("broccoli"))
        XCTAssertFalse(ctx.hasChanges, "сервис обязан сохранить — иначе @Query не обновится")

        let fid = "broccoli", cid = child.id
        let fresh = ModelContext(container)
        let seen = try fresh.fetch(FetchDescriptor<IntroductionStatus>(
            predicate: #Predicate { $0.foodId == fid && $0.childId == cid }))
        XCTAssertEqual(seen.map(\.state), [.introducing])
    }

    // MARK: - Выборки не смешивают детей

    @MainActor
    func testLogsAreFetchedPerChild() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let elder = Child(name: "Эмма", birthDate: .now)
        let younger = Child(name: "Лев", birthDate: .now)
        ctx.insert(elder); ctx.insert(younger)

        for (id, owner) in [("apple", elder), ("pear", elder), ("plum", younger)] {
            let log = FoodLog(foodId: id, date: .now, type: .intro)
            log.childId = owner.id
            ctx.insert(log)
        }
        try ctx.save()

        let elderId = elder.id
        let mine = try ctx.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.childId == elderId }))
        XCTAssertEqual(Set(mine.map(\.foodId)), ["apple", "pear"])

        let youngerId = younger.id
        let theirs = try ctx.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.childId == youngerId }))
        XCTAssertEqual(theirs.map(\.foodId), ["plum"])
    }

    // MARK: - Запись проставляет владельца

    @MainActor
    func testServiceStampsOwnerOnEverythingItCreates() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let child = Child(name: "Эмма", birthDate: .now)
        ctx.insert(child)
        try ctx.save()

        let service = FeedingService(context: ctx, childId: child.id)
        service.startIntroduction(food("apple"))
        service.logFeeding(food("apple"), liking: .liked, reaction: nil)

        let logs = try ctx.fetch(FetchDescriptor<FoodLog>())
        XCTAssertFalse(logs.isEmpty)
        XCTAssertTrue(logs.allSatisfy { $0.childId == child.id },
                      "бесхозная запись пропадёт из отфильтрованных выборок")

        let statuses = try ctx.fetch(FetchDescriptor<IntroductionStatus>())
        XCTAssertTrue(statuses.allSatisfy { $0.childId == child.id })
    }

    /// Регресс: лист планирования создавал планы без владельца — ни одна лента,
    /// отфильтрованная по ребёнку, их не показывала. Дедуп — в пределах ребёнка.
    @MainActor
    func testPlanIsOwnedAndDedupedPerChild() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let older = Child(name: "Эмма", birthDate: .now)
        let younger = Child(name: "Лев", birthDate: .now)
        ctx.insert(older); ctx.insert(younger)
        try ctx.save()

        let day = Date(timeIntervalSince1970: 1_800_000_000)
        FeedingService(context: ctx, childId: older.id).plan(["mango"], on: day)
        // Повтор на тот же день тому же ребёнку — без копий; другому — свой план.
        FeedingService(context: ctx, childId: older.id).plan(["mango"], on: day.addingTimeInterval(3600))
        FeedingService(context: ctx, childId: younger.id).plan(["mango"], on: day)

        let oid = older.id, yid = younger.id
        let olderPlans = try ctx.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.planned && $0.childId == oid }))
        let youngerPlans = try ctx.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.planned && $0.childId == yid }))
        XCTAssertEqual(olderPlans.map(\.foodId), ["mango"], "план должен быть виден ленте ребёнка, без дублей")
        XCTAssertEqual(youngerPlans.count, 1, "чужой план не должен глушить свой")
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.childId == nil })), 0, "бесхозных планов быть не должно")
    }

    /// Главное правило разделения: продукт, введённый старшему, у младшего обязан
    /// считаться невведённым. Иначе младший «наследует» чужую историю прикорма.
    @MainActor
    func testStatusOfAnotherChildIsNotReused() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let elder = Child(name: "Эмма", birthDate: .now)
        let younger = Child(name: "Лев", birthDate: .now)
        ctx.insert(elder); ctx.insert(younger)
        try ctx.save()

        FeedingService(context: ctx, childId: elder.id).markIntroduced([food("apple")])

        let elderStatus = FeedingService(context: ctx, childId: elder.id).status(for: "apple")
        XCTAssertEqual(elderStatus.state, .introduced)

        let youngerStatus = FeedingService(context: ctx, childId: younger.id).status(for: "apple")
        XCTAssertEqual(youngerStatus.state, .notIntroduced,
                       "младший не наследует историю старшего")
        XCTAssertEqual(youngerStatus.childId, younger.id)

        // И статусов теперь два — по одному на ребёнка, а не один общий.
        let all = try ctx.fetch(FetchDescriptor<IntroductionStatus>(
            predicate: #Predicate { $0.foodId == "apple" }))
        XCTAssertEqual(all.count, 2)
    }

    /// Записи одного ребёнка не должны влиять на автозавершение ввода у другого.
    @MainActor
    func testIntroProgressCountsOnlyOwnFeedings() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let elder = Child(name: "Эмма", birthDate: .now)
        let younger = Child(name: "Лев", birthDate: .now)
        ctx.insert(elder); ctx.insert(younger)
        try ctx.save()

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for owner in [elder, younger] {
            let log = FoodLog(foodId: "apple", date: start, type: .intro)
            log.childId = owner.id
            ctx.insert(log)
        }
        try ctx.save()

        let elderId = elder.id
        let elderLogs = try ctx.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.childId == elderId }))
        XCTAssertEqual(
            FeedingService.introFeedingDays(logs: elderLogs, foodId: "apple", since: start), 1,
            "кормления другого ребёнка не должны засчитываться")
    }
}
