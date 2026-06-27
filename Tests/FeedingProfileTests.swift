import XCTest
@testable import Prikorm

/// Тесты пресетов методик: верифицированность (источник + оговорка у каждого) и
/// разумность цифр (App Review 1.4.1 — methodology disclosure).
final class FeedingProfileTests: XCTestCase {

    func testEveryPresetCarriesAVerifiedSource() {
        for p in FeedingProfile.presets {
            XCTAssertFalse(p.source.trimmingCharacters(in: .whitespaces).isEmpty,
                           "\(p.id): пустой source")
            XCTAssertFalse(p.caveat.trimmingCharacters(in: .whitespaces).isEmpty,
                           "\(p.id): пустой caveat")
            let url = URL(string: p.sourceURL)
            XCTAssertNotNil(url, "\(p.id): невалидный sourceURL")
            XCTAssertEqual(url?.scheme, "https", "\(p.id): sourceURL должен быть https")
        }
    }

    func testPresetNumbersInSaneRanges() {
        for p in FeedingProfile.presets {
            XCTAssertTrue((4...7).contains(p.startAgeMonths), "\(p.id): старт вне 4–7")
            XCTAssertTrue((1...14).contains(p.observationDays), "\(p.id): окно вне 1–14")
            XCTAssertTrue((1...7).contains(p.allergenFrequencyPerWeek), "\(p.id): частота вне 1–7")
            XCTAssertFalse(p.allergenGroups.isEmpty, "\(p.id): пустой список аллергенов")
            XCTAssertGreaterThanOrEqual(p.maintenanceIntervalDays, 1, "\(p.id): интервал < 1")
        }
    }

    func testPresetLookupFallsBackToWho() {
        XCTAssertEqual(FeedingProfile.preset(id: "does-not-exist").id, FeedingProfile.who.id)
        XCTAssertEqual(FeedingProfile.preset(id: "aap").id, "aap")
    }
}
