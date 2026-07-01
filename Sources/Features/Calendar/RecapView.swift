import SwiftUI
import UIKit

/// Шэр-карточка «Рекап месяца» (bucket 3): красивая 9:16-картинка «что нового
/// попробовали за месяц» → шэр в сторис. Рендерится в PNG через ImageRenderer.
/// Только факты из журнала, без советов.
struct RecapCard: View {
    let recap: MonthRecap

    var body: some View {
        VStack(spacing: 14) {
            Text("Pudding · \(monthTitle)")
                .font(.headline).foregroundStyle(.white.opacity(0.95))

            Mascot(mood: .cheer, size: 92)

            Text("\(childName), \(recap.ageMonths) \(String(localized: "мес"))")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.9))

            VStack(spacing: 0) {
                Text("\(heroNumber)")
                    .font(.system(size: 66, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(heroLabel)
                    .font(.subheadline.weight(.bold)).foregroundStyle(.white.opacity(0.92))
            }
            .padding(.top, 2)

            iconGrid

            if let fav = recap.favorite {
                Text("\(String(localized: "Любимое")): \(fav.localizedName) 😋")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(.white.opacity(0.18), in: Capsule())
            }

            Spacer(minLength: 0)
            Text("сделано в Pudding")
                .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
        }
        .padding(28)
        .frame(width: 360, height: 640)
        .background(
            LinearGradient(colors: [Theme.accent, Theme.accentDeep, Theme.lilac],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    private var iconGrid: some View {
        let foods = Array(recap.triedFoods.prefix(12))
        let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(foods) { FoodIcon(food: $0, size: 46) }
        }
    }

    private var childName: String {
        recap.childName.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "Малыш") : recap.childName
    }
    private var heroNumber: Int { recap.newCount > 0 ? recap.newCount : recap.triedFoods.count }
    private var heroLabel: String {
        recap.newCount > 0 ? String(localized: "новых вкусов")
                           : String(localized: "продуктов за месяц")
    }
    private var monthTitle: String {
        recap.month.formatted(.dateTime.month(.wide).year()).capitalized
    }
}

/// Превью карточки рекапа + шэр как картинки.
struct RecapSheet: View {
    let recap: MonthRecap
    @Environment(\.dismiss) private var dismiss
    @State private var shareFile: ShareableFile?

    var body: some View {
        NavigationStack {
            ScrollView {
                RecapCard(recap: recap)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                    .padding()
            }
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
