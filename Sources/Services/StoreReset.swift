import Foundation
import SwiftData

/// «Сбросить все данные»: стирает дневник целиком.
///
/// Удаляем ПОШТУЧНО, а не `context.delete(model:)`. Пакетное удаление мимо контекста
/// давало две беды: `@Query` в `RootView` не замечал пропажу ребёнка (пустой экран
/// с таббаром вместо онбординга), а смесь пакетного и поштучного удаления роняла
/// `save()` — изменения откатывались, и ребёнок возвращался после онбординга.
enum StoreReset {
    static func wipe(_ context: ModelContext) throws {
        // Фото — первыми: каскад от FoodLog их бы тоже снёс, но орфаны без записи
        // (бывали после старых пакетных удалений) он не найдёт.
        try deleteAll(LogPhoto.self, in: context)
        try deleteAll(FoodLog.self, in: context)
        try deleteAll(IntroductionStatus.self, in: context)
        try deleteAll(CustomFood.self, in: context)
        try deleteAll(Child.self, in: context)
        try context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for model in try context.fetch(FetchDescriptor<T>()) { context.delete(model) }
    }
}
