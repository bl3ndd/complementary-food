import XCTest
@testable import Prikorm

/// Тесты методики «свой план» (пресеты убраны, п.11) и раздельного окна
/// наблюдения для обычного продукта vs аллергена (п.10).
final class FeedingProfileTests: XCTestCase {

    private func food(_ id: String, allergen: Bool) -> Food {
        Food(id: id, name: id, category: .other, emoji: "🍎",
             isAllergen: allergen, allergenGroup: allergen ? .other : nil, minAgeMonths: 6)
    }

    // MARK: - Сборка своего плана из Child

    func testCustomProfileBuiltFromChild() {
        let child = Child(feedingProfileId: FeedingProfile.customId)
        child.customStartAgeMonths = 5
        child.customObservationDaysRegular = 4
        child.customObservationDaysAllergen = 8
        child.customAllergenFrequencyPerWeek = 1
        child.customAllergenGroups = [.egg, .fish]

        let p = child.feedingProfile
        XCTAssertEqual(p.id, FeedingProfile.customId)
        XCTAssertEqual(p.startAgeMonths, 5)
        XCTAssertEqual(p.observationDaysRegular, 4)
        XCTAssertEqual(p.observationDaysAllergen, 8)
        XCTAssertEqual(p.allergenFrequencyPerWeek, 1)
        XCTAssertEqual(p.allergenGroups, [.egg, .fish])
        XCTAssertFalse(p.name.isEmpty)
    }

    /// Любой Child даёт «свой план» — других методик нет.
    func testChildAlwaysResolvesToCustom() {
        XCTAssertEqual(Child(feedingProfileId: "aap").feedingProfile.id, FeedingProfile.customId)
        XCTAssertEqual(Child(feedingProfileId: "nope").feedingProfile.id, FeedingProfile.customId)
    }

    /// Частота 0 не должна ронять Int(Inf)-трапом (legacy/CloudKit-значение).
    func testMaintenanceIntervalGuardsAgainstZeroFrequency() {
        let p = FeedingProfile(id: "t", name: "T", startAgeMonths: 6,
                               observationDaysRegular: 3, observationDaysAllergen: 5,
                               allergenFrequencyPerWeek: 0, allergenGroups: [])
        XCTAssertEqual(p.maintenanceIntervalDays, 7, "частота 0 → знаменатель зажат в 1")
    }

    // MARK: - Раздельное окно наблюдения (п.10)

    func testObservationWindowDiffersForAllergen() {
        let child = Child(feedingProfileId: FeedingProfile.customId)
        child.customObservationDaysRegular = 3
        child.customObservationDaysAllergen = 7
        let p = child.feedingProfile

        XCTAssertEqual(p.observationDays(for: food("zucchini", allergen: false)), 3)
        XCTAssertEqual(p.observationDays(for: food("egg", allergen: true)), 7)
    }

    // MARK: - Интервал поддержки из частоты

    func testMaintenanceIntervalFromFrequency() {
        func interval(_ freq: Int) -> Int {
            let c = Child(); c.customAllergenFrequencyPerWeek = freq
            return c.feedingProfile.maintenanceIntervalDays
        }
        XCTAssertEqual(interval(1), 7)
        XCTAssertEqual(interval(2), 4)   // round(3.5)
        XCTAssertEqual(interval(3), 2)   // round(2.33)
        XCTAssertEqual(interval(7), 1)
    }

    // MARK: - Аллергены round-trip + клэмп границ

    func testCustomAllergenGroupsRoundTrip() {
        let child = Child()
        child.customAllergenGroups = [.peanut, .treenut, .sesame]
        XCTAssertEqual(child.customAllergenGroups, [.peanut, .treenut, .sesame])
        XCTAssertFalse(Child().customAllergenGroups.isEmpty)
    }

    func testClampCustomBringsValuesIntoRange() {
        let child = Child()
        child.customStartAgeMonths = 99
        child.customObservationDaysRegular = 0
        child.customObservationDaysAllergen = 99
        child.customAllergenFrequencyPerWeek = 50
        child.clampCustom()
        XCTAssertEqual(child.customStartAgeMonths, FeedingProfile.CustomLimits.startAge.upperBound)
        XCTAssertEqual(child.customObservationDaysRegular, FeedingProfile.CustomLimits.observation.lowerBound)
        XCTAssertEqual(child.customObservationDaysAllergen, FeedingProfile.CustomLimits.observation.upperBound)
        XCTAssertEqual(child.customAllergenFrequencyPerWeek, FeedingProfile.CustomLimits.frequency.upperBound)
    }

    func testCustomDefaultsAreSane() {
        let p = Child(feedingProfileId: FeedingProfile.customId).feedingProfile
        XCTAssertTrue((4...8).contains(p.startAgeMonths))
        XCTAssertTrue((1...14).contains(p.observationDaysRegular))
        XCTAssertTrue((1...14).contains(p.observationDaysAllergen))
        XCTAssertGreaterThanOrEqual(p.maintenanceIntervalDays, 1)
        XCTAssertFalse(p.allergenGroups.isEmpty)
    }
}
