import UIKit

/// Альтернативные иконки приложения — часть Pro.
///
/// Иконка привязана к цветовой гамме: выбрал «Матчу» — можешь поставить зелёную
/// иконку на домашний экран. Отдельного списка иконок нет намеренно, иначе
/// пришлось бы объяснять пользователю две почти одинаковые настройки.
///
/// Маппинг чистый и тестируемый; сама смена (`setAlternateIconName`) работает
/// только в живом приложении, поэтому вынесена отдельным методом.
enum AppIconManager {

    /// Имена наборов в каталоге ассетов. Должны совпадать с
    /// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` в `project.yml`.
    static let names: [String: String] = [
        Palette.marshmallow.id: "AppIconMarshmallow",
        Palette.matcha.id:      "AppIconMatcha",
        Palette.lavender.id:    "AppIconLavender",
        Palette.peach.id:       "AppIconPeach",
        Palette.honey.id:       "AppIconHoney",
        Palette.blueberry.id:   "AppIconBlueberry",
    ]

    /// Имя иконки для гаммы. `nil` — основная иконка приложения.
    ///
    /// Без Pro всегда основная: потеря покупки не должна оставлять человека с
    /// иконкой, за которую он больше не платит, но и ломать ничего не должна.
    static func iconName(for paletteId: String?, isPro: Bool) -> String? {
        guard isPro, let paletteId, let name = names[paletteId] else { return nil }
        return name
    }

    /// Применить иконку. Системный алерт «иконка изменена» показывает iOS сама —
    /// подавить его нельзя, и это нормально.
    @MainActor
    static func apply(paletteId: String?, isPro: Bool) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let wanted = iconName(for: paletteId, isPro: isPro)
        guard wanted != UIApplication.shared.alternateIconName else { return }
        UIApplication.shared.setAlternateIconName(wanted)
    }
}
