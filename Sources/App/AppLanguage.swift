import Foundation

/// Язык интерфейса: следовать системе или зафиксировать RU/EN.
/// Применяется через `AppleLanguages` (per-app override) и вступает в силу при
/// следующем запуске — iOS не даёт официального API смены языка на лету.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, ru, en

    var id: String { rawValue }

    /// Подпись в пикере. «Системный» переводится; названия языков — автонимы
    /// (одинаковы на любом языке UI), поэтому verbatim.
    var title: String {
        switch self {
        case .system: return String(localized: "Системный")
        case .ru:     return "Русский"
        case .en:     return "English"
        }
    }

    /// Код для `AppleLanguages`. `nil` — системный (ключ удаляется).
    var appleCode: String? {
        switch self {
        case .system: return nil
        case .ru:     return "ru"
        case .en:     return "en"
        }
    }
}

/// Пишет выбор языка в `AppleLanguages` (per-app override). `UserDefaults`
/// инъектируется ради детерминированного теста (CLAUDE.md).
enum LanguageManager {
    static let appleLanguagesKey = "AppleLanguages"

    static func apply(_ language: AppLanguage, to defaults: UserDefaults = .standard) {
        if let code = language.appleCode {
            defaults.set([code], forKey: appleLanguagesKey)
        } else {
            defaults.removeObject(forKey: appleLanguagesKey)
        }
    }
}
