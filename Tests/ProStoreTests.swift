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

    /// Своё хранилище на каждый тест: кэш покупки иначе протекал бы между тестами
    /// через `UserDefaults.standard` тест-хоста.
    private func isolatedDefaults() -> UserDefaults {
        let name = "ProStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    // MARK: - Кэш права

    /// Купивший должен стартовать уже с Pro: иначе платная гамма на запуске
    /// откатывается и через полсекунды возвращается, пересобирая всё дерево.
    @MainActor
    func testStartsFromCachedPurchase() {
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: ProStore.cacheKey)
        XCTAssertTrue(ProStore(purchasing: Fake(), defaults: defaults).isPurchased)
        XCTAssertFalse(ProStore(purchasing: Fake(), defaults: isolatedDefaults()).isPurchased,
                       "без кэша — не куплено")
    }

    @MainActor
    func testRefreshCorrectsCacheBothWays() async {
        let defaults = isolatedDefaults()
        await ProStore(purchasing: Fake(entitled: true), defaults: defaults).refresh()
        XCTAssertTrue(ProStore(purchasing: Fake(), defaults: defaults).isPurchased,
                      "подтверждённая покупка должна пережить перезапуск")

        // Возврат денег / другой Apple ID: кэш не должен держать Pro вечно.
        await ProStore(purchasing: Fake(entitled: false), defaults: defaults).refresh()
        XCTAssertFalse(ProStore(purchasing: Fake(), defaults: defaults).isPurchased)
    }

    // MARK: - Витрина

    @MainActor
    func testRefreshLoadsProductAndEntitlement() async {
        let store = ProStore(purchasing: Fake(entitled: true), defaults: isolatedDefaults())
        await store.refresh()

        XCTAssertEqual(store.product?.displayPrice, "$4.99")
        XCTAssertTrue(store.isPurchased)
        XCTAssertNil(store.lastError)
        XCTAssertFalse(store.isLoading, "флаг загрузки обязан сняться")
    }

    @MainActor
    func testProductErrorIsShownButEntitlementStillChecked() async {
        let store = ProStore(purchasing: Fake(entitled: true, productError: Boom()), defaults: isolatedDefaults())
        await store.refresh()

        XCTAssertEqual(store.lastError, "сеть отвалилась")
        XCTAssertTrue(store.isPurchased, "право не зависит от того, загрузилась ли витрина")
    }

    // MARK: - Покупка

    @MainActor
    func testSuccessfulPurchaseGrantsPro() async {
        let store = ProStore(purchasing: Fake(outcome: .purchased), defaults: isolatedDefaults())
        let outcome = await store.buy()

        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(store.isPurchased)
        XCTAssertNil(store.lastError)
    }

    /// Человек сам закрыл системный лист — это не ошибка и ругаться нельзя.
    @MainActor
    func testCancelledPurchaseIsSilentAndGrantsNothing() async {
        let store = ProStore(purchasing: Fake(outcome: .cancelled), defaults: isolatedDefaults())
        let outcome = await store.buy()

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(store.isPurchased)
        XCTAssertNil(store.lastError, "отмена не должна показываться как ошибка")
    }

    /// «Ask to Buy»: покупка ждёт подтверждения родителя — права ещё нет.
    @MainActor
    func testPendingPurchaseDoesNotGrantPro() async {
        let store = ProStore(purchasing: Fake(outcome: .pending), defaults: isolatedDefaults())
        let outcome = await store.buy()

        XCTAssertEqual(outcome, .pending)
        XCTAssertFalse(store.isPurchased)
    }

    @MainActor
    func testPurchaseErrorIsReportedAndDoesNotGrantPro() async {
        let store = ProStore(purchasing: Fake(purchaseError: Boom()), defaults: isolatedDefaults())
        let outcome = await store.buy()

        XCTAssertNil(outcome)
        XCTAssertFalse(store.isPurchased)
        XCTAssertEqual(store.lastError, "сеть отвалилась")
        XCTAssertFalse(store.isLoading)
    }

    // MARK: - Восстановление

    @MainActor
    func testRestoreBringsBackPro() async {
        let store = ProStore(purchasing: Fake(entitled: false, entitledAfterRestore: true), defaults: isolatedDefaults())
        XCTAssertFalse(store.isPurchased)

        await store.restore()
        XCTAssertTrue(store.isPurchased)
        XCTAssertNil(store.lastError)
    }

    @MainActor
    func testRestoreErrorIsReported() async {
        let store = ProStore(purchasing: Fake(restoreError: Boom()), defaults: isolatedDefaults())
        await store.restore()

        XCTAssertEqual(store.lastError, "сеть отвалилась")
        XCTAssertFalse(store.isPurchased)
    }

    /// Повторная покупка после ошибки не должна показывать старый текст.
    @MainActor
    func testErrorIsClearedOnNextAttempt() async {
        var fake = Fake(purchaseError: Boom())
        let store = ProStore(purchasing: fake, defaults: isolatedDefaults())
        await store.buy()
        XCTAssertNotNil(store.lastError)

        fake.purchaseError = nil
        let fresh = ProStore(purchasing: fake, defaults: isolatedDefaults())
        await fresh.buy()
        XCTAssertNil(fresh.lastError)
    }

    // MARK: - Витрина не загрузилась

    /// Раньше кнопка была просто выключена, и «Открыть Pro» выглядело сломанным.
    @MainActor
    func testBuyWithoutProductRetriesAndExplains() async {
        let store = ProStore(purchasing: Fake(productToReturn: nil), defaults: isolatedDefaults())
        let outcome = await store.buy()
        XCTAssertNil(outcome)
        XCTAssertFalse(store.isPurchased)
        XCTAssertNotNil(store.lastError, "пустая витрина — видимая ошибка, а не тишина")
    }

    @MainActor
    func testBuyLoadsProductLazily() async {
        let store = ProStore(purchasing: Fake(), defaults: isolatedDefaults())
        XCTAssertNil(store.product)
        let outcome = await store.buy()
        XCTAssertEqual(outcome, .purchased, "витрина догружается прямо на тапе")
        XCTAssertTrue(store.isPurchased)
    }

    private struct SlowStore: ProPurchasing {
        func product(id: String) async throws -> ProProduct? {
            try await Task.sleep(for: .milliseconds(300)); return nil
        }
        func purchase(id: String) async throws -> ProPurchaseOutcome { .purchased }
        func isEntitled(to id: String) async -> Bool { false }
        func restore() async throws {}
    }

    /// Медленная витрина в фоне не выключает кнопку покупки.
    @MainActor
    func testBackgroundRefreshDoesNotLockBuyButton() async {
        let store = ProStore(purchasing: SlowStore(), defaults: isolatedDefaults())
        let loading = Task { await store.refresh() }
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(store.isLoading, "пока App Store думает, кнопка живая")
        await loading.value
    }
}
