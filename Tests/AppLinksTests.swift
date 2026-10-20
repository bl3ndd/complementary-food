import XCTest
@testable import Prikorm

/// Ссылки «О приложении» ведут на сайт на языке приложения. Ошибка тут —
/// 404 или чужой язык, и заметит её только пользователь.
final class AppLinksTests: XCTestCase {

    func testSitePagesAreRussianOrEnglish() {
        XCTAssertEqual(AppLinks.privacyPolicyURL(language: "ru").absoluteString,
                       "https://babyfooddiary.com/privacy")
        XCTAssertEqual(AppLinks.termsURL(language: "ru").absoluteString,
                       "https://babyfooddiary.com/terms")
        XCTAssertEqual(AppLinks.methodologyInfoURL(language: "ru").absoluteString,
                       "https://babyfooddiary.com/method", "без якоря: отдельная страница источников")
        for language in ["en", "de", "ja", "zh-Hans"] {
            XCTAssertEqual(AppLinks.privacyPolicyURL(language: language).absoluteString,
                           "https://babyfooddiary.com/en/privacy", language)
            XCTAssertEqual(AppLinks.termsURL(language: language).absoluteString,
                           "https://babyfooddiary.com/en/terms", language)
            XCTAssertEqual(AppLinks.methodologyInfoURL(language: language).absoluteString,
                           "https://babyfooddiary.com/en/method", language)
        }
    }
}
