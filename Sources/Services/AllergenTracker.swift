import Foundation

/// Логика поддержки аллергенов (SPEC §4.3): по дате последнего приёма и частоте
/// из методики считает статус (ok / dueSoon / overdue) и дату следующего приёма.
struct AllergenTracker {
    let profile: FeedingProfile

    /// Статус поддержки по дате последнего приёма. Если ни разу не давали в
    /// поддержку — считаем просроченным (пора давать).
    func status(lastGiven: Date?, now: Date = Date(),
                calendar: Calendar = .current) -> AllergenStatus {
        guard let lastGiven else { return .overdue }
        let interval = profile.maintenanceIntervalDays
        // Считаем ПЕРЕСЕЧЁННЫЕ календарные дни (как окно наблюдения), а не 24-часовые
        // кванты от времени дозы: «дал вчера» → уже не сегодня, независимо от времени.
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: lastGiven),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        if days > interval { return .overdue }
        // max(1, …): при дневной частоте (interval=1) «сегодня» (days=0) — это ok,
        // а не вечный dueSoon (B6). Для обычных интервалов поведение прежнее.
        if days >= max(1, interval - 1) { return .dueSoon }
        return .ok
    }

    /// Дата, к которой нужно снова дать аллерген.
    func nextDue(lastGiven: Date?, calendar: Calendar = .current) -> Date? {
        guard let lastGiven else { return nil }
        return calendar.date(byAdding: .day,
                             value: profile.maintenanceIntervalDays,
                             to: lastGiven)
    }
}
