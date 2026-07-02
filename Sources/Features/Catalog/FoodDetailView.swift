import SwiftUI
import SwiftData

/// Карточка продукта (гибрид): адаптивный герой (кольцо окна наблюдения / печать
/// статуса + сводка) → факты в аккордеоне → история; главное действие — в закреплённом
/// баре снизу, вторичные/деструктивные — в меню «…» (SPEC §7). Чистый дневник.
struct FoodDetailView: View {
    let food: Food
    let child: Child

    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var logs: [FoodLog]
    @State private var logMode: LogFeedingSheet.Mode?
    @State private var showCheer = false
    @State private var startDate = Date()
    @State private var editingLog: FoodLog?
    @State private var confirmStop = false
    @State private var confirmAllergy = false
    @State private var benefitsExpanded = false

    init(food: Food, child: Child) {
        self.food = food
        self.child = child
        let fid = food.id
        _statuses = Query(filter: #Predicate { $0.foodId == fid })
        _logs = Query(filter: #Predicate { $0.foodId == fid && !$0.planned },
                      sort: \FoodLog.date, order: .reverse)
    }

    private var state: IntroState { statuses.first?.state ?? .notIntroduced }
    private var service: FeedingService { FeedingService(context: context) }

    private var introStartedAt: Date? { statuses.first?.introStartedAt }
    private var observationDays: Int { child.feedingProfile.observationDays(for: food) }
    private var windowStart: Date? {
        FeedingService.windowStart(introStartedAt: introStartedAt,
                                   introLogDates: logs.filter { $0.type == .intro }.map(\.date))
    }
    private var observationDay: Int? {
        windowStart.map { FeedingService.observationDay(start: $0) }
    }
    private var canComplete: Bool {
        guard let start = windowStart else { return false }
        return FeedingService.isObservationComplete(start: start, observationDays: observationDays)
    }
    private var windowFraction: CGFloat {
        guard observationDays > 0, let day = observationDay else { return 0 }
        return min(1, max(0, CGFloat(day) / CGFloat(observationDays)))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                if state == .notIntroduced { startDateCard }
                if state == .allergy { allergyCard }
                benefitsCard
                if !logs.isEmpty { historyCard }
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle(food.localizedName)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) { stickyBar }
        .sheet(item: $logMode) { mode in
            LogFeedingSheet(food: food, child: child, mode: mode)
        }
        .sheet(item: $editingLog) { EditLogSheet(log: $0) }
        .alert("Приостановить ввод этого продукта?", isPresented: $confirmStop) {
            Button("Приостановить", role: .destructive) { stop() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это не аллергия — просто пауза, ввод можно возобновить в любой момент.")
        }
        .alert("Пометить аллергию?", isPresented: $confirmAllergy) {
            Button("Пометить аллергию", role: .destructive) { flagAllergy() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Напоминания по этому аллергену отключатся.")
        }
        .overlay { cheerOverlay }
    }

    // MARK: - Герой (адаптивный)

    private var heroCard: some View {
        HStack(spacing: 16) {
            iconWithStatus
            VStack(alignment: .leading, spacing: 6) {
                Text(state.title)
                    .font(.headline).foregroundStyle(state.color)
                subStatus
                chipsRow
            }
            Spacer(minLength: 0)
        }
        .cartoonCard(padding: 14)
    }

    private var chipsRow: some View {
        FlowLayout(spacing: 8) {
            Chip(food.category.title, icon: "square.grid.2x2",
                 color: Theme.categoryColor(food.category)).fixedSize()
            if let group = food.allergenGroup {
                Chip(group.title, icon: "exclamationmark.triangle.fill", color: .orange).fixedSize()
            }
        }
    }

    /// Иконка (круглая — под кольцо/печать) + индикатор статуса: кольцо окна
    /// наблюдения (вводится) ИЛИ печать статуса на иконке (введён/пауза/аллергия).
    private var iconWithStatus: some View {
        ZStack {
            if state == .introducing {
                Circle().stroke(Theme.sky.opacity(0.16), lineWidth: 5)
                    .frame(width: 78, height: 78)
                Circle().trim(from: 0, to: windowFraction)
                    .stroke(canComplete ? Theme.mint : Theme.sky,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 78, height: 78)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: windowFraction)
            }
            FoodIcon(food: food, size: 60, circular: true)
                .overlay(alignment: .bottomTrailing) {
                    if state != .notIntroduced, state != .introducing {
                        ZStack {
                            Circle().fill(.white).frame(width: 26, height: 26)
                                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                            OpenMojiIcon(asset: stateAsset, fallback: stateEmoji, size: 19)
                        }
                        .offset(x: 3, y: 3)
                    }
                }
        }
        .frame(width: 80, height: 80)
    }

    /// Вторая строка героя: прогресс окна / сводка по введённому / инфо о паузе.
    @ViewBuilder private var subStatus: some View {
        switch state {
        case .introducing:
            if let day = observationDay {
                Text("День \(min(day, observationDays)) из \(observationDays)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
        case .introduced:
            summaryLine
        case .paused:
            if let retry = statuses.first?.retryAt {
                Text("Напомним попробовать снова \(retry.shortDate)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        default:
            EmptyView()
        }
    }

    /// Сводка по введённому продукту: сколько кормлений, последнее, что чаще нравится.
    private var summaryLine: some View {
        HStack(spacing: 6) {
            Text("\(String(localized: "Кормлений")): \(logs.count)")
            if let last = logs.first?.date {
                Text("· \(String(localized: "последнее")) \(last.shortDate)")
            }
            if let liking = dominantLiking {
                OpenMojiIcon(asset: "like_\(liking.rawValue)", fallback: liking.emoji, size: 18)
            }
        }
        .font(.caption).foregroundStyle(.secondary)
    }

    private var dominantLiking: Liking? {
        let likings = logs.compactMap(\.liking)
        guard !likings.isEmpty else { return nil }
        return Dictionary(grouping: likings, by: { $0 })
            .mapValues(\.count).max { $0.value < $1.value }?.key
    }

    private var stateEmoji: String {
        switch state {
        case .notIntroduced: return ""
        case .introducing:   return "🌱"
        case .introduced:    return "✅"
        case .paused:        return "⏸️"
        case .allergy:       return "⚠️"
        }
    }

    private var stateAsset: String {
        switch state {
        case .notIntroduced: return ""
        case .introducing:   return "ui_seedling"
        case .introduced:    return "ui_check"
        case .paused:        return "ui_pause"
        case .allergy:       return "ui_warning"
        }
    }

    // MARK: - Дата старта (только «не введён»)

    private var startDateCard: some View {
        DatePicker(selection: $startDate, in: ...Date(), displayedComponents: .date) {
            Label("Дата старта", systemImage: "calendar").font(.subheadline)
        }
        .tint(Theme.accent)
        .cartoonCard()
    }

    // MARK: - Чем полезен (аккордеон)

    @ViewBuilder private var benefitsCard: some View {
        if food.localizedBenefits != nil || (food.nutrients?.isEmpty == false) {
            DisclosureGroup(isExpanded: $benefitsExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    if let benefits = food.localizedBenefits {
                        Text(benefits).font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let nutrients = food.nutrients, !nutrients.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(nutrients, id: \.self) { n in
                                Chip(String(localized: String.LocalizationValue(n)),
                                     icon: "leaf.fill", color: Theme.mint)
                                    .fixedSize()
                            }
                        }
                    }
                }
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Чем полезен", systemImage: "sparkles").font(.headline)
            }
            .tint(Theme.accent)
            .cartoonCard()
        }
    }

    // MARK: - Аллергия

    private var allergyCard: some View {
        HStack(spacing: 12) {
            OpenMojiIcon(asset: "ui_warning", fallback: "⚠️", size: 28)
            Text("Зафиксирована аллергия. Возвращать продукт — только по согласованию с врачом.")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartoonCard()
    }

    // MARK: - История

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("История").font(.headline)
            VStack(spacing: 0) {
                ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                    if index > 0 { Divider().padding(.leading, 50) }
                    historyRow(log)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartoonCard()
    }

    private func entryKind(_ log: FoodLog) -> (label: String, icon: String, color: Color) {
        if log.note != nil && log.liking == nil && (log.reaction == nil || log.reaction == ReactionType.none) {
            return (String(localized: "Заметка"), "note.text", Theme.lilac)
        }
        return (String(localized: "Кормление"), "fork.knife", Theme.mint)
    }

    private func historyRow(_ log: FoodLog) -> some View {
        let kind = entryKind(log)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.softGradient(kind.color))
                Image(systemName: kind.icon).font(.subheadline).foregroundStyle(kind.color)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(kind.label).font(.subheadline.weight(.semibold))
                    if let reaction = log.reaction, reaction != .none {
                        StatusBadge(text: reaction.title, color: .red)
                    }
                    Spacer(minLength: 0)
                    if let liking = log.liking {
                        OpenMojiIcon(asset: "like_\(liking.rawValue)",
                                     fallback: liking.emoji, size: 22)
                    }
                    Text(log.date.formatted(.dateTime.day().month().hour().minute()))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let note = log.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { editingLog = log }
    }

    // MARK: - Закреплённый бар действий

    private struct BarAction: Identifiable {
        let id = UUID()
        let title: LocalizedStringKey
        var role: ButtonRole? = nil
        var tint: Color? = nil
        let run: () -> Void
    }

    private var primaryAction: BarAction {
        switch state {
        case .notIntroduced:
            return BarAction(title: "Начать введение") { start(date: startDate) }
        case .introducing:
            return canComplete
                ? BarAction(title: "Ввёл успешно ✅", tint: .green) { complete() }
                : BarAction(title: "Записать кормление") { logMode = .feeding }
        case .introduced:
            return BarAction(title: "Записать кормление") { logMode = .feeding }
        case .paused:
            return BarAction(title: "Возобновить ввод") { resume() }
        case .allergy:
            return BarAction(title: "Вернуть в оборот (врач разрешил)", tint: .red) {
                service.reintroduce(food); refresh()
            }
        }
    }

    private var overflowActions: [BarAction] {
        switch state {
        case .notIntroduced:
            return []
        case .introducing:
            var items: [BarAction] = []
            if canComplete {
                items.append(BarAction(title: "Записать кормление") { logMode = .feeding })
            }
            items.append(BarAction(title: "Была реакция") { logMode = .reaction })
            items.append(BarAction(title: "Приостановить ввод", role: .destructive) { confirmStop = true })
            return items
        case .introduced:
            return [
                BarAction(title: "Была реакция") { logMode = .reaction },
                BarAction(title: "Пометить аллергию", role: .destructive) { confirmAllergy = true },
            ]
        case .paused:
            return [BarAction(title: "Попробовать через 2 месяца") { retryLater() }]
        case .allergy:
            return []
        }
    }

    private var stickyBar: some View {
        HStack(spacing: 12) {
            BigButton(title: primaryAction.title, tint: primaryAction.tint) { primaryAction.run() }
            if !overflowActions.isEmpty {
                Menu {
                    ForEach(overflowActions) { a in
                        Button(role: a.role) { a.run() } label: { Text(a.title) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.bold)).foregroundStyle(Theme.accent)
                        .frame(width: 54, height: 54)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
                }
            }
        }
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 6)
        .background(
            LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.9)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Поздравление

    private var cheerOverlay: some View {
        ZStack {
            if showCheer {
                Color.black.opacity(0.15).ignoresSafeArea()
                    .transition(.opacity)
                VStack(spacing: 14) {
                    Mascot(mood: .cheer, size: 120)
                    Text("Продукт введён! 🎉").font(.title3.bold())
                }
                .padding(28)
                .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: Theme.accentDeep.opacity(0.25), radius: 20, y: 10)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Действия

    private func start(date: Date = Date()) {
        service.startIntroduction(food, date: date)
        refresh()
    }

    private func stop() { service.stopIntroduction(food); refresh() }
    private func resume() { service.reintroduce(food); refresh() }
    private func retryLater() { service.scheduleRetry(food); refresh() }
    private func flagAllergy() { service.markAllergy(food); refresh() }

    private func complete() {
        service.completeIntroduction(food)
        refresh()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showCheer = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showCheer = false }
        }
    }

    private func refresh() {
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
    }
}
