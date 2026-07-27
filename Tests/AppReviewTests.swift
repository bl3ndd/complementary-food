import XCTest
@testable import Prikorm

/// Когда просим оценку в App Store: только после нескольких успешных вводов и
/// не повторно на той же версии.
final class AppReviewTests: XCTestCase {

    func testDoesNotAskBeforeMilestone() {
        XCTAssertFalse(AppReview.shouldAsk(introducedCount: 0,
                                           lastAskedVersion: nil, currentVersion: "1.0.0"))
        XCTAssertFalse(AppReview.shouldAsk(introducedCount: AppReview.milestone - 1,
                                           lastAskedVersion: nil, currentVersion: "1.0.0"))
    }

    func testAsksAtMilestoneWhenNeverAsked() {
        XCTAssertTrue(AppReview.shouldAsk(introducedCount: AppReview.milestone,
                                          lastAskedVersion: nil, currentVersion: "1.0.0"))
    }

    func testDoesNotAskTwiceOnSameVersion() {
        XCTAssertFalse(AppReview.shouldAsk(introducedCount: 10,
                                           lastAskedVersion: "1.0.0", currentVersion: "1.0.0"))
    }

    func testAsksAgainOnNewVersion() {
        XCTAssertTrue(AppReview.shouldAsk(introducedCount: 10,
                                          lastAskedVersion: "1.0.0", currentVersion: "1.1.0"))
    }

    func testRememberRoundTripsThroughDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "review.tests"))
        defaults.removePersistentDomain(forName: "review.tests")
        defer { defaults.removePersistentDomain(forName: "review.tests") }

        XCTAssertNil(AppReview.lastAskedVersion(defaults: defaults))
        AppReview.remember(version: "2.0.0", defaults: defaults)
        XCTAssertEqual(AppReview.lastAskedVersion(defaults: defaults), "2.0.0")
    }
}

/// Аварийное восстановление стора: файлы уходят в `corrupt-*`, чтобы приложение
/// стартовало с чистого, а не падало в `fatalError`.
final class StoreRecoveryTests: XCTestCase {

    func testMoveAsideRenamesExistingStoreFiles() throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "store-recovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = dir.appending(path: "default.store")
        try Data("данные".utf8).write(to: store)

        let moved = StoreRecovery.moveAside(in: dir)

        XCTAssertEqual(moved, ["default.store"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.path),
                       "исходный файл должен уйти в сторону")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: dir.appending(path: "corrupt-default.store").path),
                      "содержимое сохраняем для разбора, а не удаляем")
    }

    func testMoveAsideIsNoOpWhenNothingToMove() {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "store-recovery-empty-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertTrue(StoreRecovery.moveAside(in: dir).isEmpty)
    }
}
