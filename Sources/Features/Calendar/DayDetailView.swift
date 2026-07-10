import SwiftUI
import SwiftData

/// Детали одного дня: список продуктов с типом (ввод/поддержка), реакцией и
/// вкусовой оценкой (SPEC §7).
struct DayDetailView: View {
    let date: Date
    @Environment(\.modelContext) private var context
    @Query private var logs: [FoodLog]
    @Query private var children: [Child]
    @State private var editingLog: FoodLog?
    @State private var showPlan = false
    @State private var showAddFeeding = false

    private let catalog = FoodCatalog.shared

    private var day: DaySummary {
        CalendarService(catalog: catalog, logs: logs).day(date)
    }

    /// Сегодня или будущее — можно запланировать ввод (п.21).
    private var isTodayOrFuture: Bool {
        Calendar.current.startOfDay(for: date) >= Calendar.current.startOfDay(for: Date())
    }

    /// Строго будущий день — «Выполнено» прятать (нельзя «дать» в будущем).
    private var isFutureDay: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isTodayOrFuture {
                    BigButton(title: "Запланировать ввод") { showPlan = true }
                }
                // За сегодня/прошлый день можно дописать кормление (ретро-запись).
                if !isFutureDay {
                    GhostButton(title: "Записать кормление") { showAddFeeding = true }
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
        .sheet(item: $editingLog) { EditLogSheet(log: $0) }
        .sheet(isPresented: $showPlan) { PlanIntroSheet(initialDate: date) }
        .sheet(isPresented: $showAddFeeding) {
            if let child = children.first {
                QuickLogSheet(child: child, initialDate: date)
            }
        }
    }

    private func entryRow(_ entry: DayEntry) -> some View {
        DiaryEntryRow(entry: entry,
                      showDone: entry.planned && !isFutureDay,
                      onDone: { markDone(entry.log) })
            .onTapGesture { editingLog = entry.log }
    }

    /// Отметить запланированный ввод выполненным — запускает стейт-машину (introducing)
    /// и переставляет напоминания (B1).
    private func markDone(_ log: FoodLog) {
        Haptics.success()
        FeedingService(context: context).confirmPlanned(log)
        if let profile = children.first?.feedingProfile {
            NotificationManager.shared.refresh(context: context, profile: profile)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Mascot(mood: .sleepy).gentleBob()
            Text("В этот день ничего не давали").font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

