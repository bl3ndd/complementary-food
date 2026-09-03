import XCTest
@testable import Prikorm

/// Смена иконки работает только в живом приложении, поэтому тестируем чистый
/// маппинг. Он важнее, чем кажется: опечатка в имени набора — и
/// `setAlternateIconName` тихо ничего не делает, а пользователь думает, что купил
/// нерабочую фичу.
final class AppIconManagerTests: XCTestCase {

    func testEveryProPaletteHasAnIcon() {
        for palette in Palette.all where palette.isPro {
            XCTAssertNotNil(AppIconManager.names[palette.id],
                            "у гаммы \(palette.id) нет иконки")
        }
    }

    func testBasePaletteUsesTheMainIcon() {
        XCTAssertNil(AppIconManager.iconName(for: Palette.pudding.id, isPro: true),
                     "базовая гамма — это основная иконка, а не альтернативная")
    }

    func testWithoutProAlwaysMainIcon() {
        for palette in Palette.all {
            XCTAssertNil(AppIconManager.iconName(for: palette.id, isPro: false))
        }
    }

    func testProPaletteResolvesToItsIcon() {
        XCTAssertEqual(AppIconManager.iconName(for: "matcha", isPro: true), "AppIconMatcha")
        XCTAssertEqual(AppIconManager.iconName(for: "blueberry", isPro: true), "AppIconBlueberry")
    }

    func testUnknownPaletteDoesNotThrowAndFallsBackToMain() {
        XCTAssertNil(AppIconManager.iconName(for: "нет такой", isPro: true))
        XCTAssertNil(AppIconManager.iconName(for: nil, isPro: true))
    }

    /// Имена уходят в build setting ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES;
    /// дубликат означал бы, что две гаммы дерутся за один набор.
    func testIconNamesAreUnique() {
        let values = Array(AppIconManager.names.values)
        XCTAssertEqual(values.count, Set(values).count)
    }
}
