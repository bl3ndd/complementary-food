import SwiftUI
import SwiftData

/// Карточка продукта: герой + чипы-факты + действия + история (SPEC §7).
struct FoodDetailView: View {
    let food: Food
    let child: Child

    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var logs: [FoodLog]
    @State private var showLogSheet = false
    @State private var showCheer = false

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
    private var observationDays: Int { child.feedingProfile.observationDays }
    private var observationDay: Int? {
        introStartedAt.map { FeedingService.observationDay(start: $0) }
    }
    private var canComplete: Bool {
        guard let start = introStartedAt else { return false }
        return FeedingService.isObservationComplete(start: start, observationDays: observationDays)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                actionsCard
                if state == .allergy { allergyCard }
                if !logs.isEmpty { historyCard }
            }
            .padding()
        }
        .background(AppBackground())
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showLogSheet) {
            LogFeedingSheet(food: food, child: child)
        }
        .overlay {
            if showCheer { cheerOverlay }
        }
    }

    /// Кратковременное поздравление при успешном вводе продукта.
    private var cheerOverlay: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 14) {
                Mascot(mood: .cheer, size: 120)
                Text("Продукт введён! 🎉").font(.title3.bold())
            }
            .padding(28)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Theme.accentDeep.opacity(0.25), radius: 20, y: 10)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.85)))
    }

    // MARK: - Карточки

    private var heroCard: some View {
        VStack(spacing: 12) {
            FoodIcon(food: food, size: 88)
            Text(food.name).font(.title.bold())
            StatusBadge(text: state.title, color: state.color)
            HStack(spacing: 8) {
                Chip("с \(food.minAgeMonths) мес", icon: "calendar")
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
            BigButton(title: "Начать введение") { start() }
        case .introducing:
            if let day = observationDay { observationHint(day: day) }
            BigButton(title: "Записать кормление") { showLogSheet = true }
            if canComplete {
                BigButton(title: "Ввёл успешно ✅", tint: .green) { complete() }
            }
            BigButton(title: "Была реакция / аллергия 😟", tint: .red) { showLogSheet = true }
        case .introduced:
            BigButton(title: "Записать кормление") { showLogSheet = true }
            BigButton(title: "Появилась реакция / аллергия 😟", tint: .red) { showLogSheet = true }
        case .paused:
            BigButton(title: "Повторить ввод") { start() }
        case .allergy:
            BigButton(title: "Вернуть в оборот (врач разрешил)", tint: .red) {
                service.reintroduce(food); refresh()
            }
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
                     ? "Окно наблюдения прошло. Если реакции не было — отметь «ввёл успешно»."
                     : "Наблюдай за реакцией. Кнопка «ввёл успешно» появится после \(observationDays) дн.")
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
            HStack {
                Text("История").font(.headline)
                Spacer()
                Text("\(logs.count)").font(.subheadline.bold())
                    .foregroundStyle(Theme.accent)
            }
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
            return ("Заметка", "note.text", Theme.lilac)
        }
        if log.type == .maintenance { return ("Поддержка", "drop.fill", Theme.sky) }
        return ("Ввод", "leaf.fill", Theme.mint)
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
                    Text(log.date.formatted(.dateTime.day().month().hour().minute().locale(.ru)))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let note = log.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Действия

    private func start() {
        Task {
            if food.isAllergen { _ = await NotificationManager.shared.requestAuthorization() }
            service.startIntroduction(food)
            refresh()
        }
    }

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
