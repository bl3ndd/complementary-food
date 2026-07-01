import SwiftUI
import SwiftData

/// Главная «Стена Pudding» (концепт A): маскот-барометр → быстрые действия →
/// заполняющаяся коллекция продуктов → витрина аллергенов → лента дня.
/// Коллекция показывает то, что УЖЕ сделано (ретроспектива), без советов/рекомендаций.
struct DashboardView: View {
    let child: Child
    var goToCatalog: () -> Void = {}
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var logs: [FoodLog]
    @State private var editingLog: FoodLog?
    @State private var showFeed = false
    @State private var showReaction = false
    @State private var showPlan = false

    private let catalog = FoodCatalog.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    actionTiles
                    todayCard
                    introducingCard
                    collectionCard
                    allergenCard
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
            .sheet(isPresented: $showFeed) { QuickLogSheet(child: child, mode: .feeding) }
            .sheet(isPresented: $showReaction) { QuickLogSheet(child: child, mode: .reaction) }
            .sheet(isPresented: $showPlan) {
                PlanIntroSheet(initialDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
            }
        }
    }

    // MARK: - Маскот-барометр

    private var heroCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.25)).frame(width: 60, height: 60)
                Mascot(mood: todayEntries.isEmpty ? .happy : .cheer, size: 50)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(child.name.isEmpty ? String(localized: "Малыш") : child.name)
                    .font(.title2.bold()).foregroundStyle(.white)
                Text("\(child.ageInMonths) мес")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.9))
                Text(todayEntries.isEmpty
                     ? String(localized: "Сегодня записей пока нет")
                     : String(localized: "Сегодня записей: \(todayEntries.count) 🎉"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.95))
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentGradient,
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.accentDeep.opacity(0.30), radius: 16, x: 0, y: 9)
    }

    // MARK: - Быстрые действия

    private var actionTiles: some View {
        HStack(spacing: 12) {
            actionTile("Записать", asset: "ui_plate", emoji: "🍽️", color: Theme.mint) { showFeed = true }
            actionTile("Реакция", asset: "react_skin", emoji: "🩹", color: .orange) { showReaction = true }
        }
    }

    private func actionTile(_ title: LocalizedStringKey, asset: String, emoji: String, color: Color,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(.white.opacity(0.92)).frame(width: 54, height: 54)
                        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
                    OpenMojiIcon(asset: asset, fallback: emoji, size: 34)
                }
                Text(title).font(.subheadline.bold()).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 18)
            .background(LinearGradient(colors: [color, color.opacity(0.78)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: color.opacity(0.35), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: - Сейчас вводишь (окно наблюдения)

    @ViewBuilder private var introducingCard: some View {
        if !introducingItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill").foregroundStyle(Theme.mint)
                    Text("Сейчас вводишь").font(.headline)
                }
                ForEach(Array(introducingItems.enumerated()), id: \.element.status.foodId) { idx, item in
                    if idx > 0 { Divider() }
                    NavigationLink(value: item.food) {
                        HStack(spacing: 12) {
                            FoodIcon(food: item.food, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.food.localizedName).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(dayInfo(item.status)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartoonCard()
        }
    }

    private var introducingItems: [(food: Food, status: IntroductionStatus)] {
        statuses.filter { $0.state == .introducing }
            .compactMap { s in catalog.food(id: s.foodId).map { (food: $0, status: s) } }
    }

    private func dayInfo(_ s: IntroductionStatus) -> String {
        guard let start = s.introStartedAt else { return "" }
        let day = FeedingService.observationDay(start: start)
        let window = catalog.food(id: s.foodId).map { child.feedingProfile.observationDays(for: $0) }
            ?? child.feedingProfile.observationDaysRegular
        return String(localized: "День \(min(day, window)) из \(window)")
    }

    // MARK: - Коллекция продуктов (заполняется)

    private var collectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Коллекция продуктов").font(.headline)
                Spacer()
                Text("\(introducedCount)/\(catalog.foods.count)")
                    .font(.subheadline.bold()).foregroundStyle(Theme.accent)
            }
            ProgressView(value: Double(introducedCount), total: Double(max(1, catalog.foods.count)))
                .tint(Theme.accent)

            let shown = Array(collectionFoods.prefix(20))
            let ghosts = max(0, 20 - shown.count)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 10)], spacing: 10) {
                ForEach(shown) { food in
                    NavigationLink(value: food) { FoodIcon(food: food, size: 44) }
                        .buttonStyle(.plain)
                }
                ForEach(0..<ghosts, id: \.self) { _ in ghostCell }
            }

            Button { goToCatalog() } label: {
                Label("Вся коллекция", systemImage: "square.grid.2x2")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartoonCard()
    }

    private var ghostCell: some View {
        Circle().fill(Color.black.opacity(0.035))
            .frame(width: 44, height: 44)
            .overlay(Circle().stroke(Color.black.opacity(0.08),
                                     style: StrokeStyle(lineWidth: 1, dash: [3])))
    }

    // MARK: - Витрина аллергенов

    private var allergenCard: some View {
        Button { AppRouter.shared.selectedTab = .allergens } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Аллергены").font(.headline)
                    Spacer()
                    if dueCount > 0 {
                        Text("\(dueCount)").font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.orange, in: Capsule())
                    }
                    Text("\(introducedAllergenCount)/\(allergenGroups.count)")
                        .font(.subheadline.bold()).foregroundStyle(Theme.accent)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 10) {
                    ForEach(allergenGroups) { allergenCircle($0) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cartoonCard()
        }
        .buttonStyle(.plain)
    }

    private func allergenCircle(_ g: AllergenGroupStatus) -> some View {
        let due = g.isIntroduced && !g.hasAllergy && g.status != .ok
        return VStack(spacing: 4) {
            ZStack {
                if let rep = g.representativeFood {
                    FoodIcon(food: rep, size: 40)
                        .grayscale(g.isIntroduced ? 0 : 1)
                        .opacity(g.isIntroduced ? 1 : 0.4)
                } else {
                    ghostCell.frame(width: 40, height: 40)
                }
                if due {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.orange, lineWidth: 2).frame(width: 46, height: 46)
                }
                if g.hasAllergy {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.red, lineWidth: 2).frame(width: 46, height: 46)
                }
            }
            Text(g.group.title).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    // MARK: - Лента дня

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Дневник за сегодня").font(.headline)
                Spacer()
                Button { showPlan = true } label: {
                    Label("Запланировать", systemImage: "calendar.badge.plus")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                }
            }
            if todayEntries.isEmpty {
                Text("Записей сегодня ещё нет").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(todayEntries) { entry in
                    HStack(spacing: 12) {
                        if let food = entry.food { FoodIcon(food: food, size: 38) }
                        else { EmojiAvatar(emoji: "🍽️", asset: "ui_plate", size: 38) }
                        Text(entry.food?.localizedName ?? entry.foodName)
                            .font(.subheadline.weight(.medium)).lineLimit(1)
                        if let r = entry.reaction, r != .none {
                            StatusBadge(text: r.title, color: .red)
                        }
                        if let liking = entry.liking {
                            OpenMojiIcon(asset: "like_\(liking.rawValue)", fallback: liking.emoji, size: 24)
                        }
                        Spacer(minLength: 8)
                        // Время — всегда крайнее справа, ровным столбцом.
                        Text(entry.date.formatted(.dateTime.hour().minute()))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingLog = entry.log }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartoonCard()
    }

    // MARK: - Данные

    private var introducedCount: Int {
        statuses.filter { $0.state == .introduced }.count
    }

    /// Для стены: введённые и вводимые продукты (введённые первыми).
    private var collectionFoods: [Food] {
        let order: (IntroState) -> Int = { $0 == .introduced ? 0 : 1 }
        let ids = statuses.filter { $0.state == .introduced || $0.state == .introducing }
            .sorted { order($0.state) < order($1.state) }
            .map(\.foodId)
        return ids.compactMap { catalog.food(id: $0) }
    }

    private var todayEntries: [DayEntry] {
        CalendarService(catalog: catalog, logs: logs).day(Date()).entries.filter { !$0.planned }
    }

    private var allergenGroups: [AllergenGroupStatus] {
        AllergenMaintenance(catalog: catalog, profile: child.feedingProfile,
                            statuses: statuses, logs: logs).groups()
    }
    private var introducedAllergenCount: Int { allergenGroups.filter { $0.isIntroduced }.count }
    private var dueCount: Int {
        allergenGroups.filter { $0.isIntroduced && !$0.hasAllergy && $0.status != .ok }.count
    }
}
