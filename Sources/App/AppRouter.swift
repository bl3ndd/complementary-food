import SwiftUI
import UserNotifications

/// Глобальный роутер: какой таб выбран. Тап по пушу переключает таб (B-fix: пуш вёл
/// в никуда). Синглтон — чтобы делегат уведомлений и MainTabView делили одно состояние.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var selectedTab: MainTabView.Tab = .today
    /// Продукт, который надо открыть по тапу пуша (Каталог провалится в карточку).
    @Published var pendingFoodId: String?
}

/// Делегат уведомлений: показывает баннер в активном приложении и по тапу ведёт на
/// нужный таб (allergen-… → «Аллергены», intro-/retry-… → «Каталог» + карточка продукта).
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let id = response.notification.request.identifier
        if id.hasPrefix("allergen-") {
            await MainActor.run { AppRouter.shared.selectedTab = .allergens }
        } else if let fid = Self.foodId(fromNotificationId: id) {
            await MainActor.run {
                AppRouter.shared.selectedTab = .catalog
                AppRouter.shared.pendingFoodId = fid
            }
        }
    }

    /// Достаёт foodId из id пуша: `retry-<foodId>` / `intro-<foodId>-<день>`.
    /// foodId может содержать дефисы (`custom-<uuid>`), поэтому у intro отрезаем
    /// только последний `-<день>`. Публичная static — чтобы покрыть тестом.
    static func foodId(fromNotificationId id: String) -> String? {
        if id.hasPrefix("retry-") { return String(id.dropFirst("retry-".count)) }
        if id.hasPrefix("intro-") {
            let rest = String(id.dropFirst("intro-".count))
            if let dash = rest.range(of: "-", options: .backwards) {
                return String(rest[..<dash.lowerBound])
            }
            return rest
        }
        return nil
    }
}
