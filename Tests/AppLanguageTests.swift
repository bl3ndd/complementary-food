import XCTest
@testable import Prikorm

/// Тесты выбора языка (per-app override через AppleLanguages).
final class AppLanguageTests: XCTestCase {

    private let suite = "AppLanguageTests.defaults"

    private func makeDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)   // чистый старт
        return d
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testAppleCodeMapping() {
        XCTAssertNil(AppLanguage.system.appleCode, "системный — без override")
        XCTAssertEqual(AppLanguage.ru.appleCode, "ru")
        XCTAssertEqual(AppLanguage.en.appleCode, "en")
    }

    func testApplyWritesAndClearsAppleLanguages() {
        let d = makeDefaults()
        let key = LanguageManager.appleLanguagesKey

        LanguageManager.apply(.en, to: d)
        XCTAssertEqual(d.stringArray(forKey: key), ["en"])

        LanguageManager.apply(.ru, to: d)
        XCTAssertEqual(d.stringArray(forKey: key), ["ru"])

        // Системный — снимаем override. Читаем НАШ домен, а не глобальный AppleLanguages
        // (он протекает в симулятор как [en-RU, ru-RU] и ломал бы array(forKey:)).
        LanguageManager.apply(.system, to: d)
        XCTAssertNil(d.persistentDomain(forName: suite)?[key],
                     "системный режим убирает override из нашего домена")
    }

    func testEveryCaseHasNonEmptyTitle() {
        for lang in AppLanguage.allCases {
            XCTAssertFalse(lang.title.trimmingCharacters(in: .whitespaces).isEmpty,
                           "\(lang.rawValue): пустая подпись")
        }
    }
}
