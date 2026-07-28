import SwiftUI

/// Оформление приложения: следовать системе или зафиксировать светлую/тёмную.
///
/// В отличие от языка применяется **сразу**, без перезапуска: это просто
/// `preferredColorScheme` на корне. Хранится в `@AppStorage("app.theme")`, поэтому
/// UI-тесты могут форсировать тему аргументом запуска `-app.theme dark`.
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "app.theme"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return String(localized: "Системная")
        case .light:  return String(localized: "Светлая")
        case .dark:   return String(localized: "Тёмная")
        }
    }

    /// `nil` — отдаём решение системе.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
