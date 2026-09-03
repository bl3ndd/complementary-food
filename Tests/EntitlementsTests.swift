import XCTest
@testable import Prikorm

/// Право на Pro — это обязательство перед ранними пользователями, а не фича.
/// Ошибка здесь либо отбирает обещанное у тех, кто пришёл в начале, либо раздаёт
/// Pro всем подряд. Поэтому границы проверяются поштучно.
final class EntitlementsTests: XCTestCase {

    private let proVersion = "1.1.0"
    private let released = Date(timeIntervalSince1970: 1_788_000_000)

    private func install(_ version: String, at date: Date? = nil) -> AppInstall {
        AppInstall(firstLaunchedAt: date ?? released.addingTimeInterval(-86_400),
                   firstVersion: version)
    }

    private func ent(_ install: AppInstall?, purchased: Bool = false) -> Entitlements {
        Entitlements(install: install, purchased: purchased,
                     proVersion: proVersion, proReleaseDate: released)
    }

    // MARK: - Ранний пользователь

    func testNoInstallRecordIsNotEarly() {
        let e = ent(nil)
        XCTAssertFalse(e.isEarlyAdopter)
        XCTAssertFalse(e.isPro)
    }

    func testVersionBelowProVersionIsEarly() {
        XCTAssertTrue(ent(install("1.0.0")).isEarlyAdopter)
        XCTAssertTrue(ent(install("1.0.9")).isEarlyAdopter)
    }

    func testProVersionItselfIsNotEarly() {
        XCTAssertFalse(ent(install("1.1.0")).isEarlyAdopter,
                       "версия, в которой Pro стал платным, уже не ранняя")
    }

    func testVersionAboveProVersionIsNotEarly() {
        XCTAssertFalse(ent(install("1.2.0")).isEarlyAdopter)
        XCTAssertFalse(ent(install("2.0.0")).isEarlyAdopter)
    }

    /// Посимвольное сравнение считает «1.10.0» меньше «1.9.0» — и человек с более
    /// новой версией получил бы Pro бесплатно.
    func testVersionsCompareNumericallyNotLexicographically() {
        let e = Entitlements(install: install("1.10.0"), purchased: false,
                             proVersion: "1.9.0", proReleaseDate: released)
        XCTAssertFalse(e.isEarlyAdopter, "1.10.0 новее 1.9.0, а не старше")
    }

    // MARK: - Когда версию прочитать не удалось

    /// `firstVersion` имеет дефолт "" (требование CloudKit) и может приехать пустым
    /// при частичном синке. Тогда решает дата — и решает щедро.
    func testEmptyVersionFallsBackToDateAndStaysEarly() {
        let e = ent(install("", at: released.addingTimeInterval(-86_400)))
        XCTAssertTrue(e.isEarlyAdopter)
    }

    func testEmptyVersionWithLateDateIsNotEarly() {
        let e = ent(install("", at: released.addingTimeInterval(86_400)))
        XCTAssertFalse(e.isEarlyAdopter)
    }

    func testGarbageVersionFallsBackToDate() {
        XCTAssertTrue(ent(install("TestFlight",
                                  at: released.addingTimeInterval(-1))).isEarlyAdopter)
        XCTAssertFalse(ent(install("TestFlight",
                                   at: released.addingTimeInterval(1))).isEarlyAdopter)
    }

    // MARK: - Покупка

    func testPurchaseGrantsProRegardlessOfInstallRecord() {
        XCTAssertTrue(ent(nil, purchased: true).isPro)
        XCTAssertTrue(ent(install("2.0.0"), purchased: true).isPro)
    }

    func testEarlyAdopterIsProWithoutPurchase() {
        let e = ent(install("1.0.0"))
        XCTAssertTrue(e.isPro)
        XCTAssertFalse(e.purchased, "ранний получает Pro не через покупку")
    }

    func testLateUserWithoutPurchaseIsNotPro() {
        XCTAssertFalse(ent(install("1.2.0")).isPro)
    }

    // MARK: - Дефолты

    /// Пока платная сборка не вышла, `defaultProVersion` выше реальной версии в
    /// сторе — и ранними считаются все, кто уже пользуется. Это и есть верное
    /// поведение на период «Pro ещё не выпущен».
    func testDefaultsTreatCurrentUsersAsEarly() {
        let e = Entitlements(install: AppInstall(firstVersion: "1.0.0"), purchased: false)
        XCTAssertTrue(e.isEarlyAdopter)
    }
}
