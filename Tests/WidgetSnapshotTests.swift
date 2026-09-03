import XCTest
@testable import Prikorm

/// Снимок — единственный мост между приложением и виджетом. Ошибка здесь не
/// падает, а тихо показывает человеку устаревшую или пустую сетку, и понять это
/// со стороны невозможно.
final class WidgetSnapshotTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Сборка

    func testKeepsTheMostRecentFoodsWithinLimit() {
        let ids = (1...30).map { "food\($0)" }
        let snap = WidgetSnapshot.make(items: ids.map { .init(id: $0, emoji: "🥦") })

        XCTAssertEqual(snap.items.count, WidgetSnapshot.limit)
        XCTAssertEqual(snap.items.last?.id, "food30", "в сетке — последние введённые")
        XCTAssertEqual(snap.total, 30, "счётчик считает всё, а не только влезшее")
    }

    func testShortListIsKeptWhole() {
        let snap = WidgetSnapshot.make(items: [.init(id: "apple", emoji: "🍎"), .init(id: "pear", emoji: "🍐")])
        XCTAssertEqual(snap.items.map(\.id), ["apple", "pear"])
        XCTAssertEqual(snap.total, 2)
    }

    func testEmptyDiaryGivesEmptySnapshot() {
        let snap = WidgetSnapshot.make(items: [])
        XCTAssertTrue(snap.items.isEmpty)
        XCTAssertEqual(snap.total, 0)
    }

    // MARK: - Запись и чтение

    func testRoundTrip() throws {
        let snap = WidgetSnapshot.make(items: ["apple", "pear", "plum"].map { .init(id: $0, emoji: "🍎") },
                                       now: Date(timeIntervalSince1970: 1_700_000_000))
        try WidgetSnapshotStore.write(snap, to: dir)

        let back = WidgetSnapshotStore.read(from: dir)
        XCTAssertEqual(back, snap)
    }

    func testReadingMissingFileIsNilNotCrash() {
        XCTAssertNil(WidgetSnapshotStore.read(from: dir))
    }

    func testReadingGarbageIsNilNotCrash() throws {
        let url = dir.appendingPathComponent(WidgetSnapshot.fileName)
        try Data("это не json".utf8).write(to: url)
        XCTAssertNil(WidgetSnapshotStore.read(from: dir),
                     "битый снимок не должен ронять виджет")
    }

    func testRewriteReplacesPreviousSnapshot() throws {
        try WidgetSnapshotStore.write(.make(items: [.init(id: "apple", emoji: "🍎")]), to: dir)
        try WidgetSnapshotStore.write(.make(items: [.init(id: "pear", emoji: "🍐"), .init(id: "plum", emoji: "🫐")]), to: dir)

        XCTAssertEqual(WidgetSnapshotStore.read(from: dir)?.items.map(\.id), ["pear", "plum"])
    }

    /// Без App Group запись обязана быть безобидной: виджет просто не появится,
    /// а приложение продолжит работать.
    func testSavingWithoutAppGroupIsHarmless() {
        if WidgetSnapshotStore.sharedDirectory == nil {
            XCTAssertFalse(WidgetSnapshotStore.save(.make(items: [.init(id: "apple", emoji: "🍎")])))
            XCTAssertNil(WidgetSnapshotStore.load())
        }
    }
}
