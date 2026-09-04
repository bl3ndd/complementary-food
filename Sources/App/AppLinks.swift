import Foundation

/// Внешние ссылки приложения (политика, условия, поддержка, источники методик).
///
/// Сайт живёт на `babyfooddiary.com`. Старый `pudding-for-children.vercel.app`
/// остаётся с 301 навсегда: в уже выпущенных билдах эти адреса зашиты в бинарник
/// и обновятся только у тех, кто поставит новую версию.
/// (Vercel, бесплатный
/// поддомен). ⚠️ TODO перед релизом: подтвердить рабочий support-email.
enum AppLinks {
    static let privacyPolicyURL = URL(string: "https://babyfooddiary.com/privacy")!
    static let termsURL = URL(string: "https://babyfooddiary.com/terms")!
    static let methodologyInfoURL = URL(string: "https://babyfooddiary.com/#method")!
    static let supportEmail = "woodoo201818@gmail.com"

    static var supportMailto: URL { URL(string: "mailto:\(supportEmail)")! }
}

extension Bundle {
    /// Версия приложения для экрана «О приложении» (CFBundleShortVersionString).
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
