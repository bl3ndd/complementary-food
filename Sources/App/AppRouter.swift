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
    /// Чей это пуш: первые 8 символов id ребёнка. Корень переключает активного
    /// ребёнка — иначе пуш младшего открыл бы карточку в дневнике старшего.
    @Published var pendingChildTag: String?
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
        let tag = Self.childTag(fromNotificationId: id)
        if id.hasPrefix("allergen-") {
            await MainActor.run {
                AppRouter.shared.pendingChildTag = tag
                AppRouter.shared.selectedTab = .allergens
            }
        } else if let fid = Self.foodId(fromNotificationId: id) {
            await MainActor.run {
                AppRouter.shared.pendingChildTag = tag
                AppRouter.shared.selectedTab = .catalog
                AppRouter.shared.pendingFoodId = fid
            }
        }
    }

    private static let prefixes = ["allergen-", "intro-", "retry-"]

    /// Тело id без префикса и без тега ребёнка. Тег — 8 hex-символов и дефис;
    /// у пушей прошлых версий (до раздельных напоминаний) тега нет.
    private static func split(_ id: String) -> (tag: String?, rest: String)? {
        guard let prefix = prefixes.first(where: { id.hasPrefix($0) }) else { return nil }
        let rest = String(id.dropFirst(prefix.count))
        let head = rest.prefix(9)
        if head.count == 9, head.last == "-",
           head.dropLast().allSatisfy({ $0.isHexDigit && !$0.isLowercase }) {
            return (String(head.dropLast()), String(rest.dropFirst(9)))
        }
        return (nil, rest)
    }

    static func childTag(fromNotificationId id: String) -> String? { split(id)?.tag }

    /// Достаёт foodId из id пуша: `retry-<ребёнок>-<foodId>` /
    /// `intro-<ребёнок>-<foodId>-<день>` (и старые форматы без ребёнка). foodId
    /// может содержать дефисы (`custom-<uuid>`), поэтому у intro отрезаем только
    /// последний `-<день>`. Публичная static — чтобы покрыть тестом.
    static func foodId(fromNotificationId id: String) -> String? {
        guard let (_, rest) = split(id) else { return nil }
        if id.hasPrefix("retry-") { return rest }
        if id.hasPrefix("intro-") {
            if let dash = rest.range(of: "-", options: .backwards) {
                return String(rest[..<dash.lowerBound])
            }
            return rest
        }
        return nil
    }
}
