import Foundation
import SwiftData

/// Отметка о том, когда человек пришёл в приложение.
///
/// Нужна ради обещания «ранним пользователям — пожизненный доступ»: когда
/// появятся платные возможности, отличить раннего пользователя можно будет
/// **только** по такой записи. Ставить её задним числом уже не выйдет, поэтому
/// пишем с первого запуска, пока приложение полностью бесплатное.
///
/// Живёт в SwiftData → уезжает в приватный iCloud вместе с остальными данными,
/// поэтому переустановка приложения статус не сбрасывает.
/// Свойства с дефолтами — требование CloudKit (SPEC §8).
@Model
final class AppInstall {
    var id: UUID = UUID()
    /// Когда приложение впервые открыли на этом аккаунте.
    var firstLaunchedAt: Date = Date()
    /// Версия, с которой пришли (`CFBundleShortVersionString`) — чтобы потом
    /// не гадать, застал ли человек бесплатную эпоху.
    var firstVersion: String = ""

    init(firstLaunchedAt: Date = Date(), firstVersion: String = "") {
        self.firstLaunchedAt = firstLaunchedAt
        self.firstVersion = firstVersion
    }
}
