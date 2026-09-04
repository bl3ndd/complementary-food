import XCTest
@testable import Prikorm

/// Лимит ограничивает добавление, а не доступ. Тесты сторожат именно это: самая
/// вероятная ошибка здесь — «спрятать» лишних детей при потере Pro, то есть
/// отобрать у человека уже введённые дневники.
final class ChildLimitTests: XCTestCase {

    func testFirstChildIsAlwaysFree() {
        XCTAssertTrue(ChildLimit.canAdd(currentCount: 0, isPro: false))
        XCTAssertTrue(ChildLimit.canAdd(currentCount: 0, isPro: true))
    }

    func testSecondChildRequiresPro() {
        XCTAssertFalse(ChildLimit.canAdd(currentCount: 1, isPro: false))
        XCTAssertTrue(ChildLimit.canAdd(currentCount: 1, isPro: true))
    }

    func testProHasNoCeiling() {
        for count in [2, 5, 20] {
            XCTAssertTrue(ChildLimit.canAdd(currentCount: count, isPro: true))
        }
    }

    /// Ключевой случай: Pro отвалился, а детей уже несколько. Добавлять нельзя,
    /// но существующие обязаны остаться доступными — это проверяется тем, что
    /// лимит вообще не отвечает на вопрос «показывать ли ребёнка».
    func testLosingProOnlyBlocksAddingNotAccess() {
        XCTAssertFalse(ChildLimit.canAdd(currentCount: 3, isPro: false))
        // Никакой функции вида `visibleChildren(limit:)` в API нет и быть не должно:
        // доступ к уже заведённым детям лимитом не управляется.
        XCTAssertEqual(ChildLimit.freeLimit, 1)
    }
}
