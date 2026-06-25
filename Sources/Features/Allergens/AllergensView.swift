import SwiftUI
import SwiftData

/// Экран аллергенов как «садик»: каждый аллерген — растение, которое надо
/// регулярно «поливать» (давать), иначе оно вянет (SPEC §4.3, §7).
/// Метафора 1-в-1 с механикой поддержки толерантности.
struct AllergensView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var logs: [FoodLog]

    private let catalog = FoodCatalog.shared
    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Поливай растения вовремя — так аллергены остаются «знакомыми» и толерантность не падает.")
                        .font(.subheadline).foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(groups) { group in
                            card(for: group)
                        }
                    }
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Садик аллергенов")
        }
    }

    // MARK: - Карточка-растение

    private func card(for group: AllergenGroupStatus) -> some View {
        let plant = plant(for: group)
        return VStack(spacing: 8) {
            ZStack {
                Circle().fill(plant.color.opacity(0.18)).frame(width: 64, height: 64)
                Text(plant.emoji).font(.system(size: 34))
            }
            Text(group.group.title).font(.headline)
            Text(plant.phrase).font(.caption.weight(.medium)).foregroundStyle(plant.color)

            if waterable(group) {
                Button { water(group) } label: {
                    Text("Полить 💧").font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(plant.color)
            } else if let last = group.lastGiven, group.isIntroduced, !group.hasAllergy {
                Text("полит \(last.shortDate)").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 150)
        .cartoonCard()
    }

    // MARK: - Логика растения

    private func plant(for group: AllergenGroupStatus) -> (emoji: String, phrase: String, color: Color) {
        if group.hasAllergy { return ("⚠️", "Аллергия", .red) }
        if !group.isIntroduced { return ("🌰", "Не посажен", .gray) }
        switch group.status {
        case .ok:      return ("🌸", "Цветёт", .green)
        case .dueSoon: return ("🌼", "Скоро полить", .orange)
        case .overdue: return ("🥀", "Пора полить!", .red)
        }
    }

    private func waterable(_ group: AllergenGroupStatus) -> Bool {
        group.isIntroduced && !group.hasAllergy && group.status != .ok
    }

    private func water(_ group: AllergenGroupStatus) {
        guard let food = group.representativeFood else { return }
        FeedingService(context: context).logFeeding(food, liking: nil, reaction: nil)
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
    }

    private var groups: [AllergenGroupStatus] {
        AllergenMaintenance(catalog: catalog, profile: child.feedingProfile,
                            statuses: statuses, logs: logs).groups()
    }
}
