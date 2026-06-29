import SwiftUI

/// Редактор «своего плана» прикорма: пользователь задаёт старт, окно наблюдения,
/// частоту поддержки аллергена и список аллергенов. Пишет в custom-поля Child.
struct CustomPlanEditor: View {
    @Bindable var child: Child

    private let limits = FeedingProfile.CustomLimits.self
    @State private var shownInfo: PlanInfo?

    /// Какой параметр поясняем во всплывашке ⓘ.
    enum PlanInfo: String, Identifiable {
        case start, windowRegular, windowAllergen, frequency
        var id: String { rawValue }
        var text: LocalizedStringKey {
            switch self {
            case .start:
                return "С какого возраста начинать прикорм. Обычно 4–6 месяцев — точные сроки и готовность малыша согласуй с педиатром."
            case .windowRegular:
                return "Сколько дней наблюдать за реакцией на новый обычный продукт, прежде чем считать его введённым."
            case .windowAllergen:
                return "Для аллергенов окно наблюдения обычно длиннее: реакция может проявиться не сразу, поэтому следим дольше."
            case .frequency:
                return "Как часто в неделю давать уже введённый аллерген, чтобы поддерживать толерантность (клинический консенсус LEAP/EAT)."
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            paramRow("calendar", "Старт прикорма", color: Theme.sunny, info: .start,
                     value: $child.customStartAgeMonths, range: limits.startAge, unit: "мес")
            paramRow("eye.fill", "Окно: обычный продукт", color: Theme.sky, info: .windowRegular,
                     value: $child.customObservationDaysRegular, range: limits.observation, unit: "дн")
            paramRow("exclamationmark.triangle.fill", "Окно: аллерген", color: Theme.accentDeep, info: .windowAllergen,
                     value: $child.customObservationDaysAllergen, range: limits.observation, unit: "дн")
            paramRow("repeat", "Частота аллергена", color: Theme.mint, info: .frequency,
                     value: $child.customAllergenFrequencyPerWeek, range: limits.frequency, unit: "×/нед")

            Divider().padding(.vertical, 2)

            Text("Аллергены для ввода").font(.subheadline.bold())
            allergenGrid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartoonCard()
    }

    // MARK: - Параметр со степпером +/- и пояснением ⓘ

    private func paramRow(_ icon: String, _ title: LocalizedStringKey, color: Color, info: PlanInfo,
                          value: Binding<Int>, range: ClosedRange<Int>, unit: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Строка названия на всю ширину — длинный русский текст переносится, не режется.
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.softGradient(color))
                    Image(systemName: icon).font(.footnote).foregroundStyle(color)
                }
                .frame(width: 30, height: 30)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    infoButton(info)
                }
                Spacer(minLength: 0)
            }
            // Степпер-капсула во всю ширину: − слева, число по центру, + справа.
            stepper(value: value, range: range, unit: unit)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Кнопка ⓘ с всплывающим пояснением «зачем этот параметр».
    private func infoButton(_ info: PlanInfo) -> some View {
        Button { shownInfo = info } label: {
            Image(systemName: "info.circle").font(.footnote).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(get: { shownInfo == info },
                                      set: { if !$0 { shownInfo = nil } })) {
            Text(info.text)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .frame(width: 280)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func stepper(value: Binding<Int>, range: ClosedRange<Int>, unit: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            roundButton("minus", enabled: value.wrappedValue > range.lowerBound) {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 5) {
                Text("\(value.wrappedValue)").font(.title3.bold().monospacedDigit())
                Text(unit).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            roundButton("plus", enabled: value.wrappedValue < range.upperBound) {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.045), in: Capsule())
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
