import SwiftUI
import SwiftData

/// Экран «Сегодня»: что в окне наблюдения + какие аллергены пора дать (SPEC §7).
struct DashboardView: View {
    let child: Child
    var goToCatalog: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var logs: [FoodLog]
    @State private var editingLog: FoodLog?
    @State private var showPlan = false

    private let catalog = FoodCatalog.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    todaySection
                    if !dueGroups.isEmpty {
                        section(title: "По плану: освежить", icon: "ui_bell") {
                            ForEach(dueGroups) { dueRow($0) }
                        }
                    }
                    if !introducing.isEmpty {
                        section(title: "В процессе ввода", icon: "ui_seedling") {
                            ForEach(introducing, id: \.status.foodId) { introRow($0) }
                        }
                    }
                    if !pausedItems.isEmpty {
                        section(title: "Отложенные продукты", icon: "ui_seedling") {
                            ForEach(pausedItems, id: \.status.foodId) { pausedRow($0) }
                        }
                    }
                    if dueGroups.isEmpty && introducing.isEmpty && pausedItems.isEmpty
                        && today.entries.isEmpty && introducedCount == 0 {
                        emptyState
                    }
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Сегодня")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Food.self) { food in
                FoodDetailView(food: food, child: child)
            }
            .sheet(item: $editingLog) { EditLogSheet(log: $0) }
            .sheet(isPresented: $showPlan) {
                PlanIntroSheet(initialDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
            }
        }
    }

    // MARK: - Блок «Сегодня» (дневник на главной)

    private var today: DaySummary {
        CalendarService(catalog: catalog, logs: logs).day(Date())
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Сегодня").font(.title3.bold())
                Spacer()
                Button { showPlan = true } label: {
                    Label("Запланировать", systemImage: "calendar.badge.plus")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                }
            }
            if today.entries.isEmpty {
                Text("Сегодня пока ничего не записано")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cartoonCard()
            } else {
                ForEach(today.entries) { todayRow($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todayRow(_ entry: DayEntry) -> some View {
        HStack(spacing: 12) {
            if let food = entry.food { FoodIcon(food: food) }
            else { EmojiAvatar(emoji: "🍽️", asset: "ui_plate") }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.food?.localizedName ?? entry.foodName).font(.headline)
                HStack(spacing: 6) {
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.caption).foregroundStyle(.secondary)
                    if entry.planned {
                        StatusBadge(text: String(localized: "план"), color: Theme.lilac)
                    }
                    if let r = entry.reaction, r != .none {
                        StatusBadge(text: r.title, color: .red)
                    }
                }
            }
            Spacer()
            if !entry.planned, let liking = entry.liking {
                OpenMojiIcon(asset: "like_\(liking.rawValue)", fallback: liking.emoji, size: 28)
            }
        }
        .cartoonCard()
        .contentShape(Rectangle())
        .onTapGesture { editingLog = entry.log }
    }

    // MARK: - Секции

    @ViewBuilder
    private func section<Content: View>(title: LocalizedStringKey, icon: String? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon { OpenMojiIcon(asset: icon, fallback: "", size: 24) }
                Text(title).font(.title3.bold())
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dueRow(_ group: AllergenGroupStatus) -> some View {
        HStack(spacing: 12) {
            if let rep = group.representativeFood {
                FoodIcon(food: rep)
            } else {
                EmojiAvatar(emoji: "⚠️", asset: "ui_warning", color: group.status.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(group.group.title).font(.headline)
                if let due = group.nextDue {
                    Text("к \(due.shortDate)").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            PillButton(title: "Дал") { give(group) }
        }
        .cartoonCard()
    }

    private func introRow(_ item: (food: Food, status: IntroductionStatus)) -> some View {
        NavigationLink(value: item.food) {
            HStack(spacing: 12) {
                FoodIcon(food: item.food)
                Text(item.food.localizedName).font(.headline).foregroundStyle(.primary)
                Spacer()
                Text(dayInfo(item.status))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(Theme.accent)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .cartoonCard()
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Mascot(mood: .happy)
            Text("Всё под контролем!").font(.title3.bold())
            Text("Загляни в каталог и выбери первый продукт.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            BigButton(title: "Добавить продукт") { goToCatalog() }
                .padding(.horizontal, 40)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: - Данные

    private var introducedCount: Int {
        statuses.filter { $0.state == .introduced }.count
    }

    private var heroCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.25)).frame(width: 64, height: 64)
                Mascot(mood: MascotMood.forProgress(introduced: introducedCount,
                                                    total: catalog.foods.count),
                       size: 50)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(child.name.isEmpty ? String(localized: "Малыш") : child.name)
                    .font(.title2.bold()).foregroundStyle(.white)
                Text("\(child.ageInMonths) мес").font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                Text(String(localized: "\(introducedCount) продуктов введено"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.95))
            }
            Spacer()
            ProgressRingOnColor(value: introducedCount, total: catalog.foods.count)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentGradient,
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.accentDeep.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    private var introducing: [(food: Food, status: IntroductionStatus)] {
        statuses.filter { $0.state == .introducing }
            .compactMap { s in catalog.food(id: s.foodId).map { (food: $0, status: s) } }
    }

    private var pausedItems: [(food: Food, status: IntroductionStatus)] {
        statuses.filter { $0.state == .paused }
            .compactMap { s in catalog.food(id: s.foodId).map { (food: $0, status: s) } }
    }

    private func pausedRow(_ item: (food: Food, status: IntroductionStatus)) -> some View {
        NavigationLink(value: item.food) {
            HStack(spacing: 12) {
                FoodIcon(food: item.food)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.food.localizedName).font(.headline).foregroundStyle(.primary)
                    if let retry = item.status.retryAt {
                        Text("Попробовать снова \(retry.shortDate)")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Ввод остановлен").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .cartoonCard()
        }
        .buttonStyle(.plain)
    }

    private var dueGroups: [AllergenGroupStatus] {
        AllergenMaintenance(catalog: catalog, profile: child.feedingProfile,
                            statuses: statuses, logs: logs)
            .dueForDashboard()
    }

    private func dayInfo(_ s: IntroductionStatus) -> String {
        guard let start = s.introStartedAt else { return "" }
        let day = FeedingService.observationDay(start: start)
        let window = catalog.food(id: s.foodId).map { child.feedingProfile.observationDays(for: $0) }
            ?? child.feedingProfile.observationDaysRegular
        return String(localized: "День \(min(day, window)) из \(window)")
    }

    private func give(_ group: AllergenGroupStatus) {
        guard let food = group.representativeFood else { return }
        FeedingService(context: context).logFeeding(food, liking: nil, reaction: nil)
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
    }
}
