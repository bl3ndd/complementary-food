import XCTest
@testable import Prikorm

/// Тесты чистой логики настроения маскота (Task 1 плана Pudding-mascot).
/// Сам рисунок маскота не юнит-тестируется — он валидируется self-launch.
final class MascotTests: XCTestCase {

    func testForProgressNothingIntroduced() {
        XCTAssertEqual(MascotMood.forProgress(introduced: 0, total: 50), .curious)
    }

    func testForProgressGuardsZeroTotal() {
        // total == 0 не должен приводить к делению/ложному «всё введено».
        XCTAssertEqual(MascotMood.forProgress(introduced: 0, total: 0), .curious)
        XCTAssertEqual(MascotMood.forProgress(introduced: 5, total: 0), .curious)
    }

    func testForProgressPartial() {
        XCTAssertEqual(MascotMood.forProgress(introduced: 3, total: 10), .happy)
    }

    func testForProgressComplete() {
        XCTAssertEqual(MascotMood.forProgress(introduced: 10, total: 10), .cheer)
        XCTAssertEqual(MascotMood.forProgress(introduced: 12, total: 10), .cheer)
    }

    func testForDue() {
        XCTAssertEqual(MascotMood.forDue(0), .happy)
        XCTAssertEqual(MascotMood.forDue(1), .worried)
        XCTAssertEqual(MascotMood.forDue(3), .worried)
    }

    func testAllCasesNotEmpty() {
        XCTAssertFalse(MascotMood.allCases.isEmpty)
    }
}
