import Foundation
import SwiftData
import CloudKit

/// Хранить ли копию дневника в iCloud. Решает человек — явно, на онбординге;
/// поменять можно в Профиле. До 1.1.0 синк был включён у всех без вопроса.
enum CloudSync {
    enum Choice: String {
        case on, off
        /// Новая установка, человек ещё не ответил. Стор открыт локально.
        case undecided
    }

    static let storageKey = "sync.icloud"

    /// Что делать с этим запуском.
    ///
    /// Нет сохранённого выбора, но дневник на диске уже есть — человек обновился
    /// с 1.0, где синк работал всегда: оставляем как было, молча его не выключаем
    /// (иначе свежие записи перестали бы доезжать до второго устройства). Нет ни
    /// выбора, ни дневника — новая установка, спросим на онбординге.
    static func resolve(stored: String?, storeExists: Bool) -> Choice {
        if let stored, let choice = Choice(rawValue: stored) { return choice }
        return storeExists ? .on : .undecided
    }

    static var storeExists: Bool {
        FileManager.default.fileExists(
            atPath: StoreRecovery.defaultDirectory.appending(path: StoreRecovery.storeFiles[0]).path)
    }

    /// Вошёл ли человек в iCloud на этом устройстве. Без входа синк молча не работал
    /// бы — честнее сразу сказать.
    static func accountAvailable() async -> Bool {
        (try? await CKContainer(identifier: PrikormApp.cloudKitContainer).accountStatus()) == .available
    }
}

/// Контейнер дневника, который можно переоткрыть. Нужен ровно для одного случая:
/// на онбординге человек выбрал iCloud или «Восстановить», а стор уже открыт
/// локально — ждать перезапуска там нельзя, восстановление должно начаться сразу.
/// Смена из Профиля применяется при следующем запуске (как язык): переоткрывать
/// стор под живыми экранами с данными незачем рисковать.
@MainActor
final class DiaryStore: ObservableObject {

    static let shared: DiaryStore = {
        guard launchInMemory else { return DiaryStore(inMemory: false) }
        // Тесты и демо не читают и не пишут настоящий выбор: UI-тест, нажавший
        // «Только на телефоне», выключил бы синк владельцу телефона.
        let scratch = UserDefaults(suiteName: "DiaryStore.inMemory")!
        scratch.removePersistentDomain(forName: "DiaryStore.inMemory")
        return DiaryStore(inMemory: true, defaults: scratch, storeExists: false)
    }()

    @Published private(set) var container: ModelContainer
    /// Выбор человека. Может опережать `cloudActive` до перезапуска.
    @Published private(set) var choice: CloudSync.Choice
    /// С синком ли РЕАЛЬНО открыт стор сейчас (выбор мог поменяться до перезапуска).
    private(set) var cloudActive: Bool
    private let inMemory: Bool
    private let defaults: UserDefaults

    init(inMemory: Bool, defaults: UserDefaults = .standard, storeExists: Bool = CloudSync.storeExists) {
        let choice = CloudSync.resolve(stored: defaults.string(forKey: CloudSync.storageKey),
                                       storeExists: storeExists)
        // Фиксируем сразу: после первого запуска файл стора уже есть, и «нет выбора +
        // есть дневник» иначе прочиталось бы как обновление с 1.0 → синк без согласия.
        defaults.set(choice.rawValue, forKey: CloudSync.storageKey)
        self.inMemory = inMemory
        self.defaults = defaults
        self.choice = choice
        cloudActive = !inMemory && choice == .on
        container = PrikormApp.makeContainer(inMemory: inMemory, cloud: cloudActive)
    }

    /// Выбор уже сделан, но стор открыт по-старому — ждёт перезапуска.
    var pendingRestart: Bool { !inMemory && (choice == .on) != cloudActive }

    /// Запомнить выбор. `reopen` — только с онбординга, пока дневник пустой.
    func choose(_ choice: CloudSync.Choice, reopen: Bool = false) {
        defaults.set(choice.rawValue, forKey: CloudSync.storageKey)
        self.choice = choice
        let cloud = !inMemory && choice == .on
        guard reopen, cloud != cloudActive else { return }
        try? container.mainContext.save()
        container = PrikormApp.makeContainer(inMemory: inMemory, cloud: cloud)
        cloudActive = cloud
    }

    /// UI-тесты (-uitest) и демо (-demo) работают в in-memory сторе — реальные
    /// данные (и их копия в iCloud) не трогаются.
    private static var launchInMemory: Bool {
        #if DEBUG
        return UITestSupport.isActive || CommandLine.arguments.contains("-demo")
        #else
        return false
        #endif
    }
}
