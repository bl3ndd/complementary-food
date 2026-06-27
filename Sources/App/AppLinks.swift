import Foundation

/// Внешние ссылки приложения (политика, условия, поддержка, источники методик).
///
/// ⚠️ TODO перед релизом: подтвердить домен и заполнить боевыми URL после деплоя
/// сайта (см. `docs/plans/20260626-website-landing.md`). Сейчас — `getpudding.com`
/// как плейсхолдер.
enum AppLinks {
    static let privacyPolicyURL = URL(string: "https://getpudding.com/privacy.html")!
    static let termsURL = URL(string: "https://getpudding.com/terms.html")!
    static let methodologyInfoURL = URL(string: "https://getpudding.com/#method")!
    static let supportEmail = "hello@getpudding.com"

    static var supportMailto: URL { URL(string: "mailto:\(supportEmail)")! }
}

extension Bundle {
    /// Версия приложения для экрана «О приложении» (CFBundleShortVersionString).
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
