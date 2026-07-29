import Foundation

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
}
