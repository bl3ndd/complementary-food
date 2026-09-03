import SwiftUI

/// Пара «цвет для светлой / цвет для тёмной».
struct ColorPair: Equatable {
    let light: Color
    let dark: Color
}

/// Цветовая гамма приложения.
///
/// Палитра меняет **акцент и фоновую подложку**, но НЕ трогает нейтральные
/// поверхности (`card` / `fill` / `hairline` / `cardStroke`): они построены на
/// прозрачностях и одинаково работают в любой гамме. Так палитр меньше по коду
/// и, главное, нельзя случайно уронить контраст текста на карточке.
///
/// Все гаммы приглушённые и десатурированные — один акцент, почти нейтральный
/// фон. Кислота и неон исключены не из вкусовщины: на них ломается контраст
/// текста и лезут проблемы с доступностью.
struct Palette: Identifiable, Equatable {

    let id: String
    /// Ключ локализации названия (сами строки — в `Localizable.xcstrings`).
    ///
    /// «Персик» и «Черника» совпадают с названиями продуктов каталога — и это
    /// нормально: слово одно и то же, перевод во всех 14 языках тот же. Разводить
    /// ключи, как пришлось с «Поддержкой» (Maintenance против Support), тут не надо.
    let titleKey: String
    /// Бесплатна только базовая гамма, остальные — часть Pro.
    let isPro: Bool

    let accent: ColorPair
    let accentDeep: ColorPair
    let bgTop: ColorPair
    let bgBottom: ColorPair

    var title: String { String(localized: String.LocalizationValue(titleKey)) }

    /// Ключ в `UserDefaults`. Смена гаммы применяется сразу — это не язык,
    /// перезапуск не нужен (см. `AppTheme`).
    static let storageKey = "app.palette"

    /// Базовая гамма — та самая, с которой приложение вышло. Всегда бесплатна и
    /// служит запасным вариантом, если выбранная недоступна.
    static let pudding = Palette(
        id: "pudding", titleKey: "Пудинг", isPro: false,
        accent:     ColorPair(light: Color(red: 0.99, green: 0.49, blue: 0.31),
                              dark:  Color(red: 1.00, green: 0.58, blue: 0.42)),
        accentDeep: ColorPair(light: Color(red: 0.97, green: 0.33, blue: 0.44),
                              dark:  Color(red: 0.98, green: 0.44, blue: 0.54)),
        bgTop:      ColorPair(light: Color(red: 1.00, green: 0.98, blue: 0.93),
                              dark:  Color(red: 0.09, green: 0.07, blue: 0.11)),
        bgBottom:   ColorPair(light: Color(red: 1.00, green: 0.92, blue: 0.94),
                              dark:  Color(red: 0.13, green: 0.09, blue: 0.13)))

    static let marshmallow = Palette(
        id: "marshmallow", titleKey: "Зефир", isPro: true,
        accent:     ColorPair(light: Color(red: 0.87, green: 0.55, blue: 0.60),
                              dark:  Color(red: 0.92, green: 0.64, blue: 0.69)),
        accentDeep: ColorPair(light: Color(red: 0.78, green: 0.45, blue: 0.55),
                              dark:  Color(red: 0.85, green: 0.55, blue: 0.65)),
        bgTop:      ColorPair(light: Color(red: 0.99, green: 0.96, blue: 0.96),
                              dark:  Color(red: 0.10, green: 0.07, blue: 0.09)),
        bgBottom:   ColorPair(light: Color(red: 0.97, green: 0.93, blue: 0.95),
                              dark:  Color(red: 0.14, green: 0.10, blue: 0.13)))

    static let matcha = Palette(
        id: "matcha", titleKey: "Матча", isPro: true,
        accent:     ColorPair(light: Color(red: 0.47, green: 0.62, blue: 0.45),
                              dark:  Color(red: 0.58, green: 0.74, blue: 0.56)),
        accentDeep: ColorPair(light: Color(red: 0.36, green: 0.50, blue: 0.36),
                              dark:  Color(red: 0.47, green: 0.63, blue: 0.47)),
        bgTop:      ColorPair(light: Color(red: 0.98, green: 0.98, blue: 0.94),
                              dark:  Color(red: 0.07, green: 0.09, blue: 0.08)),
        bgBottom:   ColorPair(light: Color(red: 0.94, green: 0.96, blue: 0.91),
                              dark:  Color(red: 0.10, green: 0.13, blue: 0.11)))

    static let lavender = Palette(
        id: "lavender", titleKey: "Лаванда", isPro: true,
        accent:     ColorPair(light: Color(red: 0.56, green: 0.51, blue: 0.72),
                              dark:  Color(red: 0.68, green: 0.63, blue: 0.85)),
        accentDeep: ColorPair(light: Color(red: 0.45, green: 0.40, blue: 0.62),
                              dark:  Color(red: 0.57, green: 0.52, blue: 0.76)),
        bgTop:      ColorPair(light: Color(red: 0.98, green: 0.97, blue: 0.99),
                              dark:  Color(red: 0.08, green: 0.07, blue: 0.11)),
        bgBottom:   ColorPair(light: Color(red: 0.95, green: 0.94, blue: 0.98),
                              dark:  Color(red: 0.11, green: 0.10, blue: 0.15)))

    static let peach = Palette(
        id: "peach", titleKey: "Персик", isPro: true,
        accent:     ColorPair(light: Color(red: 0.91, green: 0.62, blue: 0.45),
                              dark:  Color(red: 0.95, green: 0.70, blue: 0.53)),
        accentDeep: ColorPair(light: Color(red: 0.84, green: 0.50, blue: 0.38),
                              dark:  Color(red: 0.90, green: 0.60, blue: 0.47)),
        bgTop:      ColorPair(light: Color(red: 1.00, green: 0.98, blue: 0.95),
                              dark:  Color(red: 0.10, green: 0.08, blue: 0.07)),
        bgBottom:   ColorPair(light: Color(red: 0.99, green: 0.94, blue: 0.90),
                              dark:  Color(red: 0.14, green: 0.11, blue: 0.09)))

    static let honey = Palette(
        id: "honey", titleKey: "Молоко и мёд", isPro: true,
        accent:     ColorPair(light: Color(red: 0.76, green: 0.62, blue: 0.40),
                              dark:  Color(red: 0.85, green: 0.72, blue: 0.50)),
        accentDeep: ColorPair(light: Color(red: 0.65, green: 0.51, blue: 0.31),
                              dark:  Color(red: 0.76, green: 0.62, blue: 0.41)),
        bgTop:      ColorPair(light: Color(red: 1.00, green: 0.99, blue: 0.97),
                              dark:  Color(red: 0.09, green: 0.08, blue: 0.07)),
        bgBottom:   ColorPair(light: Color(red: 0.98, green: 0.96, blue: 0.91),
                              dark:  Color(red: 0.13, green: 0.11, blue: 0.09)))

    static let blueberry = Palette(
        id: "blueberry", titleKey: "Черника", isPro: true,
        accent:     ColorPair(light: Color(red: 0.42, green: 0.45, blue: 0.68),
                              dark:  Color(red: 0.56, green: 0.60, blue: 0.82)),
        accentDeep: ColorPair(light: Color(red: 0.32, green: 0.34, blue: 0.55),
                              dark:  Color(red: 0.45, green: 0.48, blue: 0.70)),
        bgTop:      ColorPair(light: Color(red: 0.97, green: 0.97, blue: 0.99),
                              dark:  Color(red: 0.07, green: 0.07, blue: 0.10)),
        bgBottom:   ColorPair(light: Color(red: 0.93, green: 0.94, blue: 0.98),
                              dark:  Color(red: 0.10, green: 0.10, blue: 0.14)))

    static let all: [Palette] = [pudding, marshmallow, matcha, lavender, peach, honey, blueberry]

    static func palette(id: String?) -> Palette {
        all.first { $0.id == id } ?? pudding
    }

    /// Гамма, которую можно применить с текущим правом. Потеря Pro не должна
    /// ломать вид приложения — молча откатываемся на базовую.
    static func allowed(id: String?, isPro: Bool) -> Palette {
        let p = palette(id: id)
        return (p.isPro && !isPro) ? pudding : p
    }
}
