import SwiftUI
import SwiftData

/// Экран «Календарь»: лента дней, в которые что-то давали (SPEC §7).
/// Дни с активностью показывают сводку ввод/поддержка; тап → детали дня.
struct CalendarView: View {
    let child: Child
    @Query(sort: \FoodLog.date, order: .reverse) private var logs: [FoodLog]

    private let catalog = FoodCatalog.shared

    private var days: [DaySummary] {
        CalendarService(catalog: catalog, logs: logs).days()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if days.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(days) { dayCard($0) }
                    }
                    .padding()
                }
            }
            .background(AppBackground())
            .navigationTitle("Календарь")
            .navigationDestination(for: Date.self) { date in
                DayDetailView(date: date)
            }
        }
    }

    private func dayCard(_ day: DaySummary) -> some View {
        NavigationLink(value: day.date) {
            HStack(spacing: 14) {
                dateBadge(day.date)
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.date.formatted(.dateTime.weekday(.wide)).capitalized)
                        .font(.headline).foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        if day.introCount > 0 {
                            Chip("\(day.introCount) ввод", icon: "leaf.fill",
                                 color: Theme.accent)
                        }
                        if day.maintenanceCount > 0 {
                            Chip("\(day.maintenanceCount) поддержка", icon: "drop.fill",
                                 color: .blue)
                        }
                        if day.hasReaction {
                            Chip("реакция", icon: "exclamationmark.triangle.fill",
                                 color: .red)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .cartoonCard()
        }
        .buttonStyle(.plain)
    }

    private func dateBadge(_ date: Date) -> some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.day())).font(.title2.bold())
            Text(date.formatted(.dateTime.month(.abbreviated)))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 46, height: 46)
        .background(Theme.accent.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("📅").font(.system(size: 64))
            Text("Пока пусто").font(.title3.bold())
            Text("Здесь появятся дни, в которые ты давал продукты.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}
