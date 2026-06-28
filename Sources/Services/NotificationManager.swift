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

/// Локальные напоминания по методике (SPEC §4.2/4.3, §12). Разрешение просим
/// контекстно — при вводе первого аллергена, не в онбординге. Два типа:
/// 1) **Окно ввода** — пока продукт в статусе «вводится», ежедневное напоминание
///    давать его каждый день окна наблюдения (`intro-…`, одноразовые по датам).
/// 2) **Поддержка аллергена** — для введённых групп еженедельный повтор по дню
///    недели следующего приёма (`allergen-…`, `repeats: true`), чтобы не терялась
///    толерантность.
/// Тексты нейтральны: не называем продукт/аллерген на локскрине (App Review 4.5.4).
final class NotificationManager {
    static let shared = NotificationManager()

    private let center: NotificationScheduling
    private let allergenPrefix = "allergen-"
    private let introPrefix = "intro-"
    private let retryPrefix = "retry-"
    /// Время суток напоминания.
    private let hour = 10
    private let minute = 0

    init(center: NotificationScheduling = UNUserNotificationCenter.current()) {
        self.center = center
    }

    /// Снимает все наши напоминания (при сбросе данных).
    func clearAll() {
        Task {
            let ours = (await center.pendingIdentifiers())
                .filter { $0.hasPrefix(allergenPrefix) || $0.hasPrefix(introPrefix) || $0.hasPrefix(retryPrefix) }
            center.removePending(identifiers: ours)
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    /// Пересчитывает и переставляет все напоминания (окно ввода + поддержка).
    func refresh(context: ModelContext, profile: FeedingProfile) {
        let statuses = (try? context.fetch(FetchDescriptor<IntroductionStatus>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<FoodLog>())) ?? []
        let catalog = FoodCatalog.shared
        let groups = AllergenMaintenance(catalog: catalog,
                                         profile: profile,
                                         statuses: statuses,
                                         logs: logs).groups()
        // Окно ввода зависит от типа продукта (аллерген/обычный) — считаем раздельно (п.10).
        let introducing = statuses.filter { $0.state == .introducing }
        let allergenIntro = introducing.filter { catalog.food(id: $0.foodId)?.isAllergen == true }
        let regularIntro = introducing.filter { catalog.food(id: $0.foodId)?.isAllergen != true }
        let all = requests(for: groups)
            + introRequests(statuses: allergenIntro, observationDays: profile.observationDaysAllergen)
            + introRequests(statuses: regularIntro, observationDays: profile.observationDaysRegular)
            + retryRequests(statuses: statuses)
        Task { await apply(all) }
    }

    /// Снимает наши прошлые напоминания (intro-/allergen-) и ставит переданные.
    /// Чужие заявки не трогаем. Async — для детерминированного теста с моком центра.
    func apply(_ requests: [UNNotificationRequest]) async {
        let stale = (await center.pendingIdentifiers())
            .filter { $0.hasPrefix(allergenPrefix) || $0.hasPrefix(introPrefix) || $0.hasPrefix(retryPrefix) }
        center.removePending(identifiers: stale)
        for request in requests {
            center.add(request)
        }
    }

    /// Чистая функция: еженедельные напоминания поддержки по группам аллергенов.
    /// Берём введённые группы без аллергии со статусом не `.ok` (пора/скоро) и
    /// датой следующего приёма. Триггер — еженедельный повтор по дню недели.
    func requests(for groups: [AllergenGroupStatus],
                  calendar: Calendar = .current) -> [UNNotificationRequest] {
        groups.compactMap { group in
            guard group.isIntroduced, !group.hasAllergy, group.status != .ok,
                  let due = group.nextDue else { return nil }

            let content = UNMutableNotificationContent()
            content.title = "Pudding"
            content.body = String(localized: "Пора освежить введённый аллерген — загляни в приложение.")
            content.sound = .default

            var comps = DateComponents()
            comps.weekday = calendar.component(.weekday, from: due)
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

            return UNNotificationRequest(identifier: allergenPrefix + group.group.rawValue,
                                         content: content,
                                         trigger: trigger)
        }
    }

    /// Чистая функция: ежедневные напоминания на окно наблюдения. Для каждого
    /// продукта в статусе «вводится» ставим по одному напоминанию на каждый день
    /// окна (день 1…N), пропуская дни, чьё время уже прошло. Одноразовые триггеры.
    func introRequests(statuses: [IntroductionStatus],
                       observationDays: Int,
                       now: Date = Date(),
                       calendar: Calendar = .current) -> [UNNotificationRequest] {
        guard observationDays > 0 else { return [] }
        return statuses
            .filter { $0.state == .introducing }
            .compactMap { status -> [UNNotificationRequest]? in
                guard let start = status.introStartedAt else { return nil }
                let startDay = calendar.startOfDay(for: start)
                return (1...observationDays).compactMap { day in
                    guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: startDay)
                    else { return nil }
                    var comps = calendar.dateComponents([.year, .month, .day], from: dayDate)
                    comps.hour = hour
                    comps.minute = minute
                    guard let fire = calendar.date(from: comps), fire > now else { return nil }

                    let content = UNMutableNotificationContent()
                    content.title = "Pudding"
                    content.body = String(localized: "Продолжай вводить продукт — день \(day) из \(observationDays). Следи за реакцией 👀")
                    content.sound = .default

                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    return UNNotificationRequest(
                        identifier: "\(introPrefix)\(status.foodId)-\(day)",
                        content: content, trigger: trigger)
                }
            }
            .flatMap { $0 }
    }

    /// Чистая функция: одноразовые напоминания «попробовать продукт снова». Для
    /// статусов с будущим `retryAt` ставим one-shot на эту дату (10:00). Один
    /// запрос на продукт, id `retry-<foodId>` — повторный refresh заменяет, не плодит.
    func retryRequests(statuses: [IntroductionStatus],
                       now: Date = Date(),
                       calendar: Calendar = .current) -> [UNNotificationRequest] {
        statuses.compactMap { status in
            guard let retryAt = status.retryAt, retryAt > now else { return nil }

            let content = UNMutableNotificationContent()
            content.title = "Pudding"
            content.body = String(localized: "Можно снова попробовать отложенный продукт — загляни в приложение.")
            content.sound = .default

            var comps = calendar.dateComponents([.year, .month, .day], from: retryAt)
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            return UNNotificationRequest(identifier: retryPrefix + status.foodId,
                                         content: content, trigger: trigger)
        }
    }
}
