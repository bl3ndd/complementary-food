import Foundation

/// Снимок дневника для виджетов.
///
/// **Почему снимок, а не общий стор.** Виджету нужны всего несколько продуктов,
/// а чтобы дать ему SwiftData-контейнер, стор пришлось бы перенести в App Group —
/// то есть провести миграцию у всех существующих пользователей и потрогать
/// CloudKit ради пары строк на домашнем экране. Цена несопоставима с задачей.
///
/// Приложение пишет сюда маленький JSON при изменении журнала, виджет его читает.
/// Если App Group недоступна (не выдана в профиле), всё молча не работает —
/// виджет пустой, приложение цело.
///
/// Новые поля — опциональные: снимок, записанный прошлой версией приложения,
/// обязан читаться, пока приложение его не перезапишет.
struct WidgetSnapshot: Codable, Equatable {

    /// Общий контейнер приложения и расширения.
    static let appGroup = "group.com.pudding.app"
    static let fileName = "collection.json"

    /// Сколько продуктов держим. Больше в medium-виджет не влезает, а таскать
    /// весь каталог в снимке незачем.
    static let limit = 16
    /// Сколько вводимых и запланированных продуктов кладём — больше виджет не покажет.
    static let introLimit = 2
    static let plannedLimit = 3

    /// Продукт в снимке. Имя и иконка лежат прямо здесь, чтобы расширению не тащить
    /// каталог, ассеты и `FoodIcon`: виджет самодостаточен. Иконка — PNG, который
    /// отрисовало приложение; эмодзи — запасной вариант, если отрисовать не вышло.
    struct Item: Codable, Equatable {
        let id: String
        let emoji: String
        var name: String?
        var icon: Data?
    }

    /// Продукт, который сейчас вводят: сколько кормлений из нужных уже было.
    struct Intro: Codable, Equatable {
        let item: Item
        let done: Int
        let window: Int
    }

    /// Запланированный пользователем продукт (свой план, а не совет приложения).
    struct Planned: Codable, Equatable {
        let item: Item
        let date: Date
    }

    /// Продукты в порядке знакомства; в снимке — последние `limit`.
    let items: [Item]
    /// Сколько всего введено (может быть больше, чем влезло в `items`).
    let total: Int
    let updatedAt: Date
    var introducing: [Intro]?
    var planned: [Planned]?
    /// Заперта ли «Коллекция» (она — часть Pro). «Сейчас вводишь» бесплатный и
    /// на этот флаг не смотрит.
    var locked: Bool?

    /// Собирает снимок из полного списка введённых продуктов.
    static func make(items all: [Item],
                     introducing: [Intro] = [],
                     planned: [Planned] = [],
                     locked: Bool = false,
                     now: Date = Date()) -> WidgetSnapshot {
        WidgetSnapshot(items: Array(all.suffix(limit)), total: all.count, updatedAt: now,
                       introducing: Array(introducing.prefix(introLimit)),
                       planned: Array(planned.prefix(plannedLimit)),
                       locked: locked)
    }
}

/// Чтение и запись снимка. Директория инъектируется — иначе это не проверить
/// тестами, а App Group в юнит-тестах недоступна.
enum WidgetSnapshotStore {

    /// Каталог общего контейнера. `nil` — App Group не выдана.
    static var sharedDirectory: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup)
    }

    static func write(_ snapshot: WidgetSnapshot, to directory: URL) throws {
        let data = try JSONEncoder().encode(snapshot)
        // Атомарно: виджет может читать файл ровно в этот момент, и половина
        // JSON для него хуже, чем прошлый снимок.
        try data.write(to: directory.appendingPathComponent(WidgetSnapshot.fileName),
                       options: .atomic)
    }

    static func read(from directory: URL) -> WidgetSnapshot? {
        let url = directory.appendingPathComponent(WidgetSnapshot.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Записать в общий контейнер, если он есть. Без App Group — тихо ничего.
    @discardableResult
    static func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard let dir = sharedDirectory else { return false }
        do { try write(snapshot, to: dir); return true } catch { return false }
    }

    static func load() -> WidgetSnapshot? {
        guard let dir = sharedDirectory else { return nil }
        return read(from: dir)
    }
}
