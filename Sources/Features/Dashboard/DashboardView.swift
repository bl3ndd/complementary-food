import SwiftUI
import SwiftData

/// Главная — журнал-лента (концепт A): спокойная шапка → «Добавить запись» →
/// баннеры «требует внимания» → дневник записей по дням.
struct DashboardView: View {
    let child: Child
    var goToCatalog: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var logs: [FoodLog]
    @State private var editingLog: FoodLog?
    @State private var showPlan = false
    @State private var showQuickLog = false

    private let catalog = FoodCatalog.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    greeting
                    addButton
                    attentionZone
                    feed
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
            .sheet(isPresented: $showQuickLog) { QuickLogSheet(child: child) }
            .sheet(isPresented: $showPlan) {
                PlanIntroSheet(initialDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
            }
        }
    }

    // MARK: - Шапка

    private var greeting: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.25)).frame(width: 58, height: 58)
                Mascot(mood: .happy, size: 46)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(child.name.isEmpty ? String(localized: "Малыш") : child.name)
                    .font(.title2.bold()).foregroundStyle(.white)
                Text("\(child.ageInMonths) мес")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentGradient,
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.accentDeep.opacity(0.30), radius: 16, x: 0, y: 9)
    }

    private var addButton: some View {
        Menu {
            Button { showQuickLog = true } label: { Label("Записать кормление", systemImage: "square.and.pencil") }
            Button { showPlan = true } label: { Label("Запланировать ввод", systemImage: "calendar.badge.plus") }
            Button { goToCatalog() } label: { Label("Ввести новый продукт", systemImage: "leaf.fill") }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Добавить запись")
            }
            .font(.headline.bold()).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(Theme.accentGradient, in: Capsule())
            .shadow(color: Theme.accent.opacity(0.35), radius: 10, x: 0, y: 5)
        }
    }

    // MARK: - Требует внимания

    @ViewBuilder
    private var attentionZone: some View {
        if dueCount > 0 {
            Button { AppRouter.shared.selectedTab = .allergens } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.shield.fill").font(.title3).foregroundStyle(.orange)
                    Text("Аллергенов пора освежить: \(dueCount)")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .cartoonCard()
            }
            .buttonStyle(.plain)
        }
        if !introducing.isEmpty {
            attentionLabel("В процессе ввода")
            ForEach(introducing, id: \.status.foodId) { attentionRow($0.food, subtitle: dayInfo($0.status)) }
        }
        if !pausedItems.isEmpty {
            attentionLabel("Отложенные продукты")
            ForEach(pausedItems, id: \.status.foodId) { item in
                attentionRow(item.food, subtitle: pausedSubtitle(item.status))
            }
        }
    }

    private func attentionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.subheadline.bold()).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attentionRow(_ food: Food, subtitle: String) -> some View {
        NavigationLink(value: food) {
            HStack(spacing: 12) {
                FoodIcon(food: food, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.localizedName).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10).padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.9), lineWidth: 1))
            .shadow(color: Theme.accentDeep.opacity(0.08), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func pausedSubtitle(_ s: IntroductionStatus) -> String {
        if let retry = s.retryAt { return String(localized: "Попробовать снова \(retry.shortDate)") }
        return String(localized: "Ввод остановлен")
    }

    // MARK: - Лента дневника

    @ViewBuilder
    private var feed: some View {
        if feedDays.isEmpty {
            emptyFeed
        } else {
            ForEach(feedDays) { day in
                VStack(alignment: .leading, spacing: 8) {
                    Text(dayLabel(day.date)).font(.subheadline.bold()).foregroundStyle(.secondary)
                        .padding(.top, 4)
                    ForEach(day.entries) { feedRow($0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func feedRow(_ entry: DayEntry) -> some View {
        HStack(spacing: 12) {
            if let food = entry.food { FoodIcon(food: food) }
            else { EmojiAvatar(emoji: "🍽️", asset: "ui_plate") }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.food?.localizedName ?? entry.foodName).font(.headline)
                HStack(spacing: 6) {
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.caption).foregroundStyle(.secondary)
                    if let r = entry.reaction, r != .none {
                        StatusBadge(text: r.title, color: .red)
                    }
                }
            }
            Spacer()
            if let liking = entry.liking {
                OpenMojiIcon(asset: "like_\(liking.rawValue)", fallback: liking.emoji, size: 28)
            }
        }
        .cartoonCard()
        .contentShape(Rectangle())
        .onTapGesture { editingLog = entry.log }
    }

    private var emptyFeed: some View {
        VStack(spacing: 12) {
            Mascot(mood: .curious)
            Text("Здесь будет дневник кормлений").font(.headline)
            Text("Запиши первое кормление или начни вводить продукт.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Данные

    private var feedDays: [DaySummary] {
        let real = logs.filter { !$0.planned }
        let today = Calendar.current.startOfDay(for: Date())
        return CalendarService(catalog: catalog, logs: real).days()
            .filter { $0.date <= today }
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return String(localized: "Сегодня") }
        if cal.isDateInYesterday(date) { return String(localized: "Вчера") }
        return date.formatted(.dateTime.day().month().weekday(.abbreviated)).capitalized
    }

    private var introducing: [(food: Food, status: IntroductionStatus)] {
        statuses.filter { $0.state == .introducing }
            .compactMap { s in catalog.food(id: s.foodId).map { (food: $0, status: s) } }
    }

    private var pausedItems: [(food: Food, status: IntroductionStatus)] {
        statuses.filter { $0.state == .paused }
            .compactMap { s in catalog.food(id: s.foodId).map { (food: $0, status: s) } }
    }

    private var dueGroups: [AllergenGroupStatus] {
        AllergenMaintenance(catalog: catalog, profile: child.feedingProfile,
                            statuses: statuses, logs: logs)
            .dueForDashboard()
    }
    private var dueCount: Int { dueGroups.count }

    private func dayInfo(_ s: IntroductionStatus) -> String {
        guard let start = s.introStartedAt else { return "" }
        let day = FeedingService.observationDay(start: start)
        let window = catalog.food(id: s.foodId).map { child.feedingProfile.observationDays(for: $0) }
            ?? child.feedingProfile.observationDaysRegular
        return String(localized: "День \(min(day, window)) из \(window)")
    }
}
