import XCTest
import SwiftUI
import UIKit
@testable import Prikorm

/// Гаммы — это Pro-фича, но ломаются они не деньгами, а глазами: слишком яркий
/// акцент рвёт контраст текста, а нестабильный id обнуляет выбор пользователя
/// при обновлении. Тесты сторожат ровно это.
final class PaletteTests: XCTestCase {

    /// Компоненты цвета для указанной схемы. `Palette` хранит светлую и тёмную
    /// стороны раздельно, поэтому среда не нужна.
    private func hsb(_ color: Color) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b)
    }

    private func luminance(_ color: Color) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &bl, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * bl
    }

    // MARK: - Состав

    func testEveryPaletteHasUniqueStableId() {
        let ids = Palette.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "дублирующийся id перепишет чужой выбор")
        // Id уходит в UserDefaults — менять его нельзя, иначе выбор слетит при обновлении.
        XCTAssertEqual(Palette.pudding.id, "pudding")
        XCTAssertTrue(ids.allSatisfy { !$0.isEmpty })
    }

    func testOnlyBasePaletteIsFree() {
        XCTAssertFalse(Palette.pudding.isPro, "базовая гамма обязана остаться бесплатной")
        let paid = Palette.all.filter { $0.id != Palette.pudding.id }
        XCTAssertFalse(paid.isEmpty)
        XCTAssertTrue(paid.allSatisfy(\.isPro))
    }

    func testEveryPaletteHasATitle() {
        for p in Palette.all {
            XCTAssertFalse(p.titleKey.isEmpty, "у гаммы \(p.id) нет ключа названия")
            XCTAssertFalse(p.title.isEmpty)
        }
    }

    // MARK: - Никакой кислоты

    /// Прямое требование к дизайну: приглушённо, без неона. Порог не абстрактный —
    /// у базовой гаммы насыщенность акцента ≈0.69, и это верхняя планка вкуса.
    func testAccentsAreNotAcid() {
        for p in Palette.all {
            for (name, color) in [("light", p.accent.light), ("dark", p.accent.dark),
                                  ("deep light", p.accentDeep.light),
                                  ("deep dark", p.accentDeep.dark)] {
                let s = hsb(color).s
                XCTAssertLessThanOrEqual(s, 0.80,
                                         "\(p.id) \(name): насыщенность \(s) — это уже неон")
            }
        }
    }

    /// Акцент должен читаться на своём фоне. Проверяем обе схемы: в тёмной фон
    /// почти чёрный, в светлой — почти белый, и провалиться можно в любую сторону.
    func testAccentContrastsWithBackground() {
        for p in Palette.all {
            let lightGap = abs(luminance(p.accent.light) - luminance(p.bgTop.light))
            let darkGap = abs(luminance(p.accent.dark) - luminance(p.bgTop.dark))
            XCTAssertGreaterThan(lightGap, 0.15, "\(p.id): акцент сливается со светлым фоном")
            XCTAssertGreaterThan(darkGap, 0.15, "\(p.id): акцент сливается с тёмным фоном")
        }
    }

    /// Тёмная сторона фона обязана быть действительно тёмной, а светлая — светлой.
    /// Перепутанные местами пары ломают весь экран, и заметно это только глазами.
    func testBackgroundSidesAreNotSwapped() {
        for p in Palette.all {
            XCTAssertGreaterThan(luminance(p.bgTop.light), 0.7, "\(p.id): светлый фон не светлый")
            XCTAssertLessThan(luminance(p.bgTop.dark), 0.2, "\(p.id): тёмный фон не тёмный")
        }
    }

    // MARK: - Выбор и право

    func testUnknownIdFallsBackToBase() {
        XCTAssertEqual(Palette.palette(id: nil), Palette.pudding)
        XCTAssertEqual(Palette.palette(id: ""), Palette.pudding)
        XCTAssertEqual(Palette.palette(id: "нет такой"), Palette.pudding)
    }

    func testKnownIdResolves() {
        XCTAssertEqual(Palette.palette(id: "matcha"), Palette.matcha)
    }

    /// Потеря Pro (возврат покупки, чужое устройство) не должна ломать вид —
    /// молча откатываемся на базовую, а не показываем половину гаммы.
    func testProPaletteFallsBackWithoutEntitlement() {
        XCTAssertEqual(Palette.allowed(id: "matcha", isPro: false), Palette.pudding)
        XCTAssertEqual(Palette.allowed(id: "matcha", isPro: true), Palette.matcha)
        XCTAssertEqual(Palette.allowed(id: "pudding", isPro: false), Palette.pudding)
    }

    // MARK: - Theme

    @MainActor
    func testApplyingPaletteSwitchesThemeAndIsRevertible() {
        let original = Theme.palette
        defer { Theme.apply(original) }

        Theme.apply(.matcha)
        XCTAssertEqual(Theme.palette, Palette.matcha)

        Theme.apply(.pudding)
        XCTAssertEqual(Theme.palette, Palette.pudding)
    }
}
