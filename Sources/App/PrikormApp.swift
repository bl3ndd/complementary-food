import SwiftUI
import SwiftData
import UserNotifications

@main
struct PrikormApp: App {
    let container: ModelContainer

    init() {
        // Тап по пушу должен вести на нужный таб (а не открывать «в никуда»).
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared

        // UI-тесты (-uitest) работают в in-memory сторе — реальные данные не трогаем.
        var inMemory = false
        #if DEBUG
        inMemory = UITestSupport.isActive
        #endif
        container = Self.makeContainer(inMemory: inMemory)

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

    /// Контейнер с планом миграции и аварийным фолбэком.
    ///
    /// Порядок: обычный стор с миграцией → если не открылся (повреждён / схема из
    /// будущего после отката версии), уводим файлы в сторону и пробуем чистый →
    /// в самом крайнем случае in-memory, чтобы приложение всё-таки запустилось.
    /// Раньше здесь был `fatalError`: одно несовместимое изменение схемы — и у всех,
    /// кто обновился, приложение не открывается вовсе.
    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema(AppSchemaV1.models)
        // Пока локально. CloudKit включим, когда будет entitlement (SPEC §8).
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        if let container = try? ModelContainer(for: schema,
                                               migrationPlan: AppMigrationPlan.self,
                                               configurations: [config]) {
            return container
        }
        if !inMemory {
            StoreRecovery.moveAside()
            if let fresh = try? ModelContainer(for: schema,
                                               migrationPlan: AppMigrationPlan.self,
                                               configurations: [config]) {
                return fresh
            }
        }
        // Последний рубеж: память. Данные не сохранятся, но экран откроется —
        // in-memory контейнер не зависит от файлов и падать тут уже нечему.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memory])
    }
}
