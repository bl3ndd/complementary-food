import SwiftUI
import SwiftData
import UserNotifications

@main
struct PrikormApp: App {
    let container: ModelContainer

    init() {
        // Тап по пушу должен вести на нужный таб (а не открывать «в никуда»).
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared

        let schema = Schema([Child.self, IntroductionStatus.self, FoodLog.self, LogPhoto.self, CustomFood.self])
        // UI-тесты (-uitest) работают в in-memory сторе — реальные данные не трогаем.
        var inMemory = false
        #if DEBUG
        inMemory = UITestSupport.isActive
        #endif
        // Пока локально. CloudKit включим, когда будет dev-аккаунт + entitlement (SPEC §8).
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }

        #if DEBUG
        if CommandLine.arguments.contains("-seedSample") {
            SampleData.seed(container.mainContext)
        }
        if UITestSupport.isActive {
            UITestSupport.prepare(container.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
