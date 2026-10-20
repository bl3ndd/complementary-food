import XCTest
import SwiftData
@testable import Prikorm

/// «Сбросить все данные» обязан стереть ВСЁ и реально сохраниться: раньше смесь
/// пакетного и поштучного удаления роняла save(), и ребёнок возвращался после
/// онбординга.
final class StoreResetTests: XCTestCase {

    @MainActor
    func testWipeRemovesEverythingAndPersists() throws {
        let schema = Schema(AppSchemaCurrent.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
        let ctx = container.mainContext

        let child = Child(name: "Ника", birthDate: .now)
        ctx.insert(child)
        let log = FoodLog(foodId: "apple")
        log.childId = child.id
        ctx.insert(log)
        let photo = LogPhoto(data: Data([1, 2, 3]))
        ctx.insert(photo)
        log.photos = [photo]
        ctx.insert(LogPhoto(data: Data([4])))   // орфан без записи
        let status = IntroductionStatus(foodId: "apple", state: .introduced)
        status.childId = child.id
        ctx.insert(status)
        ctx.insert(CustomFood(name: "Компот", emoji: "🍎"))
        try ctx.save()

        try StoreReset.wipe(ctx)

        // Свежий контекст видит только сохранённое — проверяем, что save() прошёл.
        let fresh = ModelContext(container)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<Child>()), 0, "ребёнок вернулся бы после онбординга")
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<FoodLog>()), 0)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<LogPhoto>()), 0, "фото-орфаны не должны оставаться")
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<IntroductionStatus>()), 0)
        XCTAssertEqual(try fresh.fetchCount(FetchDescriptor<CustomFood>()), 0)
    }
}
