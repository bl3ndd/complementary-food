import SwiftUI
import SwiftData

/// Детали одного дня: список продуктов с типом (ввод/поддержка), реакцией и
/// вкусовой оценкой (SPEC §7).
struct DayDetailView: View {
    let date: Date
    @Environment(\.modelContext) private var context
    @Query private var logs: [FoodLog]
    @State private var editingLog: FoodLog?
    @State private var showPlan = false

    private let catalog = FoodCatalog.shared

    private var day: DaySummary {
        CalendarService(catalog: catalog, logs: logs).day(date)
    }

    /// Сегодня или будущее — можно запланировать ввод (п.21).
    private var isTodayOrFuture: Bool {
        Calendar.current.startOfDay(for: date) >= Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isTodayOrFuture {
                    BigButton(title: "Запланировать ввод") { showPlan = true }
                }
                if day.entries.isEmpty {
                    if !isTodayOrFuture { emptyState }
                } else {
                    ForEach(day.entries) { entryRow($0) }
                }
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle(date.formatted(.dateTime.day().month().year()))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingLog) { EditNoteSheet(log: $0) }
        .sheet(isPresented: $showPlan) { PlanFeedingSheet(date: date) }
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
                    if entry.planned {
                        StatusBadge(text: String(localized: "план"), color: Theme.lilac)
                    }
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
            if entry.planned {
                PillButton(title: "Выполнено") { markDone(entry.log) }
            } else if let liking = entry.liking {
                OpenMojiIcon(asset: "like_\(liking.rawValue)", fallback: liking.emoji, size: 30)
            }
        }
        .cartoonCard()
        .contentShape(Rectangle())
        .onTapGesture { editingLog = entry.log }
    }

    /// Отметить запланированный ввод выполненным — становится обычной записью журнала.
    private func markDone(_ log: FoodLog) {
        log.planned = false
        try? context.save()
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

/// Лист выбора продукта для планирования ввода на выбранный день (п.21).
private struct PlanFeedingSheet: View {
    let date: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private let catalog = FoodCatalog.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(catalog.search(search)) { food in
                    Button {
                        context.insert(FoodLog(foodId: food.id, date: date,
                                               type: .intro, planned: true))
                        try? context.save()
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            FoodIcon(food: food, size: 30)
                            Text(food.localizedName).foregroundStyle(.primary)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: Text("Поиск продукта"))
            .navigationTitle("Запланировать ввод")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            }
        }
    }
}
