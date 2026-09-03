import Foundation

/// Единственный ответ на вопрос «открыт ли Pro».
///
/// Право = **куплено В App Store ИЛИ пользователь пришёл до платной версии**.
/// Второе — не маркетинг, а обязательство: ранним пользователям обещан пожизненный
/// доступ, и обещание подкреплено записью `AppInstall`, которую ставит `EarlyAdopter`
/// с первого запуска (см. `Sources/Models/AppInstall.swift`).
///
/// Сервис намеренно ничего не знает ни про StoreKit, ни про системные часы: всё, что
/// нужно для решения, приходит на вход. Поэтому логику можно проверить тестами, а
/// вьюхи — писать за этим швом ещё до того, как появится настоящая покупка.
struct Entitlements {

    /// Версия, начиная с которой Pro стал платным. Все, кто поставил приложение на
    /// более раннюю версию, получают его бесплатно навсегда.
    ///
    /// Ставить фактическую версию нужно **в момент выпуска платной сборки**, не раньше:
    /// пока значение выше реальной версии в сторе, ранними считаются вообще все — что
    /// для периода «Pro ещё не выпущен» как раз и верно.
    static let defaultProVersion = "1.1.0"

    /// Запасная граница на случай, когда версию в записи прочитать не удалось.
    /// Дата первой платной сборки; всё, что раньше — ранний пользователь.
    static let defaultProReleaseDate = Date(timeIntervalSince1970: 1_788_000_000)

    /// Запись о первом запуске. `nil` — записи нет (значит человек пришёл уже
    /// после того, как `EarlyAdopter` начал их ставить, либо стор пустой).
    let install: AppInstall?
    /// Покупка подтверждена App Store.
    let purchased: Bool

    var proVersion: String = Entitlements.defaultProVersion
    var proReleaseDate: Date = Entitlements.defaultProReleaseDate

    /// Пришёл ли человек до платной версии.
    ///
    /// Основной признак — `firstVersion`: он точнее даты, потому что не зависит от
    /// того, когда именно сборка доехала до конкретного пользователя. Но поле
    /// CloudKit-safe, то есть имеет дефолт `""` и теоретически может приехать пустым
    /// при частичном синке — тогда откатываемся на дату. Здесь мы намеренно щедры:
    /// человек, реально пришедший рано, не должен терять статус из-за поля, которое
    /// не доехало.
    var isEarlyAdopter: Bool {
        guard let install else { return false }

        let version = install.firstVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isVersion(version) {
            // `.numeric` — иначе «1.10.0» окажется меньше «1.9.0» посимвольно.
            return version.compare(proVersion, options: .numeric) == .orderedAscending
        }
        return install.firstLaunchedAt < proReleaseDate
    }

    var isPro: Bool { purchased || isEarlyAdopter }

    /// Строка похожа на версию, если непустая и состоит только из цифр и точек.
    /// Всё остальное («», «TestFlight», мусор из миграции) считаем непрочитанным.
    private static func isVersion(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        return s.allSatisfy { $0.isNumber || $0 == "." } && s.contains(where: \.isNumber)
    }
}
