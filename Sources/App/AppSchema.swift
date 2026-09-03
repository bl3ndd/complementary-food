import Foundation
import SwiftData

/// Версионированная схема хранилища.
///
/// Зачем: без плана миграции любое несовместимое изменение моделей после релиза
/// роняет приложение на старте (`ModelContainer` бросает, а App-init не умеет
/// «просто продолжить»). С планом SwiftData сам проводит стор через стадии.
///
/// **Как добавлять изменения:** заводим `AppSchemaV2` с новым набором моделей,
/// кладём его в `AppMigrationPlan.schemas` и описываем переход в `stages`
/// (`.lightweight`, если поля добавляются с дефолтами — это наш обычный случай,
/// потому что модели CloudKit-safe: всё опционально или с дефолтом).
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Child.self, IntroductionStatus.self, FoodLog.self, LogPhoto.self, CustomFood.self]
    }
}

/// V2: добавлена `AppInstall` — отметка «когда пришёл» под обещание пожизненного
/// доступа ранним пользователям. Новая сущность = lightweight-переход.
enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 1, 0) }

    static var models: [any PersistentModel.Type] {
        AppSchemaV1.models + [AppInstall.self]
    }
}

/// **Ловушка, проверенная на устройстве 03.09.2026.** Правило «меняешь модели —
/// заводи следующую версию» работает, когда добавляешь НОВЫЙ ТИП: так V2 добавила
/// `AppInstall`, и схемы стали различимы. Для нового ПОЛЯ у существующего типа оно
/// не работает: все `VersionedSchema` ссылаются на одни и те же Swift-типы, поэтому
/// поле появляется сразу во всех версиях, две соседние становятся неотличимы, и
/// SwiftData падает при построении пути миграции — тест-хост умирал с `signal abrt`
/// ещё до подключения.
///
/// Поэтому опциональное поле (`Child.photo`) добавлено В ТЕКУЩУЮ версию, без бампа:
/// SwiftData мигрирует такое сам, существующие записи получают `nil`. Заводить
/// новую версию имеет смысл только вместе с новым типом — либо с полными копиями
/// моделей на каждую версию, чего этот проект сознательно не делает.

/// Текущая схема — всегда последняя версия.
typealias AppSchemaCurrent = AppSchemaV2

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AppSchemaV1.self, AppSchemaV2.self]
    }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: AppSchemaV1.self, toVersion: AppSchemaV2.self)]
    }
}

/// Аварийное восстановление стора: если контейнер не создаётся даже с планом
/// миграции (повреждённый файл, откат на старую версию приложения), уводим файлы
/// в сторону и стартуем с чистого. Пользователь теряет данные — но приложение
/// запускается и его можно починить/переустановить, а не «оно просто не открывается».
enum StoreRecovery {
    /// Имена файлов стора SwiftData по умолчанию (сам стор + журналы SQLite).
    static let storeFiles = ["default.store", "default.store-shm", "default.store-wal"]

    /// Папка стора по умолчанию.
    static var defaultDirectory: URL { URL.applicationSupportDirectory }

    /// Переименовывает файлы стора в `corrupt-*` (не удаляем: файл может
    /// пригодиться для разбора по логам поддержки). Возвращает, что реально сдвинули.
    @discardableResult
    static func moveAside(in directory: URL = defaultDirectory,
                          fileManager: FileManager = .default) -> [String] {
        var moved: [String] = []
        for name in storeFiles {
            let url = directory.appending(path: name)
            guard fileManager.fileExists(atPath: url.path) else { continue }
            let backup = directory.appending(path: "corrupt-\(name)")
            try? fileManager.removeItem(at: backup)
            do {
                try fileManager.moveItem(at: url, to: backup)
                moved.append(name)
            } catch {
                // Не смогли отодвинуть — пробуем удалить, иначе старт снова упрётся в тот же файл.
                if (try? fileManager.removeItem(at: url)) != nil { moved.append(name) }
            }
        }
        return moved
    }
}
