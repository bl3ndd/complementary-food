import SwiftUI
import SwiftData

/// Карточка продукта: герой + чипы-факты + действия + история (SPEC §7).
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

    init(food: Food, child: Child) {
        self.food = food
        self.child = child
        let fid = food.id
        _statuses = Query(filter: #Predicate { $0.foodId == fid })
        _logs = Query(filter: #Predicate { $0.foodId == fid },
                      sort: \FoodLog.date, order: .reverse)
    }

    private var state: IntroState { statuses.first?.state ?? .notIntroduced }
    private var service: FeedingService { FeedingService(context: context) }

    private var introStartedAt: Date? { statuses.first?.introStartedAt }
    private var observationDays: Int { child.feedingProfile.observationDays(for: food) }
    /// Начало окна = самая ранняя из отметки старта и intro-логов (учитывает бэкдейт).
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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                actionsCard
                if state == .allergy { allergyCard }
                benefitsCard
                if !logs.isEmpty { historyCard }
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle(food.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $logMode) { mode in
            LogFeedingSheet(food: food, child: child, mode: mode)
        }
        .sheet(item: $editingLog) { EditLogSheet(log: $0) }
        .alert("Приостановить ввод этого продукта?", isPresented: $confirmStop) {
            Button("Приостановить", role: .destructive) { stop() }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Пометить аллергию?", isPresented: $confirmAllergy) {
            Button("Пометить аллергию", role: .destructive) { flagAllergy() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Напоминания по этому аллергену отключатся.")
        }
        .overlay { cheerOverlay }
    }

    /// Кратковременное поздравление при успешном вводе продукта. Фон-затемнение
    /// только проявляется (opacity), а карточка ещё и масштабируется — иначе фон
    /// «летал» вместе с Puddingом (общий scale-транзишен на всём ZStack).
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

    // MARK: - Карточки

    private var heroCard: some View {
        VStack(spacing: 12) {
            FoodIcon(food: food, size: 88)
            Text(food.localizedName).font(.title.bold())
            StatusBadge(text: state.title, color: state.color)
            HStack(spacing: 8) {
                Chip(food.category.title, icon: "square.grid.2x2",
                     color: Theme.categoryColor(food.category))
                if let group = food.allergenGroup {
                    Chip(group.title, icon: "exclamationmark.triangle.fill", color: .orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .cartoonCard()
    }

    private var actionsCard: some View {
        VStack(spacing: 10) { actionButtons }
            .cartoonCard()
    }

    @ViewBuilder private var actionButtons: some View {
        switch state {
        case .notIntroduced:
            DatePicker(selection: $startDate, in: ...Date(), displayedComponents: .date) {
                Label("Дата старта", systemImage: "calendar")
            }
            .font(.subheadline)
            BigButton(title: "Начать введение") { start(date: startDate) }
        case .introducing:
            if let day = observationDay { observationHint(day: day) }
            BigButton(title: "Записать кормление") { logMode = .feeding }
            if canComplete {
                BigButton(title: "Ввёл успешно ✅", tint: .green) { complete() }
            }
            GhostButton(title: "Была реакция", tint: .red) { logMode = .reaction }
            GhostButton(title: "Приостановить ввод", tint: .gray) { confirmStop = true }
        case .introduced:
            BigButton(title: "Записать кормление") { logMode = .feeding }
            GhostButton(title: "Появилась реакция", tint: .red) { logMode = .reaction }
            GhostButton(title: "Пометить аллергию", tint: .gray) { confirmAllergy = true }
        case .paused:
            if let retry = statuses.first?.retryAt {
                Text("Напомним попробовать снова \(retry.shortDate)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            BigButton(title: "Возобновить ввод") { resume() }
            GhostButton(title: "Попробовать через 2 месяца", tint: .gray) { retryLater() }
        case .allergy:
            BigButton(title: "Вернуть в оборот (врач разрешил)", tint: .red) {
                service.reintroduce(food); refresh()
            }
        }
    }

    /// Чем полезен продукт и какие нутриенты содержит (п.12).
    @ViewBuilder private var benefitsCard: some View {
        if food.localizedBenefits != nil || (food.nutrients?.isEmpty == false) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Чем полезен", systemImage: "sparkles").font(.headline)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartoonCard()
        }
    }

    /// Прогресс окна наблюдения — пока оно идёт, продукт ещё НЕ введён.
    private func observationHint(day: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.fill").font(.title3).foregroundStyle(Theme.sky)
            VStack(alignment: .leading, spacing: 2) {
                Text("День \(min(day, observationDays)) из \(observationDays)")
                    .font(.subheadline.bold())
                Text(canComplete
                     ? String(localized: "Окно наблюдения прошло. Если реакции не было — отметь «ввёл успешно».")
                     : String(localized: "Наблюдай за реакцией. Кнопка «ввёл успешно» появится после \(observationDays) дн."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }

    private var allergyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.title2).foregroundStyle(.red)
            Text("Зафиксирована аллергия. Обратись к педиатру. Возвращать продукт — только по согласованию с врачом.")
                .font(.subheadline)
        }
        .cartoonCard()
    }

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
        .cartoonCard()
    }

    /// Описание записи журнала: тип, иконка, цвет.
    private func entryKind(_ log: FoodLog) -> (label: String, icon: String, color: Color) {
        if log.note != nil && log.liking == nil && (log.reaction == nil || log.reaction == ReactionType.none) {
            return (String(localized: "Заметка"), "note.text", Theme.lilac)
        }
        // Чистый дневник: любая запись — «Кормление» (без методики ввод/поддержка).
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
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { editingLog = log }
    }

    // MARK: - Действия

    private func start(date: Date = Date()) {
        service.startIntroduction(food, date: date)
        refresh()   // refresh сам запросит разрешение на уведомления при первом планировании.
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
