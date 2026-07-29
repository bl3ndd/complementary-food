import SwiftUI
import SwiftData
import UserNotifications

@main
struct PrikormApp: App {
    let container: ModelContainer

    init() {
        // Тап по пушу должен вести на нужный таб (а не открывать «в никуда»).
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared

        // UI-тесты (-uitest) и демо (-demo) работают в in-memory сторе — реальные
        // данные (и их копия в iCloud) не трогаются.
        var inMemory = false
        #if DEBUG
        let demo = CommandLine.arguments.contains("-demo")
        inMemory = UITestSupport.isActive || demo
        #endif
        container = Self.makeContainer(inMemory: inMemory)

        #if DEBUG
        if demo {
            // Дневник за ~4 месяца: смотреть, как приложение живёт на реальном объёме.
            SampleData.seedDiary(container.mainContext)
        }
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
    /// Приватная база CloudKit пользователя. Наших серверов нет: данные едут в
    /// личный iCloud владельца устройства, мы к ним доступа не имеем.
    static let cloudKitContainer = "iCloud.com.pudding.app"

    private static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema(AppSchemaCurrent.models)
        // UI-тесты — всегда чистая память, без облака.
        let config = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                 cloudKitDatabase: .private(cloudKitContainer))

        if let container = try? ModelContainer(for: schema,
                                               migrationPlan: AppMigrationPlan.self,
                                               configurations: [config]) {
            return container
        }
        if !inMemory {
            // Облако не поднялось (нет entitlement в профиле, отозван контейнер) —
            // это не повод не открыться: работаем локально, дневник важнее синка.
            let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            if let localOnly = try? ModelContainer(for: schema,
                                                   migrationPlan: AppMigrationPlan.self,
                                                   configurations: [local]) {
                return localOnly
            }
            StoreRecovery.moveAside()
            if let fresh = try? ModelContainer(for: schema,
                                               migrationPlan: AppMigrationPlan.self,
                                               configurations: [local]) {
                return fresh
            }
        }
        // Последний рубеж: память. Данные не сохранятся, но экран откроется —
        // in-memory контейнер не зависит от файлов и падать тут уже нечему.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memory])
    }
}
