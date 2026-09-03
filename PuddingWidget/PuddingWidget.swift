import WidgetKit
import SwiftUI

/// Виджет «Коллекция»: растущая сетка продуктов, которые малыш уже попробовал.
///
/// Данные берёт из снимка в App Group — расширение не открывает SwiftData и не
/// знает про CloudKit. Нет снимка (App Group не выдана, приложение ещё ни разу не
/// сохраняло) — показываем пустое состояние, а не падаем.
struct CollectionEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct CollectionProvider: TimelineProvider {
    func placeholder(in context: Context) -> CollectionEntry {
        CollectionEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CollectionEntry) -> Void) {
        completion(CollectionEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CollectionEntry>) -> Void) {
        // Обновление приложение вызывает само через WidgetCenter при изменении
        // журнала; таймлайн — страховка на случай, если приложение долго не
        // открывали.
        let entry = CollectionEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct CollectionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CollectionEntry

    private var columns: Int { family == .systemSmall ? 3 : 6 }
    private var capacity: Int { family == .systemSmall ? 6 : 12 }

    var body: some View {
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
                        Text(item.emoji).font(.system(size: family == .systemSmall ? 22 : 20))
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
        StaticConfiguration(kind: "PuddingCollection", provider: CollectionProvider()) { entry in
            // Свой фон и тени в виджете выглядят инородно: система даёт материал сама.
            CollectionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Коллекция")
        .description("Растущая сетка продуктов, которые малыш попробовал.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PuddingWidgetBundle: WidgetBundle {
    var body: some Widget { CollectionWidget() }
}
