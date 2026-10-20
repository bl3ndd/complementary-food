import XCTest
import SwiftUI
@testable import Prikorm

/// Рендер каждой карточки рекапа в PNG — то, что реально уедет в сторис.
/// Проверяет, что карточка собирается в картинку нужного размера, и прикладывает
/// её к результату прогона: так оформление можно оценить глазами, не листая
/// карусель на телефоне.
@MainActor
final class RecapRenderTests: XCTestCase {

    private func sample() -> (RecapService, [String]) {
        let foods = Array(FoodCatalog.shared.all.prefix(14))
        let cal = Calendar.current
        let now = Date()
        var logs: [FoodLog] = []
        for (i, food) in foods.enumerated() {
            let date = cal.date(byAdding: .day, value: -i, to: now)!
            let liking: Liking = i % 4 == 3 ? .disliked : .liked
            logs.append(FoodLog(foodId: food.id, date: date, type: .intro, liking: liking))
        }
        let service = RecapService(catalog: FoodCatalog.shared, logs: logs)
        return (service, foods.prefix(12).map(\.id))
    }

    func testEveryCardRendersAtStoryFrame() throws {
        let (service, introduced) = sample()
        let month = service.recap(for: Date(), childName: "Мия", ageMonths: 7)
        let cards = RecapCardKind.carousel(
            month: month,
            poster: service.collectionPoster(introducedFoodIds: introduced),
            milestone: service.milestone(introducedCount: introduced.count),
            firstTime: service.latestFirstTime(),
            tastes: service.tastesTop(),
            tasteCalendar: service.tasteCalendar(for: Date()))
        XCTAssertEqual(cards.count, 6, "на полном дневнике в карусели все шесть карточек")

        for kind in cards {
            let view = RecapCarouselView.cardView(kind, childName: "Мия", childPhoto: nil)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage, kind.id)
            XCTAssertEqual(image.size, CGSize(width: 360, height: 640), kind.id)

            let attachment = XCTAttachment(image: image)
            attachment.name = "recap_\(kind.id)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
