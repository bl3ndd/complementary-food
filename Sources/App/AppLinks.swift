import Foundation

/// Внешние ссылки приложения (политика, условия, поддержка, источники методик).
///
/// Сайт задеплоен на `pudding-for-children.vercel.app` (Vercel, бесплатный
/// поддомен). ⚠️ TODO перед релизом: подтвердить рабочий support-email.
enum AppLinks {
    static let privacyPolicyURL = URL(string: "https://pudding-for-children.vercel.app/privacy")!
    static let termsURL = URL(string: "https://pudding-for-children.vercel.app/terms")!
    static let methodologyInfoURL = URL(string: "https://pudding-for-children.vercel.app/#method")!
    static let supportEmail = "woodoo201818@gmail.com"

    static var supportMailto: URL { URL(string: "mailto:\(supportEmail)")! }
}

extension Bundle {
    /// Версия приложения для экрана «О приложении» (CFBundleShortVersionString).
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
