import Foundation

/// Какой ребёнок сейчас открыт.
///
/// Хранится в `UserDefaults` (не в сторе): это состояние устройства, а не данные —
/// на планшете и на телефоне может быть открыт разный ребёнок, и синхронизировать
/// такое через iCloud было бы вредно.
///
/// Разрешение намеренно снисходительное: любой сбой выбора приводит к первому
/// ребёнку, а не к пустому экрану. Ребёнка могли удалить на другом устройстве,
/// id мог не доехать через синк — человек всё равно должен увидеть свой дневник.
enum ActiveChild {

    static let storageKey = "app.activeChild"

    /// Активный ребёнок: сохранённый, иначе первый, иначе `nil` (детей нет).
    static func resolve(children: [Child], storedId: String?) -> Child? {
        if let storedId,
           let uuid = UUID(uuidString: storedId),
           let match = children.first(where: { $0.id == uuid }) {
            return match
        }
        return children.first
    }

    /// Значение для `@AppStorage`.
    static func id(of child: Child?) -> String {
        child?.id.uuidString ?? ""
    }
}
