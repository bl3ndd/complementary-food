import XCTest
import UIKit
@testable import Prikorm

/// Тесты PDF-дневника «для педиатра»: чистый контент-билдер (журнал без планов,
/// хронология реакций, секции) детерминирован с инъекцией now/calendar; сам PDF —
/// смоук на валидный заголовок. Ассерты — на счётчики/даты/enum (без локализуемого
/// текста: имена продуктов локализуются в языке симулятора, см. CLAUDE.md).
final class DiaryPDFExportTests: XCTestCase {

    private let catalog = FoodCatalog(foods: [
        Food(id: "broccoli", name: "Брокколи", category: .vegetable,
             emoji: "🥦", isAllergen: false, allergenGroup: nil, minAgeMonths: 4),
        Food(id: "egg_yolk", name: "Желток", category: .egg,
             emoji: "🥚", isAllergen: true, allergenGroup: .egg, minAgeMonths: 6),
    ])

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private let now = Date(timeIntervalSince1970: 1_750_000_000)   // фикс «сейчас»

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")!
        return f.date(from: iso)!
    }

    private func sampleLogs() -> [FoodLog] {
        [
            FoodLog(foodId: "broccoli", date: date("2026-06-10T08:00:00Z"), type: .intro),
            FoodLog(foodId: "egg_yolk", date: date("2026-06-11T09:00:00Z"), type: .maintenance),
            FoodLog(foodId: "egg_yolk", date: date("2026-06-12T09:00:00Z"), type: .intro,
                    reaction: .skin),
            FoodLog(foodId: "broccoli", date: date("2026-07-01T09:00:00Z"), type: .intro,
                    planned: true),   // план — в журнал/реакции не попадает
        ]
    }

    private func eggStatus() -> AllergenGroupStatus {
        AllergenGroupStatus(group: .egg, foods: [], representativeFood: nil,
                            isIntroduced: true, hasAllergy: false,
                            lastGiven: date("2026-06-11T09:00:00Z"),
                            status: .ok, nextDue: nil)
    }

    private func export(_ logs: [FoodLog],
                        allergens: [AllergenGroupStatus] = []) -> DiaryPDFExport {
        DiaryPDFExport(childName: "Ника", ageMonths: 8, catalog: catalog,
                       logs: logs, allergens: allergens, now: now, calendar: utc)
    }

    // MARK: - Журнал: без планов, старые сверху

    func testJournalDaysExcludePlannedOldestFirst() {
        let days = export(sampleLogs()).journalDays()
        XCTAssertEqual(days.count, 3, "три фактических дня (план в июле исключён)")
        XCTAssertEqual(utc.component(.day, from: days[0]), 10, "старые сверху")
        XCTAssertEqual(utc.component(.day, from: days[2]), 12)
    }

    // MARK: - Реакции: только фактические, хронологически

    func testReactionLogsExcludePlannedOldestFirst() {
        let reactions = export(sampleLogs()).reactionLogs()
        XCTAssertEqual(reactions.count, 1, "одна фактическая реакция (план не считается)")
        XCTAssertEqual(reactions[0].reaction, .skin)
    }

    // MARK: - Секции отчёта

    func testReportHasThreeSectionsWhenReactionsAndAllergensPresent() {
        let report = export(sampleLogs(), allergens: [eggStatus()]).report()
        XCTAssertEqual(report.sections.count, 3, "журнал + реакции + аллергены")
        // Журнал: 3 жирных заголовка дня + 3 записи.
        let journal = report.sections[0]
        XCTAssertEqual(journal.rows.count, 6)
        XCTAssertEqual(journal.rows.filter { $0.bold }.count, 3)
        // Секция реакций — одна строка.
        XCTAssertEqual(report.sections[1].rows.count, 1)
        XCTAssertTrue(report.sections[1].heading.contains("1"), "счётчик реакций в заголовке")
        // Аллергены — одна группа.
        XCTAssertEqual(report.sections[2].rows.count, 1)
    }

    func testReportEmptyLogsHasOnlyJournalWithPlaceholder() {
        let report = export([]).report()
        XCTAssertEqual(report.sections.count, 1, "только журнал, без реакций/аллергенов")
        XCTAssertEqual(report.sections[0].rows.count, 1, "плейсхолдер «записей нет»")
        XCTAssertTrue(export([]).journalDays().isEmpty)
    }

    func testReportSubtitleContainsChildNameAndAge() {
        let report = export(sampleLogs()).report()
        XCTAssertTrue(report.subtitle.contains("Ника"))
        XCTAssertTrue(report.subtitle.contains("8"))
    }

    // MARK: - Фото-приложение

    func testPhotoItemsExcludePlannedOldestFirst() {
        let logs = sampleLogs()
        logs[0].photo = Data([1, 2, 3])   // broccoli 06-10
        logs[2].photo = Data([4, 5, 6])   // egg-реакция 06-12
        logs[3].photo = Data([7, 8, 9])   // план — не считается
        let e = export(logs)
        let items = e.photoItems()
        XCTAssertEqual(items.count, 2, "фото плана исключено")
        XCTAssertFalse(items[0].caption.isEmpty)
        XCTAssertEqual(e.report().photos.count, 2)
    }

    // MARK: - PDF-смоук

    func testMakeDataProducesValidPDF() {
        let data = export(sampleLogs(), allergens: [eggStatus()]).makeData()
        XCTAssertFalse(data.isEmpty)
        // PDF начинается с сигнатуры «%PDF».
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
    }

    func testMakeDataWithEmbeddedPhotoStillValid() {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        let logs = sampleLogs()
        logs[0].photo = img.pngData()
        let data = export(logs, allergens: [eggStatus()]).makeData()
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8), "фото не ломает рендер")
    }

    func testWriteTempFileCreatesReadablePDF() throws {
        let url = try XCTUnwrap(export(sampleLogs()).writeTempFile())
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(url.pathExtension, "pdf")
        let data = try Data(contentsOf: url)
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
    }
}
