import XCTest
@testable import Prikorm

/// Карточки карусели — это то, что мама выкладывает в сторис. Ошибка здесь не
/// падает приложением, а публично врёт: не тот продукт «первым», не та веха, не
/// тот топ. Плюс всё, что считается через словари, обязано быть детерминированным —
/// иначе карточка меняется между запусками на одних и тех же данных.
final class RecapCardsTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)   // 14.11.2023
    private var cal = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        cal.timeZone = TimeZone(identifier: "UTC")!
    }

    private func day(_ offset: Int, hour: Int = 12) -> Date {
        let base = cal.date(byAdding: .day, value: offset, to: now)!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: base)!
    }

    private func food(_ id: String) -> Food {
        Food(id: id, name: id.capitalized, category: .vegetable,
             emoji: "🥦", isAllergen: false, allergenGroup: nil, minAgeMonths: 6)
    }

    private func service(_ logs: [FoodLog], foods: [Food]) -> RecapService {
        RecapService(catalog: FoodCatalog(foods: foods), logs: logs, calendar: cal)
    }

    // MARK: - Постер коллекции

    func testPosterOrdersByFirstTasting() {
        let foods = [food("apple"), food("pear"), food("plum")]
        let logs = [
            FoodLog(foodId: "plum", date: day(-1), type: .intro),
            FoodLog(foodId: "apple", date: day(-10), type: .intro),
            FoodLog(foodId: "pear", date: day(-5), type: .intro),
        ]
        let poster = service(logs, foods: foods)
            .collectionPoster(introducedFoodIds: ["apple", "pear", "plum"])

        XCTAssertEqual(poster.foods.map(\.id), ["apple", "pear", "plum"],
                       "порядок знакомства, а не порядок массива на входе")
        XCTAssertEqual(poster.count, 3)
    }

    func testPosterIgnoresFoodsMissingFromCatalog() {
        let logs = [FoodLog(foodId: "apple", date: day(-1), type: .intro)]
        let poster = service(logs, foods: [food("apple")])
            .collectionPoster(introducedFoodIds: ["apple", "удалённый"])
        XCTAssertEqual(poster.foods.map(\.id), ["apple"])
    }

    func testEmptyPosterIsEmptyNotCrash() {
        let poster = service([], foods: []).collectionPoster(introducedFoodIds: [])
        XCTAssertTrue(poster.isEmpty)
        XCTAssertEqual(poster.count, 0)
    }

    // MARK: - Вехи

    func testMilestoneOnExactStep() {
        let s = service([], foods: [])
        XCTAssertEqual(s.milestone(introducedCount: 10)?.reached, 10)
        XCTAssertEqual(s.milestone(introducedCount: 25)?.reached, 25)
    }

    func testMilestoneBelowFirstStepIsNil() {
        XCTAssertNil(service([], foods: []).milestone(introducedCount: 9),
                     "ниже первой планки хвастаться нечем")
        XCTAssertNil(service([], foods: []).milestone(introducedCount: 0))
    }

    func testMilestoneTakesTheHighestReachedStep() {
        let m = service([], foods: []).milestone(introducedCount: 26)
        XCTAssertEqual(m?.reached, 25, "26 — это ещё веха 25, а не 50")
        XCTAssertEqual(m?.total, 26)
    }

    // MARK: - «Первый раз»

    func testLatestFirstTimeTakesTheNewestDebut() {
        let foods = [food("apple"), food("pear")]
        let logs = [
            FoodLog(foodId: "apple", date: day(-10), type: .intro, liking: .liked),
            FoodLog(foodId: "apple", date: day(-1), type: .maintenance),   // не дебют
            FoodLog(foodId: "pear", date: day(-5), type: .intro, liking: .neutral),
        ]
        let ft = service(logs, foods: foods).latestFirstTime()
        XCTAssertEqual(ft?.food.id, "pear", "груша дебютировала позже яблока")
        XCTAssertEqual(ft?.date, day(-5))
        XCTAssertEqual(ft?.liking, .neutral)
    }

    func testLatestFirstTimeIgnoresPlannedLogs() {
        let foods = [food("apple"), food("pear")]
        let logs = [
            FoodLog(foodId: "apple", date: day(-10), type: .intro),
            FoodLog(foodId: "pear", date: day(1), type: .intro, planned: true),
        ]
        let ft = service(logs, foods: foods).latestFirstTime()
        XCTAssertEqual(ft?.food.id, "apple", "план — это не «попробовали»")
    }

    func testLatestFirstTimeIsNilOnEmptyDiary() {
        XCTAssertNil(service([], foods: []).latestFirstTime())
    }

    // MARK: - Топ вкусов

    func testTopRanksByCountOfRatings() {
        let foods = [food("apple"), food("pear"), food("plum")]
        let logs = [
            FoodLog(foodId: "apple", date: day(-3), type: .maintenance, liking: .liked),
            FoodLog(foodId: "apple", date: day(-2), type: .maintenance, liking: .liked),
            FoodLog(foodId: "pear", date: day(-1), type: .maintenance, liking: .liked),
            FoodLog(foodId: "plum", date: day(-1), type: .maintenance, liking: .disliked),
        ]
        let top = service(logs, foods: foods).tastesTop()
        XCTAssertEqual(top.liked.map(\.id), ["apple", "pear"])
        XCTAssertEqual(top.disliked.map(\.id), ["plum"])
    }

    /// Ничья по числу оценок обязана разводиться детерминированно, иначе карточка
    /// меняет порядок между запусками на одних и тех же данных.
    func testTiesAreBrokenByFirstRatingDateAndStableAcrossRuns() {
        let foods = [food("apple"), food("pear")]
        let logs = [
            FoodLog(foodId: "pear", date: day(-1), type: .maintenance, liking: .liked),
            FoodLog(foodId: "apple", date: day(-5), type: .maintenance, liking: .liked),
        ]
        let first = service(logs, foods: foods).tastesTop().liked.map(\.id)
        XCTAssertEqual(first, ["apple", "pear"], "раньше попробовали — раньше в топе")

        for _ in 0..<20 {
            XCTAssertEqual(service(logs, foods: foods).tastesTop().liked.map(\.id), first)
        }
    }

    func testTopRespectsLimit() {
        let ids = (1...8).map { "food\($0)" }
        let foods = ids.map { food($0) }
        let logs = ids.enumerated().map { i, id in
            FoodLog(foodId: id, date: day(-i - 1), type: .maintenance, liking: .liked)
        }
        XCTAssertEqual(service(logs, foods: foods).tastesTop(limit: 5).liked.count, 5)
    }

    func testEmptyTopOnDiaryWithoutRatings() {
        let logs = [FoodLog(foodId: "apple", date: day(-1), type: .intro)]
        let top = service(logs, foods: [food("apple")]).tastesTop()
        XCTAssertTrue(top.isEmpty)
    }

    // MARK: - Набор карточек карусели

    private func emptyMonth() -> MonthRecap {
        MonthRecap(month: now, childName: "Эмма", ageMonths: 7, triedFoods: [],
                   newCount: 0, totalLogs: 0, favorite: nil)
    }

    private func fullMonth() -> MonthRecap {
        MonthRecap(month: now, childName: "Эмма", ageMonths: 7, triedFoods: [food("apple")],
                   newCount: 1, totalLogs: 3, favorite: nil)
    }

    /// Пустая карточка в сторис выглядит как баг, поэтому в набор она не попадает.
    func testCarouselSkipsEmptyCards() {
        let cards = RecapCardKind.carousel(
            month: emptyMonth(),
            poster: CollectionPoster(foods: [], count: 0),
            milestone: nil,
            firstTime: nil,
            tastes: TastesTop(liked: [], disliked: []),
            tasteCalendar: TasteCalendar(month: now, days: []))
        XCTAssertTrue(cards.isEmpty)
    }

    func testCarouselKeepsFilledCardsAndPutsMonthFirst() {
        let cards = RecapCardKind.carousel(
            month: fullMonth(),
            poster: CollectionPoster(foods: [food("apple")], count: 1),
            milestone: Milestone(reached: 10, total: 11),
            firstTime: nil,
            tastes: TastesTop(liked: [food("apple")], disliked: []),
            tasteCalendar: TasteCalendar(month: now, days: [3]))

        XCTAssertEqual(cards.map(\.id), ["month", "poster", "milestone", "tastes", "calendar"])
        XCTAssertEqual(cards.first?.id, "month", "бесплатная месячная карточка — крючок, она первая")
    }

    // MARK: - Календарь вкусов

    func testCalendarMarksOnlyDebutDays() {
        let foods = [food("apple"), food("pear")]
        let apple = day(-3), pear = day(-1)
        let logs = [
            FoodLog(foodId: "apple", date: apple, type: .intro),
            FoodLog(foodId: "apple", date: day(-2), type: .maintenance),  // повтор, не дебют
            FoodLog(foodId: "pear", date: pear, type: .intro),
        ]
        let c = service(logs, foods: foods).tasteCalendar(for: now)
        XCTAssertEqual(c.days, [cal.component(.day, from: apple),
                                cal.component(.day, from: pear)].sorted())
    }

    func testCalendarIgnoresOtherMonths() {
        let foods = [food("apple")]
        let logs = [FoodLog(foodId: "apple", date: day(-60), type: .intro)]
        XCTAssertEqual(service(logs, foods: foods).tasteCalendar(for: now).days, [])
    }

    func testCalendarOnEmptyDiary() {
        XCTAssertEqual(service([], foods: []).tasteCalendar(for: now).days, [])
    }
}
