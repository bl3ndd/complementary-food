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

    private let catalog = FoodCatalog.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard
                ForEach(sortedGroups) { row(for: $0) }
            }
            .padding()
        }
    }

    // MARK: - Шапка-сводка

    private var summaryCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(.white.opacity(0.25)).frame(width: 56, height: 56)
                Mascot(mood: MascotMood.forDue(dueCount), size: 46)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(dueCount > 0 ? "Пора освежить" : "Всё под контролем")
                    .font(.title3.bold()).foregroundStyle(.white)
                Text(dueCount > 0
                     ? "\(dueCount) \(allergenWord(dueCount)) ждут — дай, чтобы сохранить толерантность"
                     : "Знакомые аллергены повторяются вовремя")
                    .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentGradient,
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Theme.accentDeep.opacity(0.30), radius: 16, x: 0, y: 9)
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
                PillButton(title: "Дал", tint: info.color) { give(group) }
            } else {
                StatusBadge(text: info.badge, color: info.color)
            }
        }
        .cartoonCard()
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
            return RowInfo(badge: "Аллергия", subtitle: "Только по согласованию с врачом",
                           color: .red, canGive: false)
        }
        if !group.isIntroduced {
            return RowInfo(badge: "Не введён", subtitle: "Ещё не вводили этот аллерген",
                           color: .gray, canGive: false)
        }
        switch group.status {
        case .ok:
            let due = group.nextDue.map { "Повторить до \($0.shortDate)" } ?? "Поддерживается"
            return RowInfo(badge: "В норме", subtitle: due, color: Theme.mint, canGive: false)
        case .dueSoon:
            let due = group.nextDue.map { "Лучше дать до \($0.shortDate)" } ?? "Скоро пора дать"
            return RowInfo(badge: "Скоро", subtitle: due, color: .orange, canGive: true)
        case .overdue:
            let last = group.lastGiven.map { "Давали \($0.shortDate)" } ?? "Ещё не давали в поддержку"
            return RowInfo(badge: "Пора дать", subtitle: last, color: Theme.accent, canGive: true)
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

    private func allergenWord(_ n: Int) -> String {
        let mod10 = n % 10, mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "аллерген" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "аллергена" }
        return "аллергенов"
    }

    private func give(_ group: AllergenGroupStatus) {
        guard let food = group.representativeFood else { return }
        FeedingService(context: context).logFeeding(food, liking: nil, reaction: nil)
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
    }

    private var groups: [AllergenGroupStatus] {
        AllergenMaintenance(catalog: catalog, profile: child.feedingProfile,
                            statuses: statuses, logs: logs).groups()
    }
}
