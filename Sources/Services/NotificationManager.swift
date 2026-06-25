import Foundation
import SwiftData
import UserNotifications

/// Локальные напоминания о поддержке аллергенов (SPEC §4.3, §12).
/// Разрешение просим контекстно — при вводе первого аллергена, не в онбординге.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let prefix = "allergen-"

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    /// Пересчитывает и переставляет напоминания по текущим данным.
    func refresh(context: ModelContext, profile: FeedingProfile) {
        let statuses = (try? context.fetch(FetchDescriptor<IntroductionStatus>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<FoodLog>())) ?? []
        let groups = AllergenMaintenance(catalog: .shared,
                                         profile: profile,
                                         statuses: statuses,
                                         logs: logs).groups()
        schedule(groups)
    }

    private func schedule(_ groups: [AllergenGroupStatus]) {
        // Снимаем старые «аллергенные» напоминания.
        center.getPendingNotificationRequests { [prefix, center] requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }

        let calendar = Calendar.current
        for group in groups where group.isIntroduced && !group.hasAllergy {
            guard let due = group.nextDue, due > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Пора дать аллерген"
            content.body = "Не забудь дать «\(group.group.title)» — поддерживаем толерантность."
            content.sound = .default

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: due)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: prefix + group.group.rawValue,
                                                content: content,
                                                trigger: trigger)
            center.add(request)
        }
    }
}
