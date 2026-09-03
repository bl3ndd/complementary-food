import XCTest
@testable import Prikorm

/// Выбор активного ребёнка обязан быть снисходительным: любой сбой приводит к
/// первому ребёнку, а не к пустому экрану. Ребёнка могли удалить на другом
/// устройстве, id мог не доехать через синк — человек всё равно должен увидеть
/// свой дневник, а не онбординг поверх существующих записей.
final class ActiveChildTests: XCTestCase {

    private func child(_ name: String) -> Child {
        Child(name: name, birthDate: Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testStoredIdSelectsThatChild() {
        let first = child("Эмма"), second = child("Лев")
        let picked = ActiveChild.resolve(children: [first, second],
                                         storedId: second.id.uuidString)
        XCTAssertEqual(picked?.id, second.id)
    }

    func testUnknownIdFallsBackToFirst() {
        let first = child("Эмма"), second = child("Лев")
        let picked = ActiveChild.resolve(children: [first, second],
                                         storedId: UUID().uuidString)
        XCTAssertEqual(picked?.id, first.id, "удалённый на другом устройстве — не повод для пустого экрана")
    }

    func testGarbageIdFallsBackToFirst() {
        let first = child("Эмма")
        XCTAssertEqual(ActiveChild.resolve(children: [first], storedId: "не-uuid")?.id, first.id)
        XCTAssertEqual(ActiveChild.resolve(children: [first], storedId: "")?.id, first.id)
        XCTAssertEqual(ActiveChild.resolve(children: [first], storedId: nil)?.id, first.id)
    }

    func testNoChildrenGivesNil() {
        XCTAssertNil(ActiveChild.resolve(children: [], storedId: nil))
        XCTAssertNil(ActiveChild.resolve(children: [], storedId: UUID().uuidString))
    }

    func testIdRoundTrip() {
        let c = child("Эмма")
        XCTAssertEqual(ActiveChild.id(of: c), c.id.uuidString)
        XCTAssertEqual(ActiveChild.id(of: nil), "")
        XCTAssertEqual(ActiveChild.resolve(children: [c], storedId: ActiveChild.id(of: c))?.id, c.id)
    }
}
