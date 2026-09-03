import SwiftUI
import UIKit

/// Карточки рекап-карусели (Pro).
///
/// Все — в той же рамке 360×640, что и месячный `RecapCard`, чтобы шэрились
/// одинаково. Но оформление тише: крупная цифра, воздух и типографика вместо
/// декора. Конфетти и бликов здесь нет намеренно — карточка должна выглядеть
/// как разворот журнала, а не как баннер.
///
/// Как и `RecapCard`, карточки принудительно светлые: они уезжают картинкой, и
/// `.secondary` внутри белой плашки в тёмной теме стал бы светло-серым на белом.

// MARK: - Общая рамка

/// Фон, шапка и подпись — одинаковые у всех карточек карусели.
struct ShareCardChrome<Content: View>: View {
    let title: String
    let subtitle: String?
    /// Фото малыша. С ним карточку выкладывают заметно охотнее, чем с иконкой
    /// продукта — поэтому само фото бесплатное, оно работает на карусель.
    var photo: Data?
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            // Фон из активной гаммы: то, что мама выкладывает в сторис, должно
            // совпадать с тем, как выглядит её приложение.
            LinearGradient(colors: [Theme.accent, Theme.accentDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 0) {
                Text(title)
                    .font(.subheadline.weight(.heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .background(.white.opacity(0.20), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
                    .padding(.top, 30)

                if let photo, let ui = UIImage(data: photo) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 3))
                        .padding(.top, 14)
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 8)
                }

                content
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Mascot(mood: .happy, size: 22)
                    Text("сделано в Pudding")
                        .font(.caption.weight(.bold)).foregroundStyle(.white)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.white.opacity(0.18), in: Capsule())
                .padding(.bottom, 24)
            }
        }
        .frame(width: 360, height: 640)
        .clipped()
        .environment(\.colorScheme, .light)
    }
}

/// Белая плашка под содержимое — как в месячной карточке, но без тени-«ореола».
private struct Sheet<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

/// Крупное число с подписью — общий герой почти всех карточек.
private struct HeroNumber: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.headline.weight(.bold)).foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Постер коллекции

struct CollectionPosterCard: View {
    let poster: CollectionPoster
    let childName: String
    var childPhoto: Data?

    /// Сетка обрезается, иначе на большой коллекции иконки станут микроскопическими.
    private var shown: [Food] { Array(poster.foods.prefix(24)) }

    var body: some View {
        ShareCardChrome(title: String(localized: "Коллекция вкусов"), subtitle: childName, photo: childPhoto) {
            Sheet {
                VStack(spacing: 18) {
                    HeroNumber(value: poster.count, label: String(localized: "продуктов попробовано"))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10),
                                             count: 6), spacing: 10) {
                        ForEach(shown) { food in
                            FoodIcon(food: food, size: 34, circular: true)
                        }
                    }
                    .padding(.horizontal, 18)

                    if poster.count > shown.count {
                        Text("и ещё \(poster.count - shown.count)")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Веха

struct MilestoneCard: View {
    let milestone: Milestone
    let childName: String
    var childPhoto: Data?

    var body: some View {
        ShareCardChrome(title: String(localized: "Новая веха"), subtitle: childName, photo: childPhoto) {
            Sheet {
                VStack(spacing: 16) {
                    Mascot(mood: .cheer, size: 92)
                    HeroNumber(value: milestone.reached,
                               label: String(localized: "продуктов в коллекции"))
                    if milestone.total > milestone.reached {
                        Text("а всего уже \(milestone.total)")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Первый раз

struct FirstTimeCard: View {
    let firstTime: FirstTime
    let childName: String
    var childPhoto: Data?

    var body: some View {
        ShareCardChrome(title: String(localized: "Первый раз"), subtitle: childName, photo: childPhoto) {
            Sheet {
                VStack(spacing: 16) {
                    FoodIcon(food: firstTime.food, size: 96, circular: true)

                    Text(firstTime.food.localizedName)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Text(firstTime.date.formatted(.dateTime.day().month(.wide)))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)

                    if let liking = firstTime.liking {
                        Text(liking.title)
                            .font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Theme.accent.opacity(0.14), in: Capsule())
                    }
                }
            }
        }
    }
}

// MARK: - Топ вкусов

struct TastesTopCard: View {
    let top: TastesTop
    let childName: String
    var childPhoto: Data?

    var body: some View {
        ShareCardChrome(title: String(localized: "Что зашло"), subtitle: childName, photo: childPhoto) {
            Sheet {
                VStack(alignment: .leading, spacing: 18) {
                    column(String(localized: "Любимое"), top.liked)
                    if !top.disliked.isEmpty {
                        column(String(localized: "Не зашло"), top.disliked)
                    }
                }
                .padding(.horizontal, 26)
            }
        }
    }

    private func column(_ title: String, _ foods: [Food]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.heavy)).foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(foods) { food in
                HStack(spacing: 10) {
                    FoodIcon(food: food, size: 30, circular: true)
                    Text(food.localizedName)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                }
            }
        }
    }
}

// MARK: - Календарь вкусов

struct TasteCalendarCard: View {
    let calendar: TasteCalendar
    let childName: String
    var childPhoto: Data?

    private var marked: Set<Int> { Set(calendar.days) }
    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: calendar.month)?.count ?? 30
    }

    var body: some View {
        ShareCardChrome(title: monthTitle, subtitle: childName, photo: childPhoto) {
            Sheet {
                VStack(spacing: 18) {
                    HeroNumber(value: calendar.days.count,
                               label: String(localized: "дней с новым вкусом"))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6),
                                             count: 7), spacing: 6) {
                        ForEach(1...daysInMonth, id: \.self) { day in
                            Circle()
                                .fill(marked.contains(day) ? Theme.accent : Color.black.opacity(0.06))
                                .frame(height: 26)
                        }
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
    }

    private var monthTitle: String {
        calendar.month.formatted(.dateTime.month(.wide).year()).capitalized
    }
}
