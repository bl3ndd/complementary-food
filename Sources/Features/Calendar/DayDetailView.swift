import SwiftUI
import SwiftData

/// Детали одного дня: список продуктов с типом (ввод/поддержка), реакцией и
/// вкусовой оценкой (SPEC §7).
struct DayDetailView: View {
    let date: Date
    @Query private var logs: [FoodLog]
    @State private var editingLog: FoodLog?

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
        .sheet(item: $editingLog) { EditNoteSheet(log: $0) }
    }

    private func entryRow(_ entry: DayEntry) -> some View {
        HStack(spacing: 12) {
            if let food = entry.food {
                FoodIcon(food: food)
            } else {
                EmojiAvatar(emoji: "🍽️", asset: "ui_plate")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.food?.localizedName ?? entry.foodName).font(.headline)
                HStack(spacing: 6) {
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.caption).foregroundStyle(.secondary)
                    StatusBadge(text: entry.type == .intro
                                ? String(localized: "Ввод")
                                : String(localized: "maintenance.type", defaultValue: "Поддержка"),
                                color: entry.type == .intro ? Theme.accent : .blue)
                    if let reaction = entry.reaction, reaction != .none {
                        StatusBadge(text: reaction.title, color: .red)
                    }
                }
                if let note = entry.log.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let liking = entry.liking {
                Text(liking.emoji).font(.system(size: 30))
            }
        }
        .cartoonCard()
        .contentShape(Rectangle())
        .onTapGesture { editingLog = entry.log }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Mascot(mood: .sleepy)
            Text("В этот день ничего не давали").font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}
