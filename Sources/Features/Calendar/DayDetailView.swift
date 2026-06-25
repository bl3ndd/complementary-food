import SwiftUI
import SwiftData

/// Детали одного дня: список продуктов с типом (ввод/поддержка), реакцией и
/// вкусовой оценкой (SPEC §7).
struct DayDetailView: View {
    let date: Date
    @Query private var logs: [FoodLog]

    private let catalog = FoodCatalog.shared

    private var day: DaySummary {
        CalendarService(catalog: catalog, logs: logs).day(date)
    }

    var body: some View {
        ScrollView {
            if day.entries.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(day.entries) { entryRow($0) }
                }
                .padding()
            }
        }
        .background(AppBackground())
        .navigationTitle(date.formatted(.dateTime.day().month().year()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func entryRow(_ entry: DayEntry) -> some View {
        HStack(spacing: 12) {
            if let food = entry.food {
                FoodIcon(food: food)
            } else {
                EmojiAvatar(emoji: "🍽️")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.foodName).font(.headline)
                HStack(spacing: 6) {
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.caption).foregroundStyle(.secondary)
                    StatusBadge(text: entry.type == .intro ? "Ввод" : "Поддержка",
                                color: entry.type == .intro ? Theme.accent : .blue)
                    if let reaction = entry.reaction, reaction != .none {
                        StatusBadge(text: reaction.title, color: .red)
                    }
                }
            }
            Spacer()
            if let liking = entry.liking {
                Text(liking.emoji).font(.system(size: 30))
            }
        }
        .cartoonCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🌙").font(.system(size: 64))
            Text("В этот день ничего не давали").font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}
