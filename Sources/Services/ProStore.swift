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
}

/// Состояние покупки для интерфейса. Вьюха знает только `isPurchased`,
/// `product` и `lastError`; про `Transaction` и верификацию она не в курсе.
@MainActor
final class ProStore: ObservableObject {

    @Published private(set) var product: ProProduct?
    @Published private(set) var isPurchased = false
    @Published private(set) var isLoading = false
    /// Текст последней ошибки для показа пользователю. Отмена покупки сюда
    /// НЕ попадает: человек сам закрыл лист, ругаться не за что.
    @Published private(set) var lastError: String?

    /// Общий экземпляр для вьюх — как `NotificationManager.shared` и `AppRouter.shared`.
    /// В тестах используется обычный `init` с моком.
    static let shared = ProStore(purchasing: StoreKitPurchasing())

    private let purchasing: ProPurchasing
    private let productId: String

    init(purchasing: ProPurchasing, productId: String = ProProductID.pro) {
        self.purchasing = purchasing
        self.productId = productId
    }

    /// Витрина + текущее право. Зовётся при показе экрана покупки и на старте.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await purchasing.product(id: productId)
        } catch {
            lastError = error.localizedDescription
        }
        isPurchased = await purchasing.isEntitled(to: productId)
    }

    @discardableResult
    func buy() async -> ProPurchaseOutcome? {
        isLoading = true
        defer { isLoading = false }
        lastError = nil
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
}
