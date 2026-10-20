import SwiftUI
import UIKit

/// Шэр-карточка «Рекап месяца» (bucket 3): красивая 9:16-картинка «что нового
/// попробовали за месяц» → шэр в сторис. Рендерится в PNG через ImageRenderer.
/// Только факты из журнала, без советов.
struct RecapCard: View {
    let recap: MonthRecap
    var childPhoto: Data?

    var body: some View {
        // Та же журнальная рамка, что у карточек карусели: месячная идёт в ней
        // первой, и выбиваться из ряда ей нельзя.
        ShareCardChrome(kicker: "\(monthTitle) · \(recap.ageMonths) \(String(localized: "мес"))",
                        childName: recap.childName, photo: childPhoto) {
            VStack(alignment: .leading, spacing: 22) {
                HeroNumber(value: heroNumber, label: heroLabel)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(48), spacing: 12), count: 5),
                          alignment: .leading, spacing: 12) {
                    ForEach(recap.triedFoods.prefix(15)) { FoodIcon(food: $0, size: 48, circular: true) }
                }

                if let fav = recap.favorite {
                    HStack(spacing: 10) {
                        FoodIcon(food: fav, size: 32, circular: true)
                        Text("\(String(localized: "Любимое")): \(fav.localizedName)")
                            .font(.headline).foregroundStyle(Theme.ink)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }

                Text(statsLine)
                    .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
    }

    /// Сводка-факты: сколько всего записей и продуктов за месяц.
    private var statsLine: String {
        "\(String(localized: "Записей")): \(recap.totalLogs) · \(String(localized: "продуктов")): \(recap.triedFoods.count)"
    }

    private var heroNumber: Int { recap.newCount > 0 ? recap.newCount : recap.triedFoods.count }
    private var heroLabel: String {
        recap.newCount > 0 ? String(localized: "новых вкусов")
                           : String(localized: "продуктов за месяц")
    }
    private var monthTitle: String {
        recap.month.formatted(.dateTime.month(.wide).year()).firstCapitalized
    }
}

/// Превью карточки рекапа + шэр как картинки.
struct RecapSheet: View {
    let recap: MonthRecap
    @Environment(\.dismiss) private var dismiss
    @State private var shareFile: ShareableFile?

    var body: some View {
        NavigationStack {
            FittedShareCard { RecapCard(recap: recap) }
                .padding()
            .background(AppBackground())
            .navigationTitle("Рекап месяца")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                BigButton(title: "Поделиться") { share() }
                    .padding()
            }
            .sheet(item: $shareFile) { ActivityView(items: [$0.url]) }
        }
        .cozySheet()
    }

    @MainActor private func share() {
        let renderer = ImageRenderer(content: RecapCard(recap: recap))
        renderer.scale = 3
        guard let ui = renderer.uiImage, let data = ui.pngData() else { return }
        let suffix = recap.childName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "" : " \(recap.childName)"
        let file = "Pudding\(suffix).png".replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(file)
        do { try data.write(to: url); shareFile = ShareableFile(url: url) } catch {}
    }
}
