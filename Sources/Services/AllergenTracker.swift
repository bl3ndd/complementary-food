import Foundation

/// Логика поддержки аллергенов (SPEC §4.3): по дате последнего приёма и частоте
/// из методики считает статус (ok / dueSoon / overdue) и дату следующего приёма.
struct AllergenTracker {
    let profile: FeedingProfile

    /// Статус поддержки по дате последнего приёма. Если ни разу не давали в
    /// поддержку — считаем просроченным (пора давать).
    func status(lastGiven: Date?, now: Date = Date()) -> AllergenStatus {
        guard let lastGiven else { return .overdue }
        let interval = profile.maintenanceIntervalDays
        let days = Calendar.current.dateComponents([.day], from: lastGiven, to: now).day ?? 0
        if days > interval { return .overdue }
        if days >= interval - 1 { return .dueSoon }
        return .ok
    }

    /// Дата, к которой нужно снова дать аллерген.
    func nextDue(lastGiven: Date?) -> Date? {
        guard let lastGiven else { return nil }
        return Calendar.current.date(byAdding: .day,
                                     value: profile.maintenanceIntervalDays,
                                     to: lastGiven)
    }
}
