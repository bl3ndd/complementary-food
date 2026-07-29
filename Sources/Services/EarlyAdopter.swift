import Foundation
import SwiftData

/// Кто пришёл в бесплатную эпоху приложения.
///
/// Пока платных возможностей нет вообще, и обещание «ранним — пожизненно»
/// держится ровно на одной записи `AppInstall`: она ставится при первом запуске
/// и синхронизируется через iCloud. Когда появится Pro, здесь же будет решаться,
/// кому его открывать бесплатно — по дате первого запуска, а не по честному слову.
struct EarlyAdopter {
    let context: ModelContext

    /// Возвращает запись о первом запуске, создавая её при необходимости.
    /// Идемпотентна: повторные вызовы не плодят записи и не двигают дату.
    @discardableResult
    func registerIfNeeded(now: Date = Date(), version: String = Bundle.main.appVersion) -> AppInstall {
        let existing = (try? context.fetch(FetchDescriptor<AppInstall>())) ?? []
        // Дубли теоретически возможны при гонке двух устройств на одном iCloud —
        // берём самую раннюю запись, она и есть «когда пришёл».
        if let earliest = existing.min(by: { $0.firstLaunchedAt < $1.firstLaunchedAt }) {
            return earliest
        }
        let install = AppInstall(firstLaunchedAt: now, firstVersion: version)
        context.insert(install)
        try? context.save()
        return install
    }
}
