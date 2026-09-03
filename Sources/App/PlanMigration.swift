import Foundation
import SwiftData

/// Разовые миграции пользовательского плана прикорма.
///
/// Правило: **чужие настройки не трогаем**. Если значения совпадают со старым
/// дефолтом — значит юзер их не менял, и его можно перевести на новый дефолт.
/// Если он что-то выставил сам, оставляем как есть, даже если дефолт изменился.
enum PlanMigration {
    /// Окна наблюдения: было 3 дня обычный / 5 аллерген, стало 2 / 3.
    enum ObservationWindowsV2 {
        static let key = "migration.observationWindows.v2"
        static let oldRegular = 3, oldAllergen = 5
        static let newRegular = 2, newAllergen = 3

        /// Возвращает `true`, если план ребёнка реально изменился.
        @discardableResult
        static func apply(to child: Child, defaults: UserDefaults = .standard) -> Bool {
            guard !defaults.bool(forKey: key) else { return false }
            defaults.set(true, forKey: key)

            guard child.customObservationDaysRegular == oldRegular,
                  child.customObservationDaysAllergen == oldAllergen else {
                return false   // юзер настроил окна сам — не вмешиваемся
            }
            child.customObservationDaysRegular = newRegular
            child.customObservationDaysAllergen = newAllergen
            return true
        }
    }

    /// Привязка старых записей к ребёнку.
    ///
    /// До появления нескольких детей дневник был глобальным: у `FoodLog` и
    /// `IntroductionStatus` не было владельца. Здесь мы его проставляем — но только
    /// когда ребёнок ровно ОДИН и владелец однозначен.
    ///
    /// **Если детей несколько — не делаем ничего.** Угадывать, чья запись, нельзя, а
    /// ошибка перемешала бы два дневника необратимо. Такое состояние вообще возможно
    /// только у того, кто уже заводил детей после этого релиза, — а у него записи
    /// создаются сразу с владельцем.
    enum ChildOwnership {
        /// Возвращает, сколько записей привязали.
        @discardableResult
        static func apply(context: ModelContext) -> Int {
            let children = (try? context.fetch(FetchDescriptor<Child>())) ?? []
            guard children.count == 1, let owner = children.first else { return 0 }
            let id = owner.id

            var touched = 0
            // Только записи без владельца: уже привязанные не перезаписываем ни при
            // каких условиях, иначе повторный запуск угонял бы чужие записи.
            let logs = (try? context.fetch(FetchDescriptor<FoodLog>(
                predicate: #Predicate { $0.childId == nil }))) ?? []
            for log in logs { log.childId = id; touched += 1 }

            let statuses = (try? context.fetch(FetchDescriptor<IntroductionStatus>(
                predicate: #Predicate { $0.childId == nil }))) ?? []
            for status in statuses { status.childId = id; touched += 1 }

            if touched > 0 { try? context.save() }
            return touched
        }
    }
}
