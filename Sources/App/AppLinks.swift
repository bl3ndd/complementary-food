import Foundation

/// Внешние ссылки приложения (политика, условия, поддержка, источники методик).
///
/// Сайт живёт на `babyfooddiary.com`. Старый `pudding-for-children.vercel.app`
/// остаётся с 301 навсегда: в уже выпущенных билдах эти адреса зашиты в бинарник
/// и обновятся только у тех, кто поставит новую версию.
/// (Vercel, бесплатный
/// поддомен). ⚠️ TODO перед релизом: подтвердить рабочий support-email.
enum AppLinks {
    static let site = "https://babyfooddiary.com"

    /// Язык, на котором приложение сейчас показано: выбранный в «Языке» или
    /// системный. Именно он, а не язык устройства — иначе человек, переключивший
    /// приложение на английский, попадал бы на русский сайт.
    static var appLanguage: String { Bundle.main.preferredLocalizations.first ?? "en" }

    /// Политика, условия и источники методики есть только на русском и английском
    /// (ручные страницы `site/*.html`): остальные языки ведут на английскую версию —
    /// так же, как ссылки с локализованных лендингов.
    static func legalPath(for language: String) -> String {
        language == "ru" ? "" : "/en"
    }

    static func privacyPolicyURL(language: String = appLanguage) -> URL {
        URL(string: "\(site)\(legalPath(for: language))/privacy")!
    }

    static func termsURL(language: String = appLanguage) -> URL {
        URL(string: "\(site)\(legalPath(for: language))/terms")!
    }

    static func methodologyInfoURL(language: String = appLanguage) -> URL {
        URL(string: "\(site)\(legalPath(for: language))/method")!
    }

    static let supportEmail = "woodoo201818@gmail.com"

    static var supportMailto: URL { URL(string: "mailto:\(supportEmail)")! }
}

extension Bundle {
    /// Версия приложения для экрана «О приложении» (CFBundleShortVersionString).
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
