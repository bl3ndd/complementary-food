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
            BigButton(title: "Записать кормление") { showLogSheet = true }
            BigButton(title: "Ввёл успешно ✅", tint: .green) { complete() }
        case .introduced:
            BigButton(title: "Записать кормление") { showLogSheet = true }
        case .paused:
            BigButton(title: "Повторить ввод") { start() }
        case .allergy:
            BigButton(title: "Вернуть в оборот (врач разрешил)", tint: .red) {
                service.reintroduce(food); refresh()
            }
        }
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
        VStack(alignment: .leading, spacing: 12) {
            Text("История").font(.headline)
            ForEach(logs) { log in
                HStack {
                    Text(log.date.shortDate).font(.subheadline)
                    if let liking = log.liking { Text(liking.emoji) }
                    Spacer()
                    if let reaction = log.reaction, reaction != .none {
                        StatusBadge(text: reaction.title, color: .red)
                    } else {
                        Text(log.type == .maintenance ? "поддержка" : "ввод")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .cartoonCard()
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
    }

    private func refresh() {
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
    }
}
