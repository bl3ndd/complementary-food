import SwiftUI
import SwiftData

/// Что открывает кнопка рекапа на главной: с Pro — карусель, без Pro — пейвол.
/// (Одиночная месячная карточка для всех остаётся в календаре.)
///
/// Собирается в отдельной вьюхе со своими выборками: карусели нужен весь дневник
/// ребёнка (постер, «первый раз», топ), а главная держит в `@Query` только хвост
/// журнала за 30 дней — тянуть туда весь дневник ради кнопки нельзя (см. перф-разбор
/// в `DashboardView`).
struct RecapDestination: View {
    let child: Child
    @Query private var logs: [FoodLog]
    @Query private var statuses: [IntroductionStatus]
    @Query private var installs: [AppInstall]
    @ObservedObject private var proStore = ProStore.shared
    #if DEBUG
    @AppStorage(Entitlements.debugSimulateNewUserKey) private var simulateNewUser = false
    #else
    private let simulateNewUser = false
    #endif

    private let catalog = FoodCatalog.shared

    init(child: Child) {
        self.child = child
        let cid = child.id
        _logs = Query(FetchDescriptor<FoodLog>(predicate: #Predicate { $0.childId == cid }))
        _statuses = Query(FetchDescriptor<IntroductionStatus>(
            predicate: #Predicate { $0.childId == cid }))
    }

    private var entitlements: Entitlements {
        Entitlements(install: simulateNewUser ? nil : installs.min(by: { $0.firstLaunchedAt < $1.firstLaunchedAt }),
                     purchased: proStore.isPurchased,
                     originalAppBuild: simulateNewUser ? nil : proStore.originalAppBuild)
    }

    var body: some View {
        if entitlements.isPro {
            let service = RecapService(catalog: catalog, logs: logs)
            let month = service.recap(for: Date(), childName: child.name,
                                      ageMonths: child.ageInMonths)
            let introduced = statuses.filter { $0.state == .introduced }.map(\.foodId)
            RecapCarouselView(
                cards: RecapCardKind.carousel(
                    month: month,
                    poster: service.collectionPoster(introducedFoodIds: introduced),
                    milestone: service.milestone(introducedCount: introduced.count),
                    firstTime: service.latestFirstTime(),
                    tastes: service.tastesTop(),
                    tasteCalendar: service.tasteCalendar(for: Date())),
                childName: child.name,
                childPhoto: child.photo)
        } else {
            ProSheet(entitlements: entitlements)
        }
    }
}
