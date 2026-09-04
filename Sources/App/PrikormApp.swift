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

        // Привязку старых записей к ребёнку делаем ДО первой отрисовки: выборки уже
        // фильтруются по владельцу, и без этого человек после обновления увидел бы
        // пустой дневник, пока свипер не отработает. Идемпотентно и дёшево — предикат
        // ищет только записи без владельца.
        PlanMigration.ChildOwnership.apply(context: container.mainContext)
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

    /// Не `private` — на in-memory-ветку есть тест (`AppShellTests`).
    static func makeContainer(inMemory: Bool) -> ModelContainer {
        let schema = Schema(AppSchemaCurrent.models)
        // UI-тесты и демо — всегда чистая память, без облака. Плана миграции здесь
        // быть НЕ должно: мигрировать в пустой памяти нечего, а в связке с ним
        // `isStoredInMemoryOnly` не срабатывает — контейнер молча открывал обычный
        // стор, и сид `-demo` уезжал в реальный дневник и дальше в iCloud владельца.
        if inMemory {
            let memoryOnly = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [memoryOnly])
        }

        // ⚠️ БЕЗ `migrationPlan` — намеренно. С планом SwiftData сверяет отпечаток
        // схемы, которым помечен стор, со списком версий. Но все `VersionedSchema`
        // ссылаются на ОДНИ И ТЕ ЖЕ Swift-типы, поэтому любое новое поле меняет
        // смысл уже выпущенной версии, стор помечен «неизвестной» версией
        // (`Cannot use staged migration with an unknown model version`), контейнер
        // не открывается и `StoreRecovery` уводит дневник в `corrupt-*`.
        // Проверено на устройстве 03-04.09.2026: так терялись данные при обновлении.
        //
        // Без плана SwiftData делает неявную lightweight-миграцию, а все наши
        // изменения аддитивные и опциональные (требование CloudKit) — то есть ровно
        // тот случай, который она умеет. Понадобится настоящая кастомная миграция —
        // вводить план вместе с ОТДЕЛЬНЫМИ КОПИЯМИ типов моделей на каждую версию,
        // иначе повторим ту же ошибку.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                        cloudKitDatabase: .private(cloudKitContainer))
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }
        do {
            // Облако не поднялось (нет entitlement в профиле, отозван контейнер) —
            // это не повод не открыться: работаем локально, дневник важнее синка.
            let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            if let localOnly = try? ModelContainer(for: schema, configurations: [local]) {
                return localOnly
            }
            StoreRecovery.moveAside()
            if let fresh = try? ModelContainer(for: schema, configurations: [local]) {
                return fresh
            }
        }
        // Последний рубеж: память. Данные не сохранятся, но экран откроется —
        // in-memory контейнер не зависит от файлов и падать тут уже нечему.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memory])
    }
}
