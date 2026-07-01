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
    /// Статусы ввода — для листа «не давать» (пауза/аллергия). Опционально.
    var statuses: [IntroductionStatus] = []
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
    struct PhotoItem { let caption: String; let data: Data }
    struct Report {
        let title: String
        let subtitle: String
        let sections: [Section]
        let photos: [PhotoItem]
    }

    /// Фото из записей (тарелки/сыпь) для приложения-фотоотчёта, старые сверху.
    func photoItems() -> [PhotoItem] {
        logs.filter { !$0.planned && $0.photo != nil }
            .sorted { $0.date < $1.date }
            .compactMap { log in
                guard let data = log.photo else { return nil }
                let name = catalog.food(id: log.foodId)?.localizedName ?? log.foodId
                let d = log.date.formatted(.dateTime.day().month().year())
                return PhotoItem(caption: "\(d) · \(name)", data: data)
            }
    }

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

        return Report(title: title, subtitle: subtitle,
                      sections: sections, photos: photoItems())
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
            if let sev = log.severity { line += " · \(sev.title)" }
            if log.photo != nil { line += " · 📷" }
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
            var rp = "\(String(localized: "Реакция")): \(r.title)"
            if let sev = log.severity { rp += " (\(sev.title))" }
            parts.append(rp)
        }
        var line = "\(name) — " + parts.joined(separator: " · ")
        if let note = log.note, !note.isEmpty { line += " · «\(note)»" }
        return line
    }

    // MARK: - Лист «не давать» (няне / в садик)

    struct AvoidItem { let name: String; let reason: String }

    /// Продукты «не давать»: на паузе (реакция при вводе / отложили) или аллергия.
    func avoidItems() -> [AvoidItem] {
        statuses
            .filter { $0.state == .paused || $0.state == .allergy }
            .compactMap { st -> AvoidItem? in
                guard let food = catalog.food(id: st.foodId) else { return nil }
                return AvoidItem(name: food.localizedName,
                                 reason: st.state == .allergy
                                    ? IntroState.allergy.title : IntroState.paused.title)
            }
            .sorted { $0.name < $1.name }
    }

    /// Одностраничный отчёт «Что НЕ давать» — для няни/садика.
    func avoidReport() -> Report {
        let name = childName.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "Малыш") : childName
        let subtitle = "\(name) · \(String(localized: "Сформировано")) "
            + now.formatted(.dateTime.day().month().year())
        let items = avoidItems()
        let rows = items.isEmpty
            ? [Row(text: String(localized: "Ограничений нет"), indented: true)]
            : items.map { Row(text: "\($0.name) — \($0.reason)", indented: true) }
        return Report(title: String(localized: "Что НЕ давать"),
                      subtitle: subtitle,
                      sections: [Section(heading: String(localized: "Список"), rows: rows)],
                      photos: [])
    }

    // MARK: - Отрисовка PDF (UIKit)

    func makeData() -> Data { render(report()) }
    func makeAvoidData() -> Data { render(avoidReport()) }

    private func render(_ report: Report) -> Data {
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

            // Приложение с фото (тарелки/сыпь) — сеткой 2 колонки, с подписью.
            guard !report.photos.isEmpty else { return }
            draw(String(localized: "Фото"), font: .boldSystemFont(ofSize: 15),
                 color: accent, spacingAfter: 8)
            let gap: CGFloat = 12
            let colW = (pageRect.width - margin * 2 - gap) / 2
            let maxImgH: CGFloat = 170
            var rowTop = y, rowMaxH: CGFloat = 0, col = 0
            for item in report.photos {
                guard let img = UIImage(data: item.data) else { continue }
                let ar = img.size.height / max(img.size.width, 1)
                let drawH = min(maxImgH, colW * ar)
                let blockH = drawH + 16
                if col == 0, rowTop + blockH > maxY { ctx.beginPage(); rowTop = margin; rowMaxH = 0 }
                let x = margin + CGFloat(col) * (colW + gap)
                img.draw(in: CGRect(x: x, y: rowTop, width: colW, height: drawH))
                (item.caption as NSString).draw(
                    in: CGRect(x: x, y: rowTop + drawH + 2, width: colW, height: 12),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 9),
                                     .foregroundColor: UIColor.darkGray])
                rowMaxH = max(rowMaxH, blockH)
                col += 1
                if col == 2 { rowTop += rowMaxH + 6; rowMaxH = 0; col = 0 }
            }
        }
    }

    /// Готовый временный PDF-дневник «для педиатра».
    func writeTempFile() -> URL? {
        writeTempFile(makeData(), prefix: String(localized: "Дневник"))
    }

    /// Готовый временный лист «Что НЕ давать».
    func writeAvoidTempFile() -> URL? {
        writeTempFile(makeAvoidData(), prefix: String(localized: "Не давать"))
    }

    private func writeTempFile(_ data: Data, prefix: String) -> URL? {
        let name = childName.trimmingCharacters(in: .whitespaces).isEmpty ? "" : " \(childName)"
        let file = "\(prefix)\(name).pdf".replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(file)
        do { try data.write(to: url); return url } catch { return nil }
    }
}
