import SwiftUI

/// Редактор «своего плана» прикорма: пользователь задаёт старт, окно наблюдения,
/// частоту поддержки аллергена и список аллергенов. Пишет в custom-поля Child.
struct CustomPlanEditor: View {
    @Bindable var child: Child

    private let limits = FeedingProfile.CustomLimits.self

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            paramRow("calendar", "Старт прикорма", color: Theme.sunny,
                     value: $child.customStartAgeMonths, range: limits.startAge, unit: "мес")
            paramRow("eye.fill", "Окно наблюдения", color: Theme.sky,
                     value: $child.customObservationDays, range: limits.observation, unit: "дн")
            paramRow("repeat", "Частота аллергена", color: Theme.mint,
                     value: $child.customAllergenFrequencyPerWeek, range: limits.frequency, unit: "×/нед")

            Divider().padding(.vertical, 2)

            Text("Аллергены для ввода").font(.subheadline.bold())
            allergenGrid

            Text(Disclaimer.short)
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartoonCard()
    }

    // MARK: - Параметр с кастомным степпером

    private func paramRow(_ icon: String, _ title: String, color: Color,
                          value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Theme.softGradient(color))
                Image(systemName: icon).font(.subheadline).foregroundStyle(color)
            }
            .frame(width: 36, height: 36)

            Text(title).font(.subheadline.weight(.medium))
            Spacer(minLength: 8)
            stepper(value: value, range: range, unit: unit)
        }
    }

    private func stepper(value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 10) {
            roundButton("minus", enabled: value.wrappedValue > range.lowerBound) {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
            }
            VStack(spacing: -1) {
                Text("\(value.wrappedValue)").font(.headline.bold()).monospacedDigit()
                Text(unit).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(minWidth: 40)
            roundButton("plus", enabled: value.wrappedValue < range.upperBound) {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
            }
        }
    }

    private func roundButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(enabled ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background(enabled ? AnyShapeStyle(Theme.accentGradient)
                                    : AnyShapeStyle(Color.black.opacity(0.06)),
                            in: Circle())
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!enabled)
    }

    // MARK: - Аллергены

    private var allergenGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 108), spacing: 8)]
        // «Другое» — это категория продукта, а не реальная группа аллергенов; не показываем.
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(AllergenGroup.allCases.filter { $0 != .other }, id: \.self) { group in
                allergenChip(group)
            }
        }
    }

    private func allergenChip(_ group: AllergenGroup) -> some View {
        let on = child.customAllergenGroups.contains(group)
        return Button {
            withAnimation(.snappy) { toggle(group) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: on ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(on ? Theme.accent : .secondary)
                Text(group.title).font(.caption.weight(.semibold))
                    .foregroundStyle(on ? Theme.accent : .primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11).padding(.vertical, 10)
            .background(on ? Theme.accent.opacity(0.14) : Color.black.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(on ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ group: AllergenGroup) {
        var groups = child.customAllergenGroups
        if let i = groups.firstIndex(of: group) { groups.remove(at: i) } else { groups.append(group) }
        child.customAllergenGroups = groups
    }
}
