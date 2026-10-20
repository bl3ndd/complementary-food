import SwiftUI
import UIKit

/// Карточки рекап-карусели (Pro).
///
/// Все — в рамке 360×640 (9:16, формат сторис). Оформление — журнальная полоса:
/// бумажный фон из активной гаммы, текст по левому краю, крупная цифра
/// и подпись снизу. Ни градиентов, ни бликов, ни белых плашек: прежний вариант
/// (оранжевый градиент + плашка, прилипшая к верху) оставлял пустой половину кадра
/// и выглядел шаблоном.
///
/// Карточки принудительно светлые: они уезжают картинкой, и тёмная схема на чужом
/// экране выглядела бы случайностью.

// MARK: - Общая рамка

/// Фон, шапка и подпись — одинаковые у всех карточек карусели.
struct ShareCardChrome<Content: View>: View {
    /// Строка-надпись над содержимым: что это за карточка и когда.
    let kicker: String
    let childName: String
    /// Фото малыша. С ним карточку выкладывают заметно охотнее, чем с иконкой
    /// продукта — поэтому само фото бесплатное, оно работает на карусель.
    var photo: Data?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(kicker.uppercased())
                    .font(.caption.weight(.bold)).tracking(1.4)
                    .foregroundStyle(Theme.accentDeep)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if let photo, let ui = UIImage(data: photo) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                }
            }
            .frame(minHeight: 48)
            .padding(.top, 28)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)

            Spacer(minLength: 0)

            Rectangle().fill(Theme.ink.opacity(0.12)).frame(height: 1)
            HStack(spacing: 6) {
                Text(displayName)
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Mascot(mood: .happy, size: 18)
                Text("сделано в Pudding")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 28)
        .frame(width: 360, height: 640)
        .background(Theme.bgTop)
        .clipped()
        // Шрифт приложения задаётся в корне, а ImageRenderer рисует вне дерева —
        // без явного дизайна картинка для шэра вышла бы другим шрифтом, чем превью.
        .fontDesign(.rounded)
        .environment(\.colorScheme, .light)
    }

    private var displayName: String {
        childName.trimmingCharacters(in: .whitespaces).isEmpty
            ? String(localized: "Малыш") : childName
    }
}

/// Крупная цифра и подпись под ней — герой почти всех карточек.
struct HeroNumber: View {
    let value: Int
    let label: String
    var size: CGFloat = 112

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(.system(size: size, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineLimit(2).minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Сетка иконок продуктов, выровненная по левому краю.
private struct FoodGrid: View {
    let foods: [Food]
    let columns: Int
    let size: CGFloat

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(size), spacing: 10), count: columns),
                  alignment: .leading, spacing: 10) {
            ForEach(foods) { FoodIcon(food: $0, size: size, circular: true) }
        }
    }
}

// MARK: - Постер коллекции

struct CollectionPosterCard: View {
    let poster: CollectionPoster
    let childName: String
    var childPhoto: Data?

    /// Сетка обрезается, иначе на большой коллекции иконки станут микроскопическими.
    private var shown: [Food] { Array(poster.foods.prefix(30)) }

    var body: some View {
        ShareCardChrome(kicker: String(localized: "Коллекция вкусов"),
                        childName: childName, photo: childPhoto) {
            VStack(alignment: .leading, spacing: 24) {
                HeroNumber(value: poster.count, label: String(localized: "продуктов попробовано"))
                FoodGrid(foods: shown, columns: 6, size: 40)
                if poster.count > shown.count {
                    Text("и ещё \(poster.count - shown.count)")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
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
        ShareCardChrome(kicker: String(localized: "Новая веха"),
                        childName: childName, photo: childPhoto) {
            VStack(alignment: .leading, spacing: 20) {
                HeroNumber(value: milestone.reached,
                           label: String(localized: "продуктов в коллекции"), size: 200)
                if milestone.total > milestone.reached {
                    Text("а всего уже \(milestone.total)")
                        .font(.title3.weight(.semibold)).foregroundStyle(.secondary)
                }
                Mascot(mood: .cheer, size: 96)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 12)
            }
        }
    }
}

// MARK: - Первый раз

struct FirstTimeCard: View {
    let firstTime: FirstTime
    let childName: String
    var childPhoto: Data?

    /// Фото самой записи — это и есть кадр «первой ложки», ради него карточку и делают.
    private var logPhoto: UIImage? {
        let data = firstTime.log.photo ?? firstTime.log.photos?
            .sorted { $0.sortIndex < $1.sortIndex }.first?.data
        return data.flatMap(UIImage.init(data:))
    }

    var body: some View {
        ShareCardChrome(kicker: String(localized: "Первый раз"),
                        childName: childName, photo: childPhoto) {
            VStack(alignment: .leading, spacing: 16) {
                if let logPhoto {
                    Image(uiImage: logPhoto).resizable().scaledToFill()
                        .frame(width: 304, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    FoodIcon(food: firstTime.food, size: 150, circular: true)
                        .padding(.vertical, 20)
                }

                Text(firstTime.food.localizedName)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2).minimumScaleFactor(0.6)

                HStack(spacing: 10) {
                    Text(firstTime.date.formatted(.dateTime.day().month(.wide)))
                        .foregroundStyle(.secondary)
                    if let liking = firstTime.liking {
                        Text("·").foregroundStyle(.secondary)
                        Text(liking.title).foregroundStyle(Theme.accentDeep)
                    }
                }
                .font(.title3.weight(.semibold))
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
        ShareCardChrome(kicker: String(localized: "Что зашло"),
                        childName: childName, photo: childPhoto) {
            VStack(alignment: .leading, spacing: 28) {
                column(String(localized: "Любимое"), top.liked, accent: true)
                if !top.disliked.isEmpty {
                    column(String(localized: "Не зашло"), Array(top.disliked.prefix(3)), accent: false)
                }
            }
        }
    }

    private func column(_ title: String, _ foods: [Food], accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(accent ? Theme.accent : Theme.ink)
            ForEach(foods) { food in
                HStack(spacing: 12) {
                    FoodIcon(food: food, size: 36, circular: true)
                    // Без minimumScaleFactor: длинные названия ужимались каждое
                    // по-своему, и список прыгал по размеру. Пусть лучше обрежутся.
                    Text(food.localizedName)
                        .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                        .lineLimit(1)
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

    private let cal = Calendar.current
    private var marked: Set<Int> { Set(calendar.days) }
    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: calendar.month)?.count ?? 30
    }
    /// Сколько пустых клеток перед первым числом — сетка начинается с первого дня
    /// недели локали, как настоящий календарь.
    private var leadingBlanks: Int {
        let weekday = cal.component(.weekday, from: calendar.month)
        return (weekday - cal.firstWeekday + 7) % 7
    }
    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        ShareCardChrome(kicker: monthTitle, childName: childName, photo: childPhoto) {
            VStack(alignment: .leading, spacing: 24) {
                HeroNumber(value: calendar.days.count,
                           label: String(localized: "дней с новым вкусом"))

                let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                        Text(s).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    }
                    ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 34) }
                    ForEach(1...daysInMonth, id: \.self) { day in
                        let on = marked.contains(day)
                        Text("\(day)")
                            .font(.footnote.weight(on ? .bold : .regular))
                            .foregroundStyle(on ? .white : Theme.ink.opacity(0.45))
                            .frame(width: 34, height: 34)
                            .background(on ? Theme.accent : .clear, in: Circle())
                    }
                }
            }
        }
    }

    private var monthTitle: String {
        calendar.month.formatted(.dateTime.month(.wide).year())
    }
}
