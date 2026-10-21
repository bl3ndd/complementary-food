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
/// сразу после дисклеймер-гейта (MainTabView) + страховкой при первом
/// фактическом планировании. Два типа:
/// 1) **Окно ввода** — пока продукт в статусе «вводится», напоминание на ближайшие
///    дни (`intro-<ребёнок>-…`, одноразовые по датам).
/// 2) **Поддержка аллергена** — одноразовые на дату следующего приёма по плану
///    (`allergen-<ребёнок>-…`) и через два дня после неё.
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

    /// Просит разрешение ОДИН раз — при первом фактическом планировании любого
    /// напоминания (а не только при старте ввода аллергена). Если статус уже определён
    /// (выдан/отклонён) — повторно не дёргаем (iOS и так покажет промпт лишь однажды).
    func ensureAuthorized() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }
    }

    /// Пересчитывает и переставляет все напоминания (окно ввода + поддержка) —
    /// для КАЖДОГО ребёнка по его записям и его плану. Раньше всё считалось одной
    /// кучей: доза аллергена старшему гасила «пора» младшему, а одинаковые id
    /// напоминаний перетирали друг друга.
    func refresh(context: ModelContext) {
        let children = (try? context.fetch(FetchDescriptor<Child>())) ?? []
        let statuses = (try? context.fetch(FetchDescriptor<IntroductionStatus>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<FoodLog>())) ?? []
        var priority: [UNNotificationRequest] = []
        var intro: [UNNotificationRequest] = []
        for child in children {
            let own = statuses.filter { $0.childId == child.id }
            let ownLogs = logs.filter { $0.childId == child.id }
            let built = requests(forChild: child.id, profile: child.feedingProfile,
                                 statuses: own, logs: ownLogs)
            priority += built.priority
            intro += built.intro
        }
        // Приоритет при лимите iOS (64 локальных уведомления): поддержка аллергенов и
        // retry важнее окна ввода — их ставим всегда, окно ввода добиваем до лимита (B7).
        let cap = 60
        let all = Array(priority.prefix(cap)) + Array(intro.prefix(max(0, cap - priority.count)))
        // Последовательно: два refresh подряд (запуск + активация, запись + карточка)
        // раньше гонялись, и старый набор мог победить новый.
        let previous = pending
        pending = Task {
            await previous?.value
            if !all.isEmpty { await ensureAuthorized() }
            await apply(all)
        }
    }

    private var pending: Task<Void, Never>?

    /// Напоминания одного ребёнка. Чистая функция — тестируется без стора.
    func requests(forChild childId: UUID, profile: FeedingProfile,
                  statuses: [IntroductionStatus], logs: [FoodLog],
                  now: Date = Date(), calendar: Calendar = .current)
        -> (priority: [UNNotificationRequest], intro: [UNNotificationRequest]) {
        let catalog = FoodCatalog.shared
        let tag = String(childId.uuidString.prefix(8))
        let groups = AllergenMaintenance(catalog: catalog, profile: profile,
                                         statuses: statuses, logs: logs,
                                         now: now, calendar: calendar).groups()
        // Окно ввода зависит от типа продукта (аллерген/обычный) — считаем раздельно (п.10).
        let introducing = statuses.filter { $0.state == .introducing }
        let allergenIntro = introducing.filter { catalog.food(id: $0.foodId)?.isAllergen == true }
        let regularIntro = introducing.filter { catalog.food(id: $0.foodId)?.isAllergen != true }
        let priority = requests(for: groups, tag: tag, now: now, calendar: calendar)
            + retryRequests(statuses: statuses, tag: tag, now: now, calendar: calendar)
        let intro = introRequests(statuses: allergenIntro, observationDays: profile.observationDaysAllergen,
                                  logs: logs, tag: tag, now: now, calendar: calendar)
            + introRequests(statuses: regularIntro, observationDays: profile.observationDaysRegular,
                            logs: logs, tag: tag, now: now, calendar: calendar)
        return (priority, intro)
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

    /// Чистая функция: напоминания поддержки по группам аллергенов. Ставятся
    /// ЗАРАНЕЕ на дату следующего приёма по плану — для каждой введённой группы без
    /// аллергии, в том числе той, что сейчас «в норме». Раньше напоминание строилось
    /// только для уже просроченных групп, то есть приходило, лишь когда человек сам
    /// открыл приложение и увидел бейдж. Второе — через пару дней, если не дали.
    func requests(for groups: [AllergenGroupStatus],
                  tag: String = "",
                  now: Date = Date(),
                  calendar: Calendar = .current) -> [UNNotificationRequest] {
        groups.flatMap { group -> [UNNotificationRequest] in
            guard group.isIntroduced, !group.hasAllergy, let due = group.nextDue else { return [] }
            let first = nextFire(onOrAfter: due, now: now, calendar: calendar)
            let fires = [first, calendar.date(byAdding: .day, value: 2, to: first)].compactMap { $0 }
            return fires.enumerated().map { i, fire in
                let content = UNMutableNotificationContent()
                content.title = "Pudding"
                content.body = String(localized: "По твоему плану — повтор знакомого аллергена. Подробности в приложении.")
                content.sound = .default
                var comps = calendar.dateComponents([.year, .month, .day], from: fire)
                comps.hour = hour
                comps.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                return UNNotificationRequest(identifier: identifier(allergenPrefix, tag, "\(group.group.rawValue)-\(i)"),
                                             content: content, trigger: trigger)
            }
        }
    }

    /// id напоминания: `<префикс><ребёнок>-<хвост>`; без ребёнка (тесты, старые
    /// вызовы) — прежний формат `<префикс><хвост>`.
    private func identifier(_ prefix: String, _ tag: String, _ rest: String) -> String {
        tag.isEmpty ? prefix + rest : "\(prefix)\(tag)-\(rest)"
    }

    /// Ближайшие 10:00 не раньше дня `day` и строго в будущем.
    private func nextFire(onOrAfter day: Date, now: Date, calendar: Calendar) -> Date {
        let base = max(calendar.startOfDay(for: day), calendar.startOfDay(for: now))
        var comps = calendar.dateComponents([.year, .month, .day], from: base)
        comps.hour = hour
        comps.minute = minute
        let fire = calendar.date(from: comps) ?? base
        return fire > now ? fire : (calendar.date(byAdding: .day, value: 1, to: fire) ?? fire)
    }

    /// Чистая функция: напоминания о кормлении для ввода, пока не набралось нужное
    /// число дней. Ставим на `осталось + 2` ближайших дня (запас на пропуски — раньше
    /// после пропущенного дня напоминания просто кончались), начиная с сегодня, если
    /// сегодня ещё не кормили и 10:00 не прошло, иначе с завтра. Текст без счётчика:
    /// он застывал на момент планирования и врал после следующей записи.
    func introRequests(statuses: [IntroductionStatus],
                       observationDays: Int,
                       logs: [FoodLog] = [],
                       tag: String = "",
                       now: Date = Date(),
                       calendar: Calendar = .current) -> [UNNotificationRequest] {
        guard observationDays > 0 else { return [] }
        return statuses
            .filter { $0.state == .introducing }
            .compactMap { status -> [UNNotificationRequest]? in
                guard let start = status.introStartedAt else { return nil }
                let done = FeedingService.introFeedingDays(logs: logs, foodId: status.foodId,
                                                           since: start, calendar: calendar)
                let remaining = observationDays - done
                guard remaining > 0 else { return nil }

                let fedToday = logs.contains {
                    $0.foodId == status.foodId && !$0.planned
                        && calendar.isDate($0.date, inSameDayAs: now)
                }
                var first = nextFire(onOrAfter: now, now: now, calendar: calendar)
                if fedToday, calendar.isDate(first, inSameDayAs: now) {
                    first = calendar.date(byAdding: .day, value: 1, to: first) ?? first
                }
                return (0..<(remaining + 2)).compactMap { offset in
                    guard let fire = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
                    var comps = calendar.dateComponents([.year, .month, .day], from: fire)
                    comps.hour = hour
                    comps.minute = minute

                    let content = UNMutableNotificationContent()
                    content.title = "Pudding"
                    content.body = String(localized: "Сегодня по плану — кормление для ввода продукта. Подробности в приложении.")
                    content.sound = .default

                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    return UNNotificationRequest(
                        identifier: identifier(introPrefix, tag, "\(status.foodId)-\(offset)"),
                        content: content, trigger: trigger)
                }
            }
            .flatMap { $0 }
    }

    /// Чистая функция: одноразовые напоминания «попробовать продукт снова». Для
    /// статусов с будущим `retryAt` ставим one-shot на эту дату (10:00). Один
    /// запрос на продукт, id `retry-<foodId>` — повторный refresh заменяет, не плодит.
    func retryRequests(statuses: [IntroductionStatus],
                       tag: String = "",
                       now: Date = Date(),
                       calendar: Calendar = .current) -> [UNNotificationRequest] {
        statuses.compactMap { status in
            // Только для отложенных (paused): если продукт вышел из паузы, но retryAt
            // не почистился — не шлём напоминание «попробовать снова».
            guard status.state == .paused,
                  let retryAt = status.retryAt, retryAt > now else { return nil }

            let content = UNMutableNotificationContent()
            content.title = "Pudding"
            content.body = String(localized: "Сегодня — дата из твоего напоминания об отложенном продукте. Подробности в приложении.")
            content.sound = .default

            var comps = calendar.dateComponents([.year, .month, .day], from: retryAt)
            comps.hour = hour
            comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            return UNNotificationRequest(identifier: identifier(retryPrefix, tag, status.foodId),
                                         content: content, trigger: trigger)
        }
    }
}
