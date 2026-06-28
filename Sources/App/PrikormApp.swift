import SwiftUI
import SwiftData

@main
struct PrikormApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Child.self, IntroductionStatus.self, FoodLog.self, CustomFood.self])
        // Пока локально. CloudKit включим, когда будет dev-аккаунт + entitlement (SPEC §8).
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }

        #if DEBUG
        if CommandLine.arguments.contains("-seedSample") {
            SampleData.seed(container.mainContext)
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
