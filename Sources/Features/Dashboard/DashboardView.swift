import SwiftUI
import SwiftData

/// Экран «Сегодня»: что в окне наблюдения + какие аллергены пора дать (SPEC §7).
struct DashboardView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var logs: [FoodLog]

    private let catalog = FoodCatalog.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    if child.ageInMonths < child.feedingProfile.startAgeMonths {
                        earlyBanner
                    }
                    if !dueGroups.isEmpty {
                        section(title: "Пора дать аллерген 🔔") {
                            ForEach(dueGroups) { dueRow($0) }
                        }
                    }
                    if !introducing.isEmpty {
                        section(title: "В процессе ввода 🌱") {
                            ForEach(introducing, id: \.status.foodId) { introRow($0) }
                        }
                    }
                    if dueGroups.isEmpty && introducing.isEmpty {
                        emptyState
                    }
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Сегодня")
            .navigationDestination(for: Food.self) { food in
                FoodDetailView(food: food, child: child)
            }
        }
    }

    // MARK: - Секции

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dueRow(_ group: AllergenGroupStatus) -> some View {
        HStack(spacing: 12) {
            if let rep = group.representativeFood {
                FoodIcon(food: rep)
            } else {
                EmojiAvatar(emoji: "⚠️", color: group.status.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(group.group.title).font(.headline)
                if let due = group.nextDue {
                    Text("к \(due.shortDate)").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button { give(group) } label: {
                Text("Дал").fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .cartoonCard()
    }

    private func introRow(_ item: (food: Food, status: IntroductionStatus)) -> some View {
        NavigationLink(value: item.food) {
            HStack(spacing: 12) {
                FoodIcon(food: item.food)
                Text(item.food.name).font(.headline).foregroundStyle(.primary)
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

    private var earlyBanner: some View {
        HStack(spacing: 12) {
            Text("🐣").font(.system(size: 40))
            Text("По выбранной методике прикорм лучше начинать ~\(child.feedingProfile.startAgeMonths) мес.")
                .font(.subheadline)
        }
        .cartoonCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("🍽️").font(.system(size: 64))
            Text("Всё под контролем!").font(.title3.bold())
            Text("Загляни в каталог и выбери первый продукт.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(child.name.isEmpty ? "Малыш" : child.name).font(.title3.bold())
                Text("\(child.ageInMonths) мес").font(.subheadline).foregroundStyle(.secondary)
                Text("\(introducedCount) продуктов введено")
                    .font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
            }
            Spacer()
            ProgressRing(value: introducedCount, total: catalog.foods.count)
        }
        .cartoonCard()
    }

    private var introducing: [(food: Food, status: IntroductionStatus)] {
        statuses.filter { $0.state == .introducing }
            .compactMap { s in catalog.food(id: s.foodId).map { (food: $0, status: s) } }
    }

    private var dueGroups: [AllergenGroupStatus] {
        AllergenMaintenance(catalog: catalog, profile: child.feedingProfile,
                            statuses: statuses, logs: logs)
            .groups()
            .filter { $0.isIntroduced && !$0.hasAllergy && $0.status != .ok }
    }

    private func dayInfo(_ s: IntroductionStatus) -> String {
        guard let start = s.introStartedAt else { return "" }
        let day = (Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0) + 1
        return "День \(day) из \(child.feedingProfile.observationDays)"
    }

    private func give(_ group: AllergenGroupStatus) {
        guard let food = group.representativeFood else { return }
        FeedingService(context: context).logFeeding(food, liking: nil, reaction: nil)
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
    }
}
