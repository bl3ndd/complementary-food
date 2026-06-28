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

    // MARK: - Свой план (custom)

    func testCustomProfileBuiltFromChild() {
        let child = Child(feedingProfileId: FeedingProfile.customId)
        child.customStartAgeMonths = 5
        child.customObservationDays = 7
        child.customAllergenFrequencyPerWeek = 1
        child.customAllergenGroups = [.egg, .fish]

        let p = child.feedingProfile
        XCTAssertEqual(p.id, FeedingProfile.customId)
        XCTAssertFalse(p.isPreset)
        XCTAssertEqual(p.startAgeMonths, 5)
        XCTAssertEqual(p.observationDays, 7)
        XCTAssertEqual(p.allergenFrequencyPerWeek, 1)
        XCTAssertEqual(p.allergenGroups, [.egg, .fish])
        XCTAssertFalse(p.source.isEmpty)
        XCTAssertFalse(p.caveat.isEmpty)
    }

    func testChildFallsBackToPresetForNonCustomId() {
        XCTAssertEqual(Child(feedingProfileId: "aap").feedingProfile.id, "aap")
        XCTAssertEqual(Child(feedingProfileId: "nope").feedingProfile.id, FeedingProfile.who.id)
    }

    func testCustomAllergenGroupsRoundTrip() {
        let child = Child()
        child.customAllergenGroups = [.peanut, .treenut, .sesame]
        XCTAssertEqual(child.customAllergenGroups, [.peanut, .treenut, .sesame])
        // Дефолт парсится в непустой список.
        XCTAssertFalse(Child().customAllergenGroups.isEmpty)
    }

    func testClampCustomBringsValuesIntoRange() {
        let child = Child()
        child.customStartAgeMonths = 99
        child.customObservationDays = 0
        child.customAllergenFrequencyPerWeek = 50
        child.clampCustom()
        XCTAssertEqual(child.customStartAgeMonths, FeedingProfile.CustomLimits.startAge.upperBound)
        XCTAssertEqual(child.customObservationDays, FeedingProfile.CustomLimits.observation.lowerBound)
        XCTAssertEqual(child.customAllergenFrequencyPerWeek, FeedingProfile.CustomLimits.frequency.upperBound)
    }

    func testCustomDefaultsAreSane() {
        let p = Child(feedingProfileId: FeedingProfile.customId).feedingProfile
        XCTAssertTrue((4...8).contains(p.startAgeMonths))
        XCTAssertTrue((1...14).contains(p.observationDays))
        XCTAssertGreaterThanOrEqual(p.maintenanceIntervalDays, 1)
    }
}
