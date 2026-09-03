import XCTest
import SwiftData
@testable import Prikorm

/// Тесты слоя моделей: round-trip через in-memory ModelContainer
/// и арифметика возраста ребёнка (Task 1).
final class ModelTests: XCTestCase {

    /// Свежий in-memory контейнер на каждый тест — изоляция, без диска.
    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Child.self, IntroductionStatus.self, FoodLog.self, LogPhoto.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Round-trip

    @MainActor
    func testChildRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let birth = Date(timeIntervalSince1970: 1_600_000_000)
        let child = Child(name: "Маша", birthDate: birth, feedingProfileId: FeedingProfile.customId)
        context.insert(child)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Child>())
        XCTAssertEqual(fetched.count, 1)
        let loaded = try XCTUnwrap(fetched.first)
        XCTAssertEqual(loaded.name, "Маша")
        XCTAssertEqual(loaded.birthDate, birth)
        XCTAssertEqual(loaded.feedingProfileId, FeedingProfile.customId)
        XCTAssertEqual(loaded.feedingProfile.id, FeedingProfile.customId)
    }

    @MainActor
    func testIntroductionStatusRoundTripAndStateEnum() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let status = IntroductionStatus(foodId: "broccoli", state: .introducing)
        status.introStartedAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(status)
        try context.save()

        let loaded = try XCTUnwrap(try context.fetch(FetchDescriptor<IntroductionStatus>()).first)
        XCTAssertEqual(loaded.foodId, "broccoli")
        XCTAssertEqual(loaded.state, .introducing)
        XCTAssertEqual(loaded.stateRaw, IntroState.introducing.rawValue)

        // мутация enum через computed property пишет в raw-хранилище
        loaded.state = .introduced
        XCTAssertEqual(loaded.stateRaw, IntroState.introduced.rawValue)
    }

    @MainActor
    func testFoodLogRoundTripWithOptionalEnums() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let date = Date(timeIntervalSince1970: 1_650_000_000)
        let photoBytes = Data([0x01, 0x02, 0x03, 0x04])
        let log = FoodLog(foodId: "egg",
                          date: date,
                          type: .maintenance,
                          reaction: .skin,
                          liking: .liked,
                          note: "немного сыпи",
                          severity: .moderate,
                          photo: photoBytes)
        context.insert(log)
        try context.save()

        let loaded = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodLog>()).first)
        XCTAssertEqual(loaded.foodId, "egg")
        XCTAssertEqual(loaded.date, date)
        XCTAssertEqual(loaded.type, .maintenance)
        XCTAssertEqual(loaded.reaction, .skin)
        XCTAssertEqual(loaded.severity, .moderate)
        XCTAssertEqual(loaded.liking, .liked)
        XCTAssertEqual(loaded.note, "немного сыпи")
        XCTAssertEqual(loaded.photo, photoBytes)
    }

    @MainActor
    func testFoodLogNilOptionalsRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let log = FoodLog(foodId: "carrot")   // дефолтный intro, без реакции/оценки
        context.insert(log)
        try context.save()

        let loaded = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodLog>()).first)
        XCTAssertEqual(loaded.type, .intro)
        XCTAssertNil(loaded.reaction)
        XCTAssertNil(loaded.severity)
        XCTAssertNil(loaded.liking)
        XCTAssertNil(loaded.note)
        XCTAssertNil(loaded.photo)
        XCTAssertTrue(loaded.photoDatas.isEmpty)
    }

    @MainActor
    func testFoodLogPhotosRelationshipOrderingAndCascade() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let log = FoodLog(foodId: "egg", photo: Data([9]))   // legacy-одиночное
        context.insert(log)
        let p0 = LogPhoto(data: Data([1]), sortIndex: 0)
        let p1 = LogPhoto(data: Data([2]), sortIndex: 1)
        context.insert(p0); context.insert(p1)
        log.photos = [p1, p0]                                 // намеренно не по порядку
        try context.save()

        let loaded = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodLog>()).first)
        // legacy сначала, потом relationship по sortIndex
        XCTAssertEqual(loaded.photoDatas, [Data([9]), Data([1]), Data([2])])
        XCTAssertEqual((loaded.photos ?? []).count, 2)

        context.delete(loaded)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<LogPhoto>()).isEmpty,
                      "фото удаляются каскадом вместе с записью")
    }

    // MARK: - Age math

    func testAgeInMonthsExactBoundary() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let birth = cal.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let child = Child(name: "Тест", birthDate: birth)

        // ровно 6 месяцев
        let sixMonths = cal.date(from: DateComponents(year: 2025, month: 7, day: 15))!
        XCTAssertEqual(child.ageInMonths(now: sixMonths, calendar: cal), 6)

        // на день меньше — ещё 5 полных месяцев
        let almostSix = cal.date(from: DateComponents(year: 2025, month: 7, day: 14))!
        XCTAssertEqual(child.ageInMonths(now: almostSix, calendar: cal), 5)
    }

    func testAgeInMonthsNewbornAndSameDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let birth = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let child = Child(name: "Тест", birthDate: birth)

        XCTAssertEqual(child.ageInMonths(now: birth, calendar: cal), 0)

        let twoWeeks = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        XCTAssertEqual(child.ageInMonths(now: twoWeeks, calendar: cal), 0)
    }

    // MARK: - FeedingProfile config (свой план)

    func testCustomFeedingProfileMaintenanceInterval() {
        let child = Child(feedingProfileId: FeedingProfile.customId)
        child.customAllergenFrequencyPerWeek = 2
        XCTAssertEqual(child.feedingProfile.maintenanceIntervalDays, 4)  // 7/2 ≈ 3.5 → 4
        child.customAllergenFrequencyPerWeek = 1
        XCTAssertEqual(child.feedingProfile.maintenanceIntervalDays, 7)  // 7/1 → 7
    }

    // MARK: - Отметка «когда пришёл» под обещание ранним пользователям

    @MainActor
    func testEarlyAdopterRegistersOnceAndKeepsFirstDate() throws {
        let schema = Schema(AppSchemaCurrent.models)
        let container = try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let service = EarlyAdopter(context: context)
        let first = Date(timeIntervalSince1970: 1_700_000_000)

        let created = service.registerIfNeeded(now: first, version: "1.0.0")
        XCTAssertEqual(created.firstLaunchedAt, first)
        XCTAssertEqual(created.firstVersion, "1.0.0")

        // Повторный запуск — та же запись, дата не съезжает.
        let again = service.registerIfNeeded(now: first.addingTimeInterval(86_400 * 30),
                                             version: "1.2.0")
        XCTAssertEqual(again.firstLaunchedAt, first, "дата первого запуска не должна двигаться")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AppInstall>()), 1,
                       "запись не должна дублироваться")
    }

    @MainActor
    func testEarlyAdopterPicksEarliestWhenDuplicatesSynced() throws {
        let schema = Schema(AppSchemaCurrent.models)
        let container = try ModelContainer(for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let early = Date(timeIntervalSince1970: 1_700_000_000)

        // Гонка двух устройств на одном iCloud: две записи прилетели через синк.
        context.insert(AppInstall(firstLaunchedAt: early.addingTimeInterval(86_400), firstVersion: "1.0.0"))
        context.insert(AppInstall(firstLaunchedAt: early, firstVersion: "1.0.0"))

        XCTAssertEqual(EarlyAdopter(context: context).registerIfNeeded().firstLaunchedAt, early,
                       "берём самую раннюю отметку")
    }
    // MARK: - Схема V3: фото малыша

    /// Поле добавляется опциональным, значит переход lightweight и существующие
    /// записи получают nil. Проверяем, что стор с планом миграции поднимается и
    /// данные на месте — миграция единственное место во всей Pro-затее, где можно
    /// задеть уже введённый дневник.
    @MainActor
    func testSchemaV3OpensWithMigrationPlanAndKeepsData() throws {
        let schema = Schema(AppSchemaCurrent.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema,
                                           migrationPlan: AppMigrationPlan.self,
                                           configurations: [config])
        let ctx = container.mainContext
        let child = Child(name: "Эмма", birthDate: Date(timeIntervalSince1970: 1_700_000_000))
        ctx.insert(child)
        ctx.insert(FoodLog(foodId: "apple", date: .now, type: .intro))
        try ctx.save()

        let children = try ctx.fetch(FetchDescriptor<Child>())
        XCTAssertEqual(children.count, 1)
        XCTAssertNil(children.first?.photo, "у существующих записей фото просто nil")
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FoodLog>()).count, 1)
    }

    @MainActor
    func testChildPhotoRoundTrips() throws {
        let schema = Schema(AppSchemaCurrent.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let ctx = container.mainContext

        let child = Child(name: "Эмма", birthDate: .now)
        child.photo = Data([0xFF, 0xD8, 0xFF, 0xE0])
        ctx.insert(child)
        try ctx.save()

        let back = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Child>()).first)
        XCTAssertEqual(back.photo, Data([0xFF, 0xD8, 0xFF, 0xE0]))
    }

    /// План миграции обязан покрывать все версии: пропущенная ступень роняет
    /// приложение у тех, кто обновляется с давней сборки.
    ///
    /// И обратное тоже: ЛИШНЯЯ версия с тем же набором моделей роняет приложение
    /// на старте (проверено 03.09.2026 — тест-хост умирал с signal abrt). Поэтому
    /// число ступеней жёстко привязано к числу версий.
    func testMigrationPlanCoversEveryVersionAndHasNoDuplicates() {
        XCTAssertEqual(AppMigrationPlan.stages.count, AppMigrationPlan.schemas.count - 1)
        let ids = AppMigrationPlan.schemas.map { "\($0.versionIdentifier)" }
        XCTAssertEqual(ids.count, Set(ids).count, "две версии с одним идентификатором")
    }

    // MARK: - Привязка записей к ребёнку

    /// Поле опциональное (требование CloudKit и условие добавления без бампа схемы),
    /// поэтому проверяем оба состояния: старая запись без владельца и новая с ним.
    @MainActor
    func testChildIdRoundTripsAndIsOptional() throws {
        let schema = Schema(AppSchemaCurrent.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let ctx = container.mainContext

        let owner = UUID()
        let owned = FoodLog(foodId: "apple", date: .now, type: .intro)
        owned.childId = owner
        let orphan = FoodLog(foodId: "pear", date: .now, type: .intro)
        ctx.insert(owned); ctx.insert(orphan)

        let status = IntroductionStatus(foodId: "apple", state: .introducing)
        status.childId = owner
        ctx.insert(status)
        try ctx.save()

        let logs = try ctx.fetch(FetchDescriptor<FoodLog>())
        XCTAssertEqual(logs.first { $0.foodId == "apple" }?.childId, owner)
        XCTAssertNil(logs.first { $0.foodId == "pear" }?.childId,
                     "запись без владельца обязана оставаться валидной")
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<IntroductionStatus>()).first?.childId, owner)
    }

    /// Выборка по владельцу — то, на чём держится разделение дневников.
    @MainActor
    func testFetchFiltersByChild() throws {
        let schema = Schema(AppSchemaCurrent.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let ctx = container.mainContext

        let elder = UUID(), younger = UUID()
        for (food, owner) in [("apple", elder), ("pear", elder), ("plum", younger)] {
            let log = FoodLog(foodId: food, date: .now, type: .intro)
            log.childId = owner
            ctx.insert(log)
        }
        try ctx.save()

        let mine = try ctx.fetch(FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.childId == elder }))
        XCTAssertEqual(Set(mine.map(\.foodId)), ["apple", "pear"])
    }

}
