import Foundation

/// Когда просить оценку в App Store.
///
/// Логика вынесена из вью, чтобы её можно было проверить тестом, а не «на глаз»
/// в проде. Правила простые и намеренно скупые:
/// 1. Просим **только после успеха** — юзер довёл продукт до «Ввёл успешно».
/// 2. Не в первый раз: первый ввод — это ещё не «приложение мне помогает».
/// 3. Не чаще одного раза на версию приложения (iOS сверху всё равно режет до 3 раз
///    в год, но своя защита честнее — не долбим на каждом апдейте).
enum AppReview {
    /// Ключ в `UserDefaults`, где лежит версия, на которой уже просили.
    static let lastAskedVersionKey = "review.lastAskedVersion"

    /// На каком по счёту введённом продукте просим.
    static let milestone = 3

    /// Стоит ли показать промпт прямо сейчас.
    /// - Parameters:
    ///   - introducedCount: сколько продуктов уже в статусе «введён» (включая текущий).
    ///   - lastAskedVersion: версия, на которой просили в прошлый раз (`nil` — не просили).
    ///   - currentVersion: текущая `CFBundleShortVersionString`.
    static func shouldAsk(introducedCount: Int,
                          lastAskedVersion: String?,
                          currentVersion: String) -> Bool {
        guard introducedCount >= milestone else { return false }
        return lastAskedVersion != currentVersion
    }

    /// Запомнить, что на этой версии уже просили.
    static func remember(version: String, defaults: UserDefaults = .standard) {
        defaults.set(version, forKey: lastAskedVersionKey)
    }

    static func lastAskedVersion(defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: lastAskedVersionKey)
    }
}
