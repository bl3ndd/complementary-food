import XCTest
@testable import Prikorm

/// Состояние покупки проверяем через мок шва `ProPurchasing`: настоящий
/// `Product.purchase()` требует живой сессии App Store, и в юнит-тестах ему
/// делать нечего. Здесь важно другое — что отмена не выглядит как ошибка,
/// «ожидает подтверждения» не выдаёт право, а сбой сети не роняет экран.
final class ProStoreTests: XCTestCase {

    private struct Fake: ProPurchasing {
        var productToReturn: ProProduct? = ProProduct(
            id: ProProductID.pro, displayName: "Pudding Pro", displayPrice: "$4.99")
        var outcome: ProPurchaseOutcome = .purchased
        var entitled = false
        var entitledAfterRestore: Bool?
        var productError: Error?
        var purchaseError: Error?
        var restoreError: Error?
        /// Мутируется из мока — поэтому класс-коробка, а не поле структуры.
        final class Calls { var restores = 0 }
        let calls = Calls()

        func product(id: String) async throws -> ProProduct? {
            if let productError { throw productError }
            return productToReturn
        }

        func purchase(id: String) async throws -> ProPurchaseOutcome {
            if let purchaseError { throw purchaseError }
            return outcome
        }

        func isEntitled(to id: String) async -> Bool {
            if calls.restores > 0, let after = entitledAfterRestore { return after }
            return entitled
        }

        func restore() async throws {
            calls.restores += 1
            if let restoreError { throw restoreError }
        }
    }

    private struct Boom: LocalizedError {
        var errorDescription: String? { "сеть отвалилась" }
    }

    // MARK: - Витрина

    @MainActor
    func testRefreshLoadsProductAndEntitlement() async {
        let store = ProStore(purchasing: Fake(entitled: true))
        await store.refresh()

        XCTAssertEqual(store.product?.displayPrice, "$4.99")
        XCTAssertTrue(store.isPurchased)
        XCTAssertNil(store.lastError)
        XCTAssertFalse(store.isLoading, "флаг загрузки обязан сняться")
    }

    @MainActor
    func testProductErrorIsShownButEntitlementStillChecked() async {
        let store = ProStore(purchasing: Fake(entitled: true, productError: Boom()))
        await store.refresh()

        XCTAssertEqual(store.lastError, "сеть отвалилась")
        XCTAssertTrue(store.isPurchased, "право не зависит от того, загрузилась ли витрина")
    }

    // MARK: - Покупка

    @MainActor
    func testSuccessfulPurchaseGrantsPro() async {
        let store = ProStore(purchasing: Fake(outcome: .purchased))
        let outcome = await store.buy()

        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(store.isPurchased)
        XCTAssertNil(store.lastError)
    }

    /// Человек сам закрыл системный лист — это не ошибка и ругаться нельзя.
    @MainActor
    func testCancelledPurchaseIsSilentAndGrantsNothing() async {
        let store = ProStore(purchasing: Fake(outcome: .cancelled))
        let outcome = await store.buy()

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(store.isPurchased)
        XCTAssertNil(store.lastError, "отмена не должна показываться как ошибка")
    }

    /// «Ask to Buy»: покупка ждёт подтверждения родителя — права ещё нет.
    @MainActor
    func testPendingPurchaseDoesNotGrantPro() async {
        let store = ProStore(purchasing: Fake(outcome: .pending))
        let outcome = await store.buy()

        XCTAssertEqual(outcome, .pending)
        XCTAssertFalse(store.isPurchased)
    }

    @MainActor
    func testPurchaseErrorIsReportedAndDoesNotGrantPro() async {
        let store = ProStore(purchasing: Fake(purchaseError: Boom()))
        let outcome = await store.buy()

        XCTAssertNil(outcome)
        XCTAssertFalse(store.isPurchased)
        XCTAssertEqual(store.lastError, "сеть отвалилась")
        XCTAssertFalse(store.isLoading)
    }

    // MARK: - Восстановление

    @MainActor
    func testRestoreBringsBackPro() async {
        let store = ProStore(purchasing: Fake(entitled: false, entitledAfterRestore: true))
        XCTAssertFalse(store.isPurchased)

        await store.restore()
        XCTAssertTrue(store.isPurchased)
        XCTAssertNil(store.lastError)
    }

    @MainActor
    func testRestoreErrorIsReported() async {
        let store = ProStore(purchasing: Fake(restoreError: Boom()))
        await store.restore()

        XCTAssertEqual(store.lastError, "сеть отвалилась")
        XCTAssertFalse(store.isPurchased)
    }

    /// Повторная покупка после ошибки не должна показывать старый текст.
    @MainActor
    func testErrorIsClearedOnNextAttempt() async {
        var fake = Fake(purchaseError: Boom())
        let store = ProStore(purchasing: fake)
        await store.buy()
        XCTAssertNotNil(store.lastError)

        fake.purchaseError = nil
        let fresh = ProStore(purchasing: fake)
        await fresh.buy()
        XCTAssertNil(fresh.lastError)
    }
}
