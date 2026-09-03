import Foundation

/// Снимок коллекции для виджета.
///
/// **Почему снимок, а не общий стор.** Виджету нужны всего несколько id продуктов,
/// а чтобы дать ему SwiftData-контейнер, стор пришлось бы перенести в App Group —
/// то есть провести миграцию у всех существующих пользователей и потрогать
/// CloudKit ради сетки иконок. Цена несопоставима с задачей.
///
/// Приложение пишет сюда маленький JSON при изменении журнала, виджет его читает.
/// Если App Group недоступна (не выдана в профиле), всё молча не работает —
/// виджет пустой, приложение цело.
struct WidgetSnapshot: Codable, Equatable {

    /// Общий контейнер приложения и расширения.
    static let appGroup = "group.com.pudding.app"
    static let fileName = "collection.json"

    /// Сколько продуктов держим. Больше в medium-виджет не влезает, а таскать
    /// весь каталог в снимке незачем.
    static let limit = 16

    /// Продукт в снимке. Эмодзи лежит прямо здесь, чтобы расширению не тащить
    /// каталог, ассеты и `FoodIcon`: виджет становится самодостаточным.
    struct Item: Codable, Equatable {
        let id: String
        let emoji: String
    }

    /// Продукты в порядке знакомства; в снимке — последние `limit`.
    let items: [Item]
    /// Сколько всего введено (может быть больше, чем влезло в `foodIds`).
    let total: Int
    let updatedAt: Date

    /// Собирает снимок из полного списка введённых продуктов.
    static func make(items all: [Item], now: Date = Date()) -> WidgetSnapshot {
        WidgetSnapshot(items: Array(all.suffix(limit)), total: all.count, updatedAt: now)
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
