import SwiftUI
import UIKit

/// Что показываем в карусели. Пустые карточки в список не попадают — листать
/// «ноль продуктов» незачем.
enum RecapCardKind: Identifiable {
    case month(MonthRecap)
    case poster(CollectionPoster)
    case milestone(Milestone)
    case firstTime(FirstTime)
    case tastes(TastesTop)
    case tasteCalendar(TasteCalendar)

    var id: String {
        switch self {
        case .month:        return "month"
        case .poster:       return "poster"
        case .milestone:    return "milestone"
        case .firstTime:    return "firstTime"
        case .tastes:       return "tastes"
        case .tasteCalendar: return "calendar"
        }
    }
}

/// Свайп-карусель шэр-карточек (Pro).
///
/// Месячная карточка идёт первой и остаётся бесплатной — она крючок: человек
/// видит формат и хочет остальные.
struct RecapCarouselView: View {
    let cards: [RecapCardKind]
    let childName: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var shareFile: ShareableFile?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TabView(selection: $index) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, kind in
                        card(kind)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(reduceMotion ? nil : .easeInOut, value: index)
            }
            .background(AppBackground())
            .navigationTitle("Рекап")
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

    @ViewBuilder
    private func card(_ kind: RecapCardKind) -> some View {
        switch kind {
        case let .month(recap):     RecapCard(recap: recap)
        case let .poster(poster):   CollectionPosterCard(poster: poster, childName: childName)
        case let .milestone(m):     MilestoneCard(milestone: m, childName: childName)
        case let .firstTime(ft):    FirstTimeCard(firstTime: ft, childName: childName)
        case let .tastes(top):      TastesTopCard(top: top, childName: childName)
        case let .tasteCalendar(c): TasteCalendarCard(calendar: c, childName: childName)
        }
    }

    /// Шэрим ровно ту карточку, которая сейчас на экране.
    @MainActor private func share() {
        guard cards.indices.contains(index) else { return }
        let renderer = ImageRenderer(content: card(cards[index]))
        renderer.scale = 3
        guard let ui = renderer.uiImage, let data = ui.pngData() else { return }

        let suffix = childName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "" : " \(childName)"
        let file = "Pudding\(suffix).png".replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(file)
        do { try data.write(to: url); shareFile = ShareableFile(url: url) } catch {}
    }
}
