import Foundation
import SwiftData
import UserNotifications

/// Абстракция над `UNUserNotificationCenter` — чтобы планировщик напоминаний
/// можно было протестировать без системного центра (Task 6).
protocol NotificationScheduling {
    func pendingIdentifiers() async -> [String]
    func removePending(identifiers: [String])
    func add(_ request: UNNotificationRequest)
}

extension UNUserNotificationCenter: NotificationScheduling {
    func pendingIdentifiers() async -> [String] {
        await pendingNotificationRequests().map(\.identifier)
    }

    func removePending(identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ request: UNNotificationRequest) {
        add(request, withCompletionHandler: nil)
    }
}

/// Локальные напоминания о поддержке аллергенов (SPEC §4.3, §12).
/// Разрешение просим контекстно — при вводе первого аллергена, не в онбординге.
/// Для каждой «просроченной/скоро» группы ставим еженедельное повторяющееся
/// напоминание (`UNCalendarNotificationTrigger`, repeats: true) в день недели
/// следующего приёма — так толерантность поддерживается без ручного перепланирования.
final class NotificationManager {
    static let shared = NotificationManager()

    private let center: NotificationScheduling
    private let prefix = "allergen-"
    /// Время суток напоминания.
    private let hour = 10
    private let minute = 0

    init(center: NotificationScheduling = UNUserNotificationCenter.current()) {
        self.center = center
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    /// Пересчитывает и переставляет напоминания по текущим данным.
    func refresh(context: ModelContext, profile: FeedingProfile) {
        let statuses = (try? context.fetch(FetchDescriptor<IntroductionStatus>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<FoodLog>())) ?? []
        let groups = AllergenMaintenance(catalog: .shared,
                                         profile: profile,
                                         statuses: statuses,
                                         logs: logs).groups()
        Task { await apply(groups) }
    }

    /// Снимает старые «аллергенные» напоминания и ставит новые по группам.
    /// Вынесено отдельно (async) для детерминированного теста с моком центра.
    func apply(_ groups: [AllergenGroupStatus]) async {
        let stale = (await center.pendingIdentifiers()).filter { $0.hasPrefix(prefix) }
        center.removePending(identifiers: stale)
        for request in requests(for: groups) {
            center.add(request)
        }
    }

    /// Чистая функция: строит запросы напоминаний по группам. Берём только
    /// введённые группы без аллергии, у которых статус не `.ok` (пора/скоро) и
    /// есть дата следующего приёма. Триггер — еженедельный повтор по дню недели.
    func requests(for groups: [AllergenGroupStatus],
                  calendar: Calendar = .current) -> [UNNotificationRequest] {
        groups.compactMap { group in
            guard group.isIntroduced, !group.hasAllergy, group.status != .ok,
                  let due = group.nextDue else { return nil }

            // Текст намеренно общий: не называем конкретный аллерген, чтобы на
            // локскране не светились данные о здоровье ребёнка (App Review 4.5.4).
            let content = UNMutableNotificationContent()
            content.title = "Pudding"
            content.body = "Пора освежить введённый аллерген — загляни в приложение."
            content.sound = .default

            var comps = DateComponents()
            comps.weekday = calendar.component(.weekday, from: due)
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

            return UNNotificationRequest(identifier: prefix + group.group.rawValue,
                                         content: content,
                                         trigger: trigger)
        }
    }
}
