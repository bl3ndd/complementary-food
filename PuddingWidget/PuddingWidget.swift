import WidgetKit
import SwiftUI
import UIKit

/// Виджеты Pudding: «Коллекция» (сетка попробованного) и «Сейчас вводишь»
/// (что вводится и что дальше по своему плану).
///
/// Данные берут из снимка в App Group — расширение не открывает SwiftData и не
/// знает про CloudKit. Нет снимка (App Group не выдана, приложение ещё ни разу не
/// сохраняло) — показываем пустое состояние, а не падаем. Без Pro — заглушка.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        // Обновление приложение вызывает само через WidgetCenter при изменении
        // журнала; таймлайн — страховка на случай, если приложение долго не
        // открывали (и чтобы «завтра» в плане вовремя стало «сегодня»).
        let entry = SnapshotEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Общее

/// Иконка продукта из снимка: PNG, отрисованный приложением; если его нет —
/// эмодзи в том же квадрате, чтобы сетка не разъезжалась.
private struct ItemIcon: View {
    let item: WidgetSnapshot.Item
    let size: CGFloat

    var body: some View {
        if let data = item.icon, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(item.emoji).font(.system(size: size * 0.7))
                .frame(width: size, height: size)
        }
    }
}

/// Заглушка без Pro: что это за виджет и где его включить. Без данных дневника.
private struct LockedView: View {
    let title: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Image(systemName: "lock.fill").font(.title3).foregroundStyle(.secondary)
            Text("Виджет — часть Pudding Pro")
                .font(.footnote.weight(.semibold))
            Text("Открой Pudding → Профиль → Pudding Pro")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Коллекция

struct CollectionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var columns: Int { family == .systemSmall ? 3 : 6 }
    private var capacity: Int { family == .systemSmall ? 6 : 12 }

    var body: some View {
        if entry.snapshot?.locked == true {
            LockedView(title: "Коллекция")
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Коллекция").font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let total = entry.snapshot?.total, total > 0 {
                    Text("\(total)").font(.caption.weight(.heavy))
                }
            }

            if let items = entry.snapshot?.items, !items.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4),
                                        count: columns), spacing: 6) {
                    ForEach(items.suffix(capacity), id: \.id) { item in
                        ItemIcon(item: item, size: family == .systemSmall ? 34 : 30)
                    }
                }
            } else {
                Text("Здесь появятся продукты, которые малыш попробовал")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
    }
}

struct CollectionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PuddingCollection", provider: SnapshotProvider()) { entry in
            // Свой фон и тени в виджете выглядят инородно: система даёт материал сама.
            CollectionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Коллекция")
        .description("Растущая сетка продуктов, которые малыш попробовал.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Сейчас вводишь

/// Что вводится и сколько кормлений из нужных уже было; в medium — ещё и что
/// дальше по своему плану. «Дальше» — только запланированное самим человеком.
struct IntroducingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var intros: [WidgetSnapshot.Intro] { entry.snapshot?.introducing ?? [] }
    private var planned: [WidgetSnapshot.Planned] { entry.snapshot?.planned ?? [] }

    var body: some View {
        if family == .systemSmall {
            small
        } else {
            medium
        }
    }

    // Small: один вводимый продукт крупно; если ничего не вводится — ближайший план.
    @ViewBuilder private var small: some View {
        if let intro = intros.first {
            VStack(alignment: .leading, spacing: 6) {
                Text("Сейчас вводишь").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                ItemIcon(item: intro.item, size: 44)
                Text(intro.item.name ?? intro.item.emoji)
                    .font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                progress(intro)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if let next = planned.first {
            VStack(alignment: .leading, spacing: 6) {
                Text("Дальше по плану").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                ItemIcon(item: next.item, size: 44)
                Text(next.item.name ?? next.item.emoji)
                    .font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                Text(dayLabel(next.date)).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            empty
        }
    }

    // Medium: слева — что вводится, справа — что дальше по плану.
    @ViewBuilder private var medium: some View {
        if intros.isEmpty && planned.isEmpty {
            empty
        } else {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Сейчас вводишь").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    if intros.isEmpty {
                        Text("Сейчас ничего не вводится")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(intros, id: \.item.id) { intro in
                        HStack(spacing: 8) {
                            ItemIcon(item: intro.item, size: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(intro.item.name ?? intro.item.emoji)
                                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                                progress(intro)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Дальше по плану").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    if planned.isEmpty {
                        Text("В плане пока пусто")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(planned, id: \.item.id) { next in
                        HStack(spacing: 8) {
                            ItemIcon(item: next.item, size: 24)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(next.item.name ?? next.item.emoji)
                                    .font(.caption.weight(.semibold)).lineLimit(1)
                                Text(dayLabel(next.date))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Сейчас вводишь").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("Начни вводить продукт в каталоге — он появится здесь")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// «1 из 2 кормлений» и тонкая шкала под ним.
    private func progress(_ intro: WidgetSnapshot.Intro) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(intro.done) из \(intro.window) кормлений")
                .font(.caption2).foregroundStyle(.secondary)
            ProgressView(value: Double(intro.done), total: Double(max(intro.window, 1)))
                // Гамма живёт в приложении, расширению она неизвестна — берём
                // базовый акцент Pudding.
                .tint(Color(red: 0.99, green: 0.49, blue: 0.31))
        }
    }

    /// «Сегодня», «Завтра» или дата — по локали устройства.
    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return String(localized: "Сегодня") }
        if cal.isDateInTomorrow(date) { return String(localized: "Завтра") }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

struct IntroducingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PuddingIntroducing", provider: SnapshotProvider()) { entry in
            IntroducingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Сейчас вводишь")
        .description("Что вводится сейчас и что дальше по твоему плану.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PuddingWidgetBundle: WidgetBundle {
    var body: some Widget {
        IntroducingWidget()
        CollectionWidget()
    }
}
