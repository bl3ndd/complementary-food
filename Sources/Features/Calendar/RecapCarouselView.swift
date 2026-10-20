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

extension RecapCardKind {
    /// Собирает набор карточек, выбрасывая пустые: листать «ноль продуктов»
    /// незачем, а пустая карточка в сторис выглядит как баг.
    /// Месячная идёт первой — она бесплатная и служит крючком.
    static func carousel(month: MonthRecap,
                         poster: CollectionPoster,
                         milestone: Milestone?,
                         firstTime: FirstTime?,
                         tastes: TastesTop,
                         tasteCalendar: TasteCalendar) -> [RecapCardKind] {
        var out: [RecapCardKind] = []
        if !month.isEmpty { out.append(.month(month)) }
        if !poster.isEmpty { out.append(.poster(poster)) }
        if let milestone { out.append(.milestone(milestone)) }
        if let firstTime { out.append(.firstTime(firstTime)) }
        if !tastes.isEmpty { out.append(.tastes(tastes)) }
        if !tasteCalendar.days.isEmpty { out.append(.tasteCalendar(tasteCalendar)) }
        return out
    }
}

/// Свайп-карусель шэр-карточек (Pro).
///
/// Месячная карточка идёт первой и остаётся бесплатной — она крючок: человек
/// видит формат и хочет остальные.
struct RecapCarouselView: View {
    let cards: [RecapCardKind]
    let childName: String
    var childPhoto: Data?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var shareFile: ShareableFile?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TabView(selection: $index) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, kind in
                        FittedShareCard { card(kind) }
                            .padding(.horizontal)
                            .tag(i)
                    }
                }
                // Системные точки белые и теряются на светлой карточке — свои, в акценте.
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut, value: index)

                HStack(spacing: 7) {
                    ForEach(cards.indices, id: \.self) { i in
                        Circle()
                            .fill(i == index ? Theme.accent : Theme.hairline)
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityHidden(true)
            }
            .padding(.top, 8)
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

    private func card(_ kind: RecapCardKind) -> some View {
        Self.cardView(kind, childName: childName, childPhoto: childPhoto)
    }

    /// Карточка отдельно от карусели — её же рендерят тесты.
    @ViewBuilder
    static func cardView(_ kind: RecapCardKind, childName: String, childPhoto: Data?) -> some View {
        switch kind {
        case let .month(recap):     RecapCard(recap: recap, childPhoto: childPhoto)
        case let .poster(poster):   CollectionPosterCard(poster: poster, childName: childName, childPhoto: childPhoto)
        case let .milestone(m):     MilestoneCard(milestone: m, childName: childName, childPhoto: childPhoto)
        case let .firstTime(ft):    FirstTimeCard(firstTime: ft, childName: childName, childPhoto: childPhoto)
        case let .tastes(top):      TastesTopCard(top: top, childName: childName, childPhoto: childPhoto)
        case let .tasteCalendar(c): TasteCalendarCard(calendar: c, childName: childName, childPhoto: childPhoto)
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

/// Карточка 360×640, вписанная в доступное место целиком. На телефоне между
/// навбаром и кнопкой «Поделиться» меньше 640 pt по высоте — без масштаба низ
/// карточки (подпись «сделано в Pudding») обрезался. В картинку для шэра уходит
/// исходный размер, масштаб только для показа.
struct FittedShareCard<Card: View>: View {
    @ViewBuilder var card: Card

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / 360, geo.size.height / 640, 1)
            card
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1))
                .scaleEffect(scale)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
