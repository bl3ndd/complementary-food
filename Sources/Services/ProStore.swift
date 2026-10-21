import Foundation
import StoreKit

/// Что именно продаём. Один непотребляемый продукт, без подписок и уровней:
/// окно жизни продукта — 4–12 месяцев ребёнка, подписка на такой срок даёт
/// отписки и возвраты вместо выручки.
enum ProProductID {
    static let pro = "com.pudding.app.pro"
}

/// Витрина продукта в терминах приложения, без типов StoreKit — чтобы вьюхи и
/// тесты не зависели от системного фреймворка.
struct ProProduct: Equatable {
    let id: String
    let displayName: String
    /// Цена строкой в валюте пользователя. Никогда не хардкодим: она задаётся в
    /// App Store Connect и различается по территориям.
    let displayPrice: String
}

/// Чем закончилась попытка покупки.
enum ProPurchaseOutcome: Equatable {
    case purchased
    /// Пользователь закрыл системный лист. Это не ошибка — молчим.
    case cancelled
    /// Ждёт подтверждения (родительский контроль, «Ask to Buy»). Права ещё нет.
    case pending
}

/// Шов над StoreKit — ровно та же идея, что у `NotificationScheduling` над
/// `UNUserNotificationCenter`: логику состояния можно проверить тестами, не
/// поднимая живую сессию App Store.
protocol ProPurchasing {
    func product(id: String) async throws -> ProProduct?
    func purchase(id: String) async throws -> ProPurchaseOutcome
    func isEntitled(to id: String) async -> Bool
    func restore() async throws
    /// Транзакции, пришедшие мимо кнопки «Купить»: одобрение «Ask to Buy», покупка
    /// на другом устройстве, возврат. Каждое событие — повод перепроверить право.
    func transactionUpdates() -> AsyncStream<Void>
    /// Сборка, впервые скачанная на этот Apple ID (`AppTransaction`), только из
    /// боевого App Store. `nil` — нет ответа или это песочница/Xcode.
    func originalAppBuild() async -> String?
}

extension ProPurchasing {
    func transactionUpdates() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func originalAppBuild() async -> String? { nil }
}

/// Состояние покупки для интерфейса. Вьюха знает только `isPurchased`,
/// `product` и `lastError`; про `Transaction` и верификацию она не в курсе.
@MainActor
final class ProStore: ObservableObject {

    @Published private(set) var product: ProProduct?
    /// Стартует с последнего известного значения, а не с `false`: иначе у купившего
    /// платная гамма на запуске откатывалась на базовую, а через полсекунды ответ
    /// StoreKit возвращал её — и `RootView` (`.id` по гамме) пересобирал всё дерево,
    /// сбрасывая навигацию. Кэш — только стартовое значение: `refresh` его сверяет.
    @Published private(set) var isPurchased: Bool {
        didSet { defaults.set(isPurchased, forKey: Self.cacheKey) }
    }
    @Published private(set) var isLoading = false
    /// Текст последней ошибки для показа пользователю. Отмена покупки сюда
    /// НЕ попадает: человек сам закрыл лист, ругаться не за что.
    @Published private(set) var lastError: String?
    /// Первая скачанная сборка по данным App Store — см. `Entitlements.originalAppBuild`.
    /// Кэшируется: ответ не меняется, а офлайн-запуск не должен его терять.
    @Published private(set) var originalAppBuild: String? {
        didSet { defaults.set(originalAppBuild, forKey: Self.originalBuildKey) }
    }

    /// Общий экземпляр для вьюх — как `NotificationManager.shared` и `AppRouter.shared`.
    /// В тестах используется обычный `init` с моком.
    static let shared = ProStore(purchasing: StoreKitPurchasing())

    static let cacheKey = "pro.purchased"
    static let originalBuildKey = "pro.originalAppBuild"

    private let purchasing: ProPurchasing
    private let productId: String
    private let defaults: UserDefaults

    init(purchasing: ProPurchasing, productId: String = ProProductID.pro,
         defaults: UserDefaults = .standard) {
        self.purchasing = purchasing
        self.productId = productId
        self.defaults = defaults
        self.isPurchased = defaults.bool(forKey: Self.cacheKey)
        self.originalAppBuild = defaults.string(forKey: Self.originalBuildKey)
        // Без слушателя одобренная родителем покупка или возврат становились видны
        // только при следующем запуске или открытии экрана Pro.
        updatesTask = Task { [weak self, purchasing, productId] in
            for await _ in purchasing.transactionUpdates() {
                let entitled = await purchasing.isEntitled(to: productId)
                self?.isPurchased = entitled
            }
        }
    }

    private var updatesTask: Task<Void, Never>?

    /// Витрина + текущее право. Зовётся при показе экрана покупки и на старте.
    ///
    /// Фоновая: кнопку покупки не держит. Запрос к App Store в песочнице может
    /// висеть минутами, и кнопка всё это время была серой без объяснений.
    func refresh() async {
        do {
            product = try await purchasing.product(id: productId)
        } catch {
            lastError = error.localizedDescription
        }
        isPurchased = await purchasing.isEntitled(to: productId)
        if let build = await purchasing.originalAppBuild() { originalAppBuild = build }
    }

    @discardableResult
    func buy() async -> ProPurchaseOutcome? {
        // Витрина могла не загрузиться при показе экрана (сеть, App Store). Кнопка
        // при этом не должна молчать: пробуем ещё раз и честно говорим, если нет.
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        if product == nil { await refresh() }
        guard product != nil else {
            if lastError == nil { lastError = String(localized: "Не удалось загрузить покупку из App Store. Проверь интернет и попробуй ещё раз.") }
            return nil
        }
        do {
            let outcome = try await purchasing.purchase(id: productId)
            if outcome == .purchased { isPurchased = true }
            return outcome
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    /// Обязательная кнопка «Восстановить покупки» (требование App Review).
    func restore() async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            try await purchasing.restore()
        } catch {
            lastError = error.localizedDescription
        }
        isPurchased = await purchasing.isEntitled(to: productId)
    }
}

/// Настоящая реализация поверх StoreKit 2.
///
/// Не покрыта юнит-тестами намеренно: `Product.purchase()` требует живой сессии
/// App Store. Логика состояния живёт в `ProStore` и тестируется через мок, а этот
/// слой проверяется запуском с `Prikorm.storekit`.
struct StoreKitPurchasing: ProPurchasing {

    func product(id: String) async throws -> ProProduct? {
        guard let p = try await Product.products(for: [id]).first else { return nil }
        return ProProduct(id: p.id, displayName: p.displayName, displayPrice: p.displayPrice)
    }

    func purchase(id: String) async throws -> ProPurchaseOutcome {
        guard let p = try await Product.products(for: [id]).first else { return .cancelled }
        switch try await p.purchase() {
        case let .success(verification):
            // Непроверенную подпись не принимаем: право выдаётся только по
            // транзакции, подтверждённой App Store.
            guard case let .verified(transaction) = verification else { return .pending }
            await transaction.finish()
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    func isEntitled(to id: String) async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            if transaction.productID == id && transaction.revocationDate == nil { return true }
        }
        return false
    }

    func restore() async throws {
        try await AppStore.sync()
    }

    func originalAppBuild() async -> String? {
        // `.shared` не показывает вход в Apple ID (в отличие от `refresh()`).
        // Песочница и Xcode отдают «1.0» всем подряд — ревьюер Apple увидел бы
        // открытый Pro и не смог бы проверить покупку. Верим только боевому стору.
        guard case let .verified(app) = try? await AppTransaction.shared,
              app.environment == .production else { return nil }
        return app.originalAppVersion
    }

    func transactionUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case let .verified(transaction) = result { await transaction.finish() }
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
