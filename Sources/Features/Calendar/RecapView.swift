import SwiftUI
import UIKit

/// Шэр-карточка «Рекап месяца» (bucket 3): красивая 9:16-картинка «что нового
/// попробовали за месяц» → шэр в сторис. Рендерится в PNG через ImageRenderer.
/// Только факты из журнала, без советов.
struct RecapCard: View {
    let recap: MonthRecap

    var body: some View {
        ZStack {
            // Фон: бренд-градиент + мягкие блики + рассыпанное конфетти.
            LinearGradient(colors: [Theme.accent, Theme.accentDeep, Theme.lilac],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            glow(x: 60, y: 80, r: 150, opacity: 0.20)
            glow(x: 320, y: 560, r: 170, opacity: 0.14)
            confettiDots

            VStack(spacing: 0) {
                // Шапка: месяц капсулой + имя.
                Text(monthTitle)
                    .font(.subheadline.weight(.heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(.white.opacity(0.20), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
                    .padding(.top, 26)

                Text("\(childName) · \(recap.ageMonths) \(String(localized: "мес"))")
                    .font(.footnote.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 8)

                // Маскот выглядывает из-за белой карты.
                Mascot(mood: .cheer, size: 96)
                    .padding(.top, 14)
                    .zIndex(1)

                // Белая карта с фактами месяца.
                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(heroNumber)")
                            .font(.system(size: 58, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.accent)
                        Text(heroLabel)
                            .font(.headline.weight(.bold)).foregroundStyle(.primary)
                    }
                    .padding(.top, 34)   // место под свисающего маскота

                    iconGrid

                    if let fav = recap.favorite {
                        HStack(spacing: 8) {
                            FoodIcon(food: fav, size: 30, circular: true)
                            Text("\(String(localized: "Любимое")): \(fav.localizedName)")
                                .font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                            OpenMojiIcon(asset: "like_liked", fallback: "😋", size: 22)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Theme.sunny.opacity(0.20), in: Capsule())
                    }

                    Text(statsLine)
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: .infinity)
                .background(.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .padding(.horizontal, 22)
                .padding(.top, -30)      // карта заезжает под маскота
                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Mascot(mood: .happy, size: 22)
                    Text("сделано в Pudding")
                        .font(.caption.weight(.bold)).foregroundStyle(.white)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.white.opacity(0.18), in: Capsule())
                .padding(.bottom, 22)
            }
        }
        .frame(width: 360, height: 640)
        .clipped()
    }

    /// Мягкий белый блик (радиальный градиент — без blur, дёшево для ImageRenderer).
    private func glow(x: CGFloat, y: CGFloat, r: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(RadialGradient(gradient: Gradient(colors: [.white.opacity(opacity), .clear]),
                                 center: .center, startRadius: 0, endRadius: r))
            .frame(width: r * 2, height: r * 2)
            .position(x: x, y: y)
    }

    /// Точка конфетти: позиция/размер детерминированы от индекса (sin-хэш).
    private struct Dot: Identifiable {
        let id: Int
        let x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat
        let angle: Double, opacity: Double, colorIndex: Int

        init(_ i: Int) {
            id = i
            let fx = abs(sin(Double(i) * 12.9898))
            let fy = abs(sin(Double(i) * 78.233))
            let fs = abs(sin(Double(i) * 39.425))
            x = 20 + CGFloat(fx) * 320
            y = 20 + CGFloat(fy) * 600
            w = 6 + 6 * CGFloat(fs)
            h = 4 + 4 * CGFloat(fs)
            angle = fs * 360
            opacity = 0.35 + 0.3 * fs
            colorIndex = i % 5
        }
    }

    /// Рассыпанное конфетти по фону.
    private var confettiDots: some View {
        let colors: [Color] = [.white, Theme.sunny, Theme.mint, .white, Theme.sky]
        let dots = (0..<16).map(Dot.init)
        return ForEach(dots) { d in
            RoundedRectangle(cornerRadius: 2)
                .fill(colors[d.colorIndex].opacity(d.opacity))
                .frame(width: d.w, height: d.h)
                .rotationEffect(.degrees(d.angle))
                .position(x: d.x, y: d.y)
        }
    }

    private var iconGrid: some View {
        let foods = Array(recap.triedFoods.prefix(12))
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(foods) { FoodIcon(food: $0, size: 52, circular: true) }
        }
        .padding(.horizontal, 24)
    }

    /// Сводка-факты: сколько всего записей и продуктов за месяц.
    private var statsLine: String {
        "\(String(localized: "Записей")): \(recap.totalLogs) · \(String(localized: "продуктов")): \(recap.triedFoods.count)"
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
