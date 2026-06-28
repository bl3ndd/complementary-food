import SwiftUI

/// Наглядная карточка методики прикорма: все параметры пресета/плана сразу видны
/// (старт, окно наблюдения, частота аллергена, аллергены, источник). Используется
/// в онбординге (компактно) и профиле (`expanded`).
struct MethodologyCard: View {
    let profile: FeedingProfile
    var selected: Bool = false
    var expanded: Bool = false
    var onTap: (() -> Void)? = nil

    private let catalog = FoodCatalog.shared

    var body: some View {
        Button { onTap?() } label: { card }
            .buttonStyle(BouncyButtonStyle())
            .disabled(onTap == nil)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(profile.name).font(.headline)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent).font(.title3)
                }
            }

            // Параметры плитками
            HStack(spacing: 8) {
                paramChip("calendar", "Старт", "\(profile.startAgeMonths) мес")
                paramChip("eye.fill", "Окно", "\(profile.observationDays) дн")
                paramChip("repeat", "Аллерген", "\(profile.allergenFrequencyPerWeek)×/нед")
            }

            // Аллергены
            if !profile.allergenGroups.isEmpty {
                Text("Аллергены: \(allergenNames)")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(expanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if expanded {
                if let url = URL(string: profile.sourceURL) {
                    Link(destination: url) {
                        Label(profile.source, systemImage: "doc.text.magnifyingglass")
                            .font(.footnote)
                    }
                }
                Text(profile.caveat)
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(selected ? Theme.accent : Color.clear, lineWidth: 2.5)
        )
        .shadow(color: Theme.accentDeep.opacity(0.10), radius: 12, y: 6)
    }

    private func paramChip(_ icon: String, _ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.caption).foregroundStyle(Theme.accent)
            Text(value).font(.subheadline.bold())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.accent.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var allergenNames: String {
        profile.allergenGroups.map(\.title).joined(separator: ", ")
    }
}
