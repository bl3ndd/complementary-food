import UIKit

/// Сборка PDF-дневника «для педиатра» (главный недостающий JTBD дневника, он же
/// Pro-хук из SPEC). Чистый билдер: данные на вход → PDF на выход, без лимита по
/// датам (урок Glow). Содержимое — только ФАКТЫ (журнал, реакции, статус поддержки
/// аллергенов); никаких выводов/советов (SPEC §4.4).
///
/// Контент (`report()`, `journalDays()`, `reactionLogs()`) — чистая, детерминированная
/// логика с инъекцией `now`/`calendar` (тестируется без UI). Отрисовка в PDF
/// (`makeData()`) — слой UIKit поверх готового контента.
struct DiaryPDFExport {
    let childName: String
    let ageMonths: Int
    let catalog: FoodCatalog
    let logs: [FoodLog]
    /// Статусы поддержки аллергенов — собираются вызывающим (AllergenMaintenance).
    let allergens: [AllergenGroupStatus]
    var now: Date = Date()
    var calendar: Calendar = .current

    // MARK: - Контент (тестируемый)

    /// Дни журнала (начало дня), только фактические записи (без планов), старые сверху.
    func journalDays() -> [Date] {
        let actual = logs.filter { !$0.planned }
        return Array(Set(actual.map { calendar.startOfDay(for: $0.date) })).sorted()
    }

    /// Фактические реакции, старые сверху (хронология для врача).
    func reactionLogs() -> [FoodLog] {
        logs.filter { !$0.planned && ($0.reaction ?? .none) != .none }
            .sorted { $0.date < $1.date }
    }

    struct Row { let text: String; var bold: Bool = false; var indented: Bool = false }
    struct Section { let heading: String; let rows: [Row] }
    struct Report { let title: String; let subtitle: String; let sections: [Section] }

    func report() -> Report {
        let title = String(localized: "Дневник прикорма")
        let name = childName.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "Малыш") : childName
        let generated = now.formatted(.dateTime.day().month().year())
        let subtitle = "\(name) · \(ageMonths) \(String(localized: "мес")) · "
            + "\(String(localized: "Сформировано")) \(generated)"

        var sections: [Section] = [journalSection()]
        let reactions = reactionLogs()
        if !reactions.isEmpty { sections.append(reactionSection(reactions)) }
        if !allergens.isEmpty { sections.append(allergenSection()) }

        return Report(title: title, subtitle: subtitle, sections: sections)
    }

    private func journalSection() -> Section {
        let actual = logs.filter { !$0.planned }
        let byDay = Dictionary(grouping: actual) { calendar.startOfDay(for: $0.date) }
        var rows: [Row] = []
        for day in byDay.keys.sorted() {
            rows.append(Row(text: day.formatted(.dateTime.weekday(.wide).day().month().year()).capitalized,
                            bold: true))
            for log in (byDay[day] ?? []).sorted(by: { $0.date < $1.date }) {
                rows.append(Row(text: entryLine(log), indented: true))
            }
        }
        if rows.isEmpty { rows = [Row(text: String(localized: "Записей пока нет"), indented: true)] }
        return Section(heading: String(localized: "Журнал"), rows: rows)
    }

    private func reactionSection(_ reactions: [FoodLog]) -> Section {
        let rows = reactions.map { log -> Row in
            let name = catalog.food(id: log.foodId)?.localizedName ?? log.foodId
            let date = log.date.formatted(.dateTime.day().month().year())
            var line = "\(date) — \(name) — \((log.reaction ?? .other).title)"
            if let note = log.note, !note.isEmpty { line += " — «\(note)»" }
            return Row(text: line, indented: true)
        }
        let heading = "\(String(localized: "Реакции")) (\(reactions.count))"
        return Section(heading: heading, rows: rows)
    }

    private func allergenSection() -> Section {
        let rows = allergens.map { g -> Row in
            let status: String
            if g.hasAllergy {
                status = IntroState.allergy.title
            } else if !g.isIntroduced {
                status = IntroState.notIntroduced.title
            } else if let last = g.lastGiven {
                let d = last.formatted(.dateTime.day().month().year())
                status = "\(g.status.title) · \(String(localized: "последний приём")) \(d)"
            } else {
                status = g.status.title
            }
            return Row(text: "\(g.group.title) — \(status)", indented: true)
        }
        return Section(heading: String(localized: "Поддержка аллергенов"), rows: rows)
    }

    private func entryLine(_ log: FoodLog) -> String {
        let name = catalog.food(id: log.foodId)?.localizedName ?? log.foodId
        var parts = [log.type == .intro
                     ? String(localized: "Ввод")
                     : String(localized: "maintenance.type", defaultValue: "Поддержка")]
        if let liking = log.liking { parts.append(liking.title) }
        if let r = log.reaction, r != .none {
            parts.append("\(String(localized: "Реакция")): \(r.title)")
        }
        var line = "\(name) — " + parts.joined(separator: " · ")
        if let note = log.note, !note.isEmpty { line += " · «\(note)»" }
        return line
    }

    // MARK: - Отрисовка PDF (UIKit)

    func makeData() -> Data {
        let report = report()
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)   // A4
        let margin: CGFloat = 40
        let maxY = pageRect.height - margin
        let accent = UIColor(red: 1.0, green: 0.45, blue: 0.42, alpha: 1)

        return UIGraphicsPDFRenderer(bounds: pageRect).pdfData { ctx in
            var y = margin
            ctx.beginPage()

            func draw(_ text: String, font: UIFont, color: UIColor,
                      indent: CGFloat = 0, spacingAfter: CGFloat = 4) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let width = pageRect.width - margin * 2 - indent
                let h = ceil((text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs, context: nil).height)
                if y + h > maxY { ctx.beginPage(); y = margin }
                (text as NSString).draw(in: CGRect(x: margin + indent, y: y, width: width, height: h),
                                        withAttributes: attrs)
                y += h + spacingAfter
            }

            draw(report.title, font: .boldSystemFont(ofSize: 22), color: .black, spacingAfter: 2)
            draw(report.subtitle, font: .systemFont(ofSize: 12), color: .darkGray, spacingAfter: 16)
            for section in report.sections {
                draw(section.heading, font: .boldSystemFont(ofSize: 15), color: accent, spacingAfter: 6)
                for row in section.rows {
                    draw(row.text,
                         font: row.bold ? .systemFont(ofSize: 12, weight: .semibold)
                                        : .systemFont(ofSize: 11),
                         color: row.bold ? .black : UIColor.darkGray,
                         indent: row.indented ? 16 : 0,
                         spacingAfter: row.bold ? 4 : 3)
                }
                y += 10
            }
        }
    }

    /// Готовый временный файл для шаринга (`ShareLink`/share sheet).
    func writeTempFile() -> URL? {
        let safeName = childName.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "Дневник") : childName
        let file = "\(String(localized: "Дневник")) \(safeName).pdf"
            .replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(file)
        do { try makeData().write(to: url); return url } catch { return nil }
    }
}
