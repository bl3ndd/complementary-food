import XCTest
@testable import Prikorm

/// Копия в iCloud — только с согласия. Ошибка здесь либо молча отправляет дневник
/// в облако, либо молча выключает синк у тех, кто обновился с 1.0.
@MainActor
final class CloudSyncTests: XCTestCase {

    private func isolatedDefaults() -> UserDefaults {
        let name = "CloudSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testNewInstallIsUndecided() {
        XCTAssertEqual(CloudSync.resolve(stored: nil, storeExists: false), .undecided)
    }

    /// Обновился с 1.0, где синк был всегда: не выключаем его молча.
    func testUpdateFromOneZeroKeepsSyncOn() {
        XCTAssertEqual(CloudSync.resolve(stored: nil, storeExists: true), .on)
    }

    func testStoredChoiceWins() {
        XCTAssertEqual(CloudSync.resolve(stored: "off", storeExists: true), .off)
        XCTAssertEqual(CloudSync.resolve(stored: "on", storeExists: false), .on)
    }

    /// Первый запуск создаёт файл стора. Если не запомнить «не решил», второй запуск
    /// прочитал бы «нет выбора + есть дневник» как обновление с 1.0 и включил синк.
    func testUndecidedSurvivesSecondLaunch() {
        let defaults = isolatedDefaults()
        _ = DiaryStore(inMemory: true, defaults: defaults, storeExists: false)
        let second = DiaryStore(inMemory: true, defaults: defaults, storeExists: true)
        XCTAssertEqual(second.choice, .undecided)
    }

    func testChoiceIsRemembered() {
        let defaults = isolatedDefaults()
        let store = DiaryStore(inMemory: true, defaults: defaults, storeExists: false)
        store.choose(.off)
        XCTAssertEqual(store.choice, .off)
        XCTAssertEqual(DiaryStore(inMemory: true, defaults: defaults, storeExists: true).choice, .off)
    }

    /// In-memory (тесты, демо) никогда не уходит в облако и не ждёт перезапуска.
    func testInMemoryNeverGoesToCloud() {
        let store = DiaryStore(inMemory: true, defaults: isolatedDefaults(), storeExists: true)
        XCTAssertEqual(store.choice, .on)
        XCTAssertFalse(store.cloudActive)
        XCTAssertFalse(store.pendingRestart)
    }
}
