import SwiftUI
import SwiftData

/// Экран «Дневник» (Concept A): основной вид — хронологическая лента записей
/// (фильтр-линза + поиск), сетка-месяц вторична как навигатор/планировщик
/// (SPEC §7). Лента отвечает на «что было», сетка — на «когда».
struct CalendarView: View {
    @Query(sort: \FoodLog.date, order: .reverse) private var logs: [FoodLog]
    @Query private var children: [Child]
    @Query private var statuses: [IntroductionStatus]
    @Environment(\.modelContext) private var context

    private let catalog = FoodCatalog.shared
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    /// Русские ключи; локализуются в каталоге (`String.LocalizationValue` ниже).
    private let weekdays = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    private enum Mode: Hashable { case feed, month }
    @State private var mode: Mode = .feed
    @State private var filter: DiaryFilter = .all
    @State private var search = ""
    @State private var monthAnchor = Date()
    @State private var editingLog: FoodLog?
    @State private var showPlan = false
    @State private var shareFile: ShareableFile?
    @State private var pendingDelete: FoodLog?

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2          // неделя с понедельника
        return c
    }

    private var service: CalendarService {
        CalendarService(catalog: catalog, logs: logs)
    }

    /// Поиск принудительно показывает ленту (искать в сетке бессмысленно).
    private var showFeed: Bool { mode == .feed || !search.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    modeSegment
                    if showFeed {
                        feedSection
                    } else {
                        monthCard
                        if logs.isEmpty { emptyHint }
                    }
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Дневник")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: Text("Поиск по дневнику"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button { exportPDF(.pediatric) } label: {
                            Label("Дневник для педиатра", systemImage: "doc.text")
                        }
                        Button { exportPDF(.avoid) } label: {
                            Label("Лист «Не давать» (няне/садику)", systemImage: "nosign")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Экспорт")
                    .disabled(logs.isEmpty || children.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showPlan = true } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .accessibilityLabel("Запланировать ввод")
                }
            }
            .navigationDestination(for: Date.self) { date in
                DayDetailView(date: date)
            }
            .sheet(item: $editingLog) { EditLogSheet(log: $0) }
            .sheet(isPresented: $showPlan) { PlanIntroSheet() }
            .sheet(item: $shareFile) { ActivityView(items: [$0.url]) }
            .alert(Text("Удалить запись?"),
                   isPresented: Binding(get: { pendingDelete != nil },
                                        set: { if !$0 { pendingDelete = nil } })) {
                Button("Удалить", role: .destructive) {
                    if let log = pendingDelete { delete(log) }
                }
                Button("Отмена", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("Действие нельзя отменить.")
            }
        }
    }

    // MARK: - Переключатель Лента / Месяц

    private var modeSegment: some View {
        HStack(spacing: 4) {
            segmentButton("Лента", .feed)
            segmentButton("Месяц", .month)
        }
        .padding(4)
        .background(Color.black.opacity(0.05), in: Capsule())
    }

    private func segmentButton(_ title: LocalizedStringKey, _ value: Mode) -> some View {
        let active = mode == value && search.isEmpty
        return Button {
            withAnimation(.snappy) { mode = value; search = "" }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(active ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    if active { Capsule().fill(Theme.accentGradient) }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Лента-дневник

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            filterChips
            let feed = service.feed(filter: filter, query: search)
            if feed.isEmpty {
                feedEmpty
            } else {
                let today = cal.startOfDay(for: Date())
                let future = feed.filter { $0.date > today }
                let past = feed.filter { $0.date <= today }
                if !future.isEmpty {
                    sectionLabel("Планы")
                    ForEach(future) { dayGroup($0) }
                }
                ForEach(past) { dayGroup($0) }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiaryFilter.allCases) { f in
                    let active = filter == f
                    Button {
                        withAnimation(.snappy) { filter = f }
                    } label: {
                        Text(f.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .background(active ? Theme.accent.opacity(0.16) : Color.black.opacity(0.05),
                                        in: Capsule())
                            .overlay(Capsule().stroke(active ? Theme.accent.opacity(0.45) : .clear,
                                                      lineWidth: 1.5))
                            .foregroundStyle(active ? Theme.accent : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func dayGroup(_ day: DaySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayHeader(day.date))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            ForEach(day.entries) { entry in
                DiaryEntryRow(entry: entry,
                              showDone: entry.planned && day.date <= cal.startOfDay(for: Date()),
                              onDone: { markDone(entry.log) })
                    .onTapGesture { editingLog = entry.log }
                    .contextMenu {
                        Button { editingLog = entry.log } label: {
                            Label("Изменить", systemImage: "pencil")
                        }
                        Button(role: .destructive) { pendingDelete = entry.log } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .foregroundStyle(Theme.lilac)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }

    /// «Сегодня, 30 июн» / «Вчера, 29 июн» / «ср, 27 июн».
    private func dayHeader(_ date: Date) -> String {
        let short = date.formatted(.dateTime.day().month())
        if cal.isDateInToday(date) { return "\(String(localized: "Сегодня")), \(short)" }
        if cal.isDateInYesterday(date) { return "\(String(localized: "Вчера")), \(short)" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month()).capitalized
    }

    private var feedEmpty: some View {
        VStack(spacing: 10) {
            Mascot(mood: search.isEmpty ? .curious : .sleepy, size: 64)
            Text(search.isEmpty
                 ? "Здесь будет история кормлений. Записывай продукты — и дневник наполнится."
                 : "Ничего не нашлось")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    // MARK: - Карточка месяца (навигатор)

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
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -40 { if canGoNext { shiftMonth(1) } }
                    else if value.translation.width > 40 { shiftMonth(-1) }
                }
        )
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.headline).foregroundStyle(Theme.accent)
            }
            .accessibilityLabel("Предыдущий месяц")
            Spacer()
            VStack(spacing: 2) {
                Text(monthAnchor.formatted(.dateTime.month(.wide).year()).capitalized)
                    .font(.headline)
                if !cal.isDate(monthAnchor, equalTo: Date(), toGranularity: .month) {
                    Button("К сегодня") {
                        withAnimation(.snappy) { monthAnchor = Date() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                }
            }
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(canGoNext ? Theme.accent : Color.secondary.opacity(0.35))
            }
            .accessibilityLabel("Следующий месяц")
            .disabled(!canGoNext)
        }
    }

    /// Сводки по дням, ключ — начало дня (для подсветки сетки; фильтр не применяем —
    /// сетка показывает всю активность как карта покрытия).
    private var summaries: [Date: DaySummary] {
        Dictionary(uniqueKeysWithValues: service.days().map { ($0.date, $0) })
    }

    private func dayCell(_ date: Date) -> some View {
        let start = cal.startOfDay(for: date)
        let summary = summaries[start]
        let active = summary != nil
        let hasReaction = summary?.hasReaction ?? false
        let isToday = cal.isDateInToday(date)
        let plannedOnly = summary?.isPlannedOnly ?? false
        // Смешанный день: есть и факт, и план — чтобы не терять сиреневый сигнал (P3).
        let mixed = (summary?.hasPlanned ?? false) && !plannedOnly
        let entryCount = summary?.entries.count ?? 0
        // «Есть записи» — синий, «реакция» — красный, «план» — сиреневый: разные хюэ (п.6/21).
        let fill = hasReaction ? Color.red : (plannedOnly ? Theme.lilac : Theme.sky)
        // Статус не только цветом — дублируем в VoiceOver (доступность).
        let statusText = hasReaction ? String(localized: "была реакция")
            : plannedOnly ? String(localized: "запланировано")
            : active ? String(localized: "есть записи")
            : String(localized: "нет записей")

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
                    // Смешанный день — тонкое сиреневое кольцо «ещё и план».
                    if mixed { Circle().stroke(Theme.lilac, lineWidth: 2).padding(1.5) }
                }
                .overlay {
                    if isToday {
                        Circle().stroke(active ? .white.opacity(0.9) : Theme.accent, lineWidth: 2)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    // Счётчик записей на «густых» днях.
                    if entryCount >= 2 {
                        Text("\(entryCount)")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(fill)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(.white).shadow(radius: 1))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(cal.component(.day, from: date)) — \(statusText)"))
    }

    private var legend: some View {
        HStack(spacing: 18) {
            legendDot(Theme.sky, "есть записи")
            legendDot(.red, "реакция")
            legendDot(Theme.lilac, "план")
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
            Text("Тапни день, чтобы запланировать ввод или посмотреть записи.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Действия / логика сетки

    private func markDone(_ log: FoodLog) {
        FeedingService(context: context).confirmPlanned(log)
        if let profile = children.first?.feedingProfile {
            NotificationManager.shared.refresh(context: context, profile: profile)
        }
    }

    private func delete(_ log: FoodLog) {
        context.delete(log)
        try? context.save()
        pendingDelete = nil
    }

    private enum ExportKind { case pediatric, avoid }

    /// Сформировать PDF и открыть системный share sheet. Дневник «для педиатра»
    /// включает статус поддержки аллергенов; лист «не давать» — паузы/аллергии.
    private func exportPDF(_ kind: ExportKind) {
        guard let child = children.first else { return }
        let allergens = AllergenMaintenance(catalog: catalog, profile: child.feedingProfile,
                                            statuses: statuses, logs: logs).groups()
        let export = DiaryPDFExport(childName: child.name, ageMonths: child.ageInMonths,
                                    catalog: catalog, logs: logs, allergens: allergens,
                                    statuses: statuses)
        let url = kind == .pediatric ? export.writeTempFile() : export.writeAvoidTempFile()
        if let url { shareFile = ShareableFile(url: url) }
    }

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

    /// Можно листать в будущее (до +6 месяцев) — чтобы планировать ввод (п.21).
    private var canGoNext: Bool {
        guard let maxMonth = cal.date(byAdding: .month, value: 6, to: Date()) else { return false }
        return cal.compare(monthAnchor, to: maxMonth, toGranularity: .month) == .orderedAscending
    }
}
