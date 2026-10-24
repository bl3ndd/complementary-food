import SwiftUI
import SwiftData

/// Список аллергенов: группы с понятным статусом поддержки толерантности.
/// Сверху — то, что пора дать; ниже — в норме / не введены / аллергия (SPEC §4.3, §7).
/// Встраивается во вкладку «Каталог» (сегмент «Аллергены»); навбар/фон даёт родитель.
struct AllergensView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var logs: [FoodLog]
    @State private var selectedFood: Food?
    /// Последняя запись «Дал» — для «Отменить». Тап пишет кормление сразу, а строка
    /// тут же уезжает при пересортировке: без отмены ошибку пришлось бы искать в дневнике.
    @State private var lastGiven: (log: FoodLog, name: String)?

    private let catalog = FoodCatalog.shared

    init(child: Child) {
        self.child = child
        let cid = child.id
        _statuses = Query(FetchDescriptor<IntroductionStatus>(
            predicate: #Predicate { $0.childId == cid }))
        _logs = Query(FetchDescriptor<FoodLog>(predicate: #Predicate { $0.childId == cid }))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard
                ForEach(sortedGroups) { row(for: $0) }
            }
            .padding()
        }
        .navigationDestination(item: $selectedFood) { food in
            FoodDetailView(food: food, child: child)
        }
        .overlay(alignment: .bottom) { undoToast }
        .animation(.snappy, value: lastGiven?.log.id)
    }

    @ViewBuilder private var undoToast: some View {
        if let given = lastGiven {
            HStack(spacing: 12) {
                Text("Записано: \(given.name)")
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 8)
                Button("Отменить") { undo(given.log) }
                    .font(.subheadline.bold()).tint(Theme.accent)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
            .padding(.horizontal).padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: given.log.id) {
                try? await Task.sleep(for: .seconds(4))
                if lastGiven?.log.id == given.log.id { lastGiven = nil }
            }
        }
    }

    private func undo(_ log: FoodLog) {
        Haptics.tap()
        let (foodId, childId) = (log.foodId, log.childId)
        context.delete(log)
        try? context.save()
        FeedingService(context: context, childId: childId).revalidate(foodId: foodId)
        NotificationManager.shared.refresh(context: context)
        Analytics.track(.logDeleted, ["undo": "true"])
        lastGiven = nil
    }

    // MARK: - Шапка-сводка

    /// Шапка-сводка. Спокойная карточка, а не белый текст на градиенте (самый
    /// «шаблонный» блок приложения), и факты вместо указаний.
    private var summaryCard: some View {
        HStack(spacing: 14) {
            Mascot(mood: MascotMood.forDue(dueCount), size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(dueCount > 0 ? String(localized: "\(dueCount) аллергенов — срок по плану") : String(localized: "Всё по плану"))
                    .font(.headline)
                Text(String(localized: "Повтор знакомых аллергенов — по твоему плану: \(child.feedingProfile.allergenFrequencyPerWeek) раз в неделю."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cartoonCard()
    }

    // MARK: - Строка-карточка

    private func row(for group: AllergenGroupStatus) -> some View {
        let info = info(for: group)
        return HStack(spacing: 12) {
            if let rep = group.representativeFood {
                FoodIcon(food: rep)
            } else {
                EmojiAvatar(emoji: "⚠️", asset: "ui_warning", color: info.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(group.group.title).font(.headline)
                Text(info.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if info.canGive {
                giveControl(group, color: info.color)
            } else {
                StatusBadge(text: info.badge, color: info.color)
            }
        }
        .cartoonCard()
        .contentShape(Rectangle())
        // Тап по строке → карточка продукта-представителя (кнопка «Дал» ловит свой тап).
        .onTapGesture { if let rep = group.representativeFood { selectedFood = rep } }
        .accessibilityAddTraits(.isButton)
    }

    /// «Дал»: если в группе введён один продукт — one-tap; если несколько — меню выбора,
    /// чтобы в дневник попал именно тот продукт, что дали (а не representative).
    @ViewBuilder
    private func giveControl(_ group: AllergenGroupStatus, color: Color) -> some View {
        let foods = introducedFoods(in: group)
        if foods.count > 1 {
            Menu {
                ForEach(foods) { food in
                    Button { give(food) } label: {
                        Label(food.localizedName, systemImage: "checkmark.circle")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Дали").font(.subheadline.weight(.bold))
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(LinearGradient(colors: [color, color.opacity(0.82)],
                                           startPoint: .top, endPoint: .bottom), in: Capsule())
            }
        } else {
            PillButton(title: "Дали", tint: color) {
                if let food = foods.first ?? group.representativeFood { give(food) }
            }
        }
    }

    private func introducedFoods(in group: AllergenGroupStatus) -> [Food] {
        group.foods.filter { food in
            statuses.first { $0.foodId == food.id }?.state == .introduced
        }
    }

    // MARK: - Статус группы → текст/цвет/действие

    private struct RowInfo {
        let badge: String
        let subtitle: String
        let color: Color
        let canGive: Bool
    }

    private func info(for group: AllergenGroupStatus) -> RowInfo {
        if group.hasAllergy {
            return RowInfo(badge: String(localized: "Аллергия"),
                           subtitle: String(localized: "Отмечена аллергия"),
                           color: .red, canGive: false)
        }
        if !group.isIntroduced {
            return RowInfo(badge: String(localized: "Не введён"),
                           subtitle: String(localized: "Ещё не вводили этот аллерген"),
                           color: .gray, canGive: false)
        }
        switch group.status {
        case .ok:
            let due = group.nextDue.map { String(localized: "По плану — \($0.shortDate)") }
                ?? String(localized: "Поддерживается")
            return RowInfo(badge: String(localized: "В норме"), subtitle: due, color: Theme.mint, canGive: false)
        case .dueSoon:
            let due = group.nextDue.map { String(localized: "По плану — \($0.shortDate)") }
                ?? String(localized: "Скоро срок по плану")
            return RowInfo(badge: String(localized: "Скоро"), subtitle: due, color: .orange, canGive: true)
        case .overdue:
            let last = group.lastGiven.map { String(localized: "Давали \($0.shortDate)") }
                ?? String(localized: "Ещё не давали в поддержку")
            return RowInfo(badge: String(localized: "Срок прошёл"), subtitle: last, color: Theme.accent, canGive: true)
        }
    }

    // MARK: - Данные

    /// Приоритет сортировки: пора дать → скоро → в норме → не введён → аллергия.
    private func priority(_ group: AllergenGroupStatus) -> Int {
        if group.hasAllergy { return 4 }
        if !group.isIntroduced { return 3 }
        switch group.status {
        case .overdue: return 0
        case .dueSoon: return 1
        case .ok:      return 2
        }
    }

    private var sortedGroups: [AllergenGroupStatus] {
        groups.sorted { priority($0) < priority($1) }
    }

    private var dueCount: Int {
        groups.filter { $0.isIntroduced && !$0.hasAllergy && $0.status != .ok }.count
    }

    private func give(_ food: Food) {
        Haptics.success()
        let log = FeedingService(context: context, childId: child.id).logFeeding(food, liking: nil, reaction: nil)
        NotificationManager.shared.refresh(context: context)
        Analytics.track(.allergenGiven)
        lastGiven = (log, food.localizedName)
    }

    private var groups: [AllergenGroupStatus] {
        AllergenMaintenance(catalog: catalog, profile: child.feedingProfile,
                            statuses: statuses, logs: logs).groups()
    }
}
