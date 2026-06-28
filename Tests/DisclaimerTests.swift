import XCTest
@testable import Prikorm

/// Тест единого медицинского дисклеймера (App Review 1.4.1): текст непустой и
/// содержит ключевой призыв консультироваться с педиатром.
/// `Disclaimer.medical` локализован, поэтому проверяем призыв к врачу
/// локале-независимо (ru «педиатр» / en «pediatric»).
final class DisclaimerTests: XCTestCase {

    func testMedicalDisclaimerMentionsPediatrician() {
        let text = Disclaimer.medical
        XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(text.localizedCaseInsensitiveContains("педиатр")
                      || text.localizedCaseInsensitiveContains("pediatric"),
                      "дисклеймер должен звать к педиатру/врачу (1.4.1)")
    }

    func testShortDisclaimerNotEmpty() {
        XCTAssertFalse(Disclaimer.short.trimmingCharacters(in: .whitespaces).isEmpty)
        XCTAssertTrue(Disclaimer.short.localizedCaseInsensitiveContains("педиатр"))
    }
}
