import Foundation

/// Язык интерфейса: следовать системе или зафиксировать один из 14 языков.
/// Применяется через `AppleLanguages` (per-app override) и вступает в силу при
/// следующем запуске — iOS не даёт официального API смены языка на лету.
/// rawValue — это и код локали для `AppleLanguages` (кроме `system`).
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case ru, en, de, fr, es, it
    case ptBR = "pt-BR"
    case pl, tr, uk, nl, ja, ko
    case zhHans = "zh-Hans"

    var id: String { rawValue }

    /// Подпись в пикере. «Системный» переводится; названия языков — автонимы
    /// (одинаковы на любом языке UI), поэтому verbatim.
    var title: String {
        switch self {
        case .system: return String(localized: "Системный")
        case .ru:     return "Русский"
        case .en:     return "English"
        case .de:     return "Deutsch"
        case .fr:     return "Français"
        case .es:     return "Español"
        case .it:     return "Italiano"
        case .ptBR:   return "Português (Brasil)"
        case .pl:     return "Polski"
        case .tr:     return "Türkçe"
        case .uk:     return "Українська"
        case .nl:     return "Nederlands"
        case .ja:     return "日本語"
        case .ko:     return "한국어"
        case .zhHans: return "简体中文"
        }
    }

    /// Код для `AppleLanguages`. `nil` — системный (ключ удаляется).
    var appleCode: String? {
        self == .system ? nil : rawValue
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
