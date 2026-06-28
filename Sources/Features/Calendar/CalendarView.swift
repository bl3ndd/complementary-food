import SwiftUI
import SwiftData

/// Экран «Календарь»: месячная сетка с подсветкой дней, в которые что-то давали
/// (SPEC §7). Активные дни залиты, дни с реакцией — красным, сегодня в рамке.
/// Тап по дню → детали дня.
struct CalendarView: View {
    @Query(sort: \FoodLog.date, order: .reverse) private var logs: [FoodLog]

    private let catalog = FoodCatalog.shared
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    /// Русские ключи; локализуются в каталоге (`String.LocalizationValue` ниже).
    private let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    @State private var monthAnchor = Date()

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2          // неделя с понедельника
        return c
    }

    /// Сводки по дням, ключ — начало дня.
    private var summaries: [Date: DaySummary] {
        Dictionary(uniqueKeysWithValues:
            CalendarService(catalog: catalog, logs: logs).days().map { ($0.date, $0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthCard
                    if logs.isEmpty { emptyHint }
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Календарь")
            .navigationDestination(for: Date.self) { date in
                DayDetailView(date: date)
            }
        }
    }

    // MARK: - Карточка месяца

    private var monthCard: some View {
        VStack(spacing: 14) {
            monthHeader
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdays, id: \.self) { d in
                    Text(String(localized: String.LocalizationValue(d)))
                        .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(monthCells().enumerated()), id: \.offset) { _, date in
                    if let date { dayCell(date) } else { Color.clear.frame(height: 40) }
                }
            }
            if !logs.isEmpty {
                Divider().padding(.top, 2)
                legend
            }
        }
        .cartoonCard()
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.headline).foregroundStyle(Theme.accent)
            }
            Spacer()
            Text(monthAnchor.formatted(.dateTime.month(.wide).year()).capitalized)
                .font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(canGoNext ? Theme.accent : Color.secondary.opacity(0.35))
            }
            .disabled(!canGoNext)
        }
    }

    // MARK: - Ячейка дня

    private func dayCell(_ date: Date) -> some View {
        let start = cal.startOfDay(for: date)
        let summary = summaries[start]
        let active = summary != nil
        let hasReaction = summary?.hasReaction ?? false
        let isToday = cal.isDateInToday(date)
        // «Есть записи» — холодный синий, «реакция» — красный: явно разные хюэ (п.6).
        let fill = hasReaction ? Color.red : Theme.sky

        return NavigationLink(value: start) {
            Text("\(cal.component(.day, from: date))")
                .font(.subheadline.weight(active ? .bold : .regular))
                .foregroundStyle(active ? .white : .primary)
                .frame(width: 40, height: 40)
                .background {
                    if active {
                        Circle().fill(LinearGradient(colors: [fill, fill.opacity(0.82)],
                                                     startPoint: .top, endPoint: .bottom))
                            .shadow(color: fill.opacity(0.35), radius: 5, y: 2)
                    } else if isToday {
                        Circle().fill(Color.black.opacity(0.04))
                    }
                }
                .overlay {
                    if isToday {
                        Circle().stroke(active ? .white.opacity(0.9) : Theme.accent, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 20) {
            legendDot(Theme.sky, "есть записи")
            legendDot(.red, "реакция")
        }
        .font(.caption).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    private func legendDot(_ color: Color, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(text)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Mascot(mood: .curious, size: 64)
            Text("Здесь будут отмечаться дни, в которые ты давал продукты.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Логика сетки

    /// Ячейки месяца: ведущие nil-паддинги до первого дня + дни месяца.
    private func monthCells() -> [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let first = interval.start
        let dayCount = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let weekday = cal.component(.weekday, from: first)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for d in 0..<dayCount {
            cells.append(cal.date(byAdding: .day, value: d, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: monthAnchor) {
            withAnimation(.snappy) { monthAnchor = d }
        }
    }

    /// Не пускаем в будущее дальше текущего месяца.
    private var canGoNext: Bool {
        cal.compare(monthAnchor, to: Date(), toGranularity: .month) == .orderedAscending
    }
}
