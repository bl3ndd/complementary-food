import XCTest
@testable import Prikorm

/// Тесты рекапа месяца (bucket 3): попробованные/новые/любимое за месяц.
/// Детерминизм через инъекцию UTC-календаря; ассерты на счётчики и id (не на
/// локализуемый текст).
final class RecapServiceTests: XCTestCase {

    private let catalog = FoodCatalog(foods: [
        Food(id: "broccoli", name: "Брокколи", category: .vegetable,
             emoji: "🥦", isAllergen: false, allergenGroup: nil, minAgeMonths: 4),
        Food(id: "egg_yolk", name: "Желток", category: .egg,
             emoji: "🥚", isAllergen: true, allergenGroup: .egg, minAgeMonths: 6),
        Food(id: "avocado", name: "Авокадо", category: .fruit,
             emoji: "🥑", isAllergen: false, allergenGroup: nil, minAgeMonths: 5),
    ])

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")!
        return f.date(from: iso)!
    }

    private func log(_ id: String, _ iso: String, liking: Liking? = nil,
                     planned: Bool = false) -> FoodLog {
        FoodLog(foodId: id, date: date(iso), type: .intro, liking: liking, planned: planned)
    }

    private func service(_ logs: [FoodLog]) -> RecapService {
        RecapService(catalog: catalog, logs: logs, calendar: utc)
    }

    private func june(_ logs: [FoodLog]) -> MonthRecap {
        service(logs).recap(for: date("2026-06-15T12:00:00Z"), childName: "Ника", ageMonths: 8)
    }

    func testRecapCountsTriedNewAndFavorite() {
        let logs = [
            log("broccoli", "2026-05-20T09:00:00Z", liking: .liked),   // май — brocco «не новый»
            log("broccoli", "2026-06-05T09:00:00Z", liking: .liked),
            log("broccoli", "2026-06-10T09:00:00Z", liking: .liked),   // brocco liked ×2 в июне
            log("egg_yolk", "2026-06-11T09:00:00Z", liking: .neutral), // новый в июне
            log("avocado",  "2026-06-12T09:00:00Z", liking: .liked),   // новый в июне
            log("avocado",  "2026-07-01T09:00:00Z"),                   // июль — вне
            log("egg_yolk", "2026-06-20T09:00:00Z", planned: true),    // план — вне
        ]
        let r = june(logs)
        XCTAssertEqual(r.triedFoods.count, 3, "brocco, egg, avocado пробовали в июне")
        XCTAssertEqual(r.triedFoods.first?.id, "broccoli", "порядок — по первому приёму в месяце")
        XCTAssertEqual(r.newCount, 2, "egg и avocado впервые в июне; brocco ещё с мая")
        XCTAssertEqual(r.totalLogs, 4, "план и июль не считаются")
        XCTAssertEqual(r.favorite?.id, "broccoli", "чаще всего понравилось")
    }

    func testEmptyMonthRecapIsEmpty() {
        let r = service([log("broccoli", "2026-05-01T09:00:00Z")]).recap(
            for: date("2026-06-15T12:00:00Z"), childName: "Ника", ageMonths: 8)
        XCTAssertTrue(r.isEmpty)
        XCTAssertTrue(r.triedFoods.isEmpty)
        XCTAssertEqual(r.newCount, 0)
        XCTAssertNil(r.favorite)
    }

    func testHasDataForMonth() {
        let s = service([log("broccoli", "2026-06-05T09:00:00Z"),
                         log("egg_yolk", "2026-07-20T09:00:00Z", planned: true)])
        XCTAssertTrue(s.hasData(for: date("2026-06-15T12:00:00Z")))
        XCTAssertFalse(s.hasData(for: date("2026-07-15T12:00:00Z")), "в июле только план — не считается")
        XCTAssertFalse(s.hasData(for: date("2026-04-15T12:00:00Z")))
    }
}
