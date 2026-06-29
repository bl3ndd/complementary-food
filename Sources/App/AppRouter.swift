import SwiftUI
import UserNotifications

/// Глобальный роутер: какой таб выбран. Тап по пушу переключает таб (B-fix: пуш вёл
/// в никуда). Синглтон — чтобы делегат уведомлений и MainTabView делили одно состояние.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    @Published var selectedTab: MainTabView.Tab = .today
}

/// Делегат уведомлений: показывает баннер в активном приложении и по тапу ведёт на
/// нужный таб (allergen-… → «Аллергены», intro-/retry-… → «Каталог»).
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let id = response.notification.request.identifier
        let tab: MainTabView.Tab? = id.hasPrefix("allergen-") ? .allergens
            : (id.hasPrefix("intro-") || id.hasPrefix("retry-")) ? .catalog : nil
        guard let tab else { return }
        await MainActor.run { AppRouter.shared.selectedTab = tab }
    }
}
