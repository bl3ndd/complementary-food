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
            paramRow("eye.fill", "Окно: обычный продукт", color: Theme.sky,
                     value: $child.customObservationDaysRegular, range: limits.observation, unit: "дн")
            paramRow("exclamationmark.triangle.fill", "Окно: аллерген", color: Theme.accentDeep,
                     value: $child.customObservationDaysAllergen, range: limits.observation, unit: "дн")
            paramRow("repeat", "Частота аллергена", color: Theme.mint,
                     value: $child.customAllergenFrequencyPerWeek, range: limits.frequency, unit: "×/нед")

            Divider().padding(.vertical, 2)

            Text("Аллергены для ввода").font(.subheadline.bold())
            allergenGrid
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartoonCard()
    }

    // MARK: - Параметр: выбор значения тапом по бейджу-числу (вместо +/-, п.9)

    private func paramRow(_ icon: String, _ title: LocalizedStringKey, color: Color,
                          value: Binding<Int>, range: ClosedRange<Int>, unit: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Theme.softGradient(color))
                    Image(systemName: icon).font(.subheadline).foregroundStyle(color)
                }
                .frame(width: 36, height: 36)

                Text(title).font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                HStack(spacing: 3) {
                    Text("\(value.wrappedValue)").font(.subheadline.bold()).monospacedDigit()
                    Text(unit).font(.caption2).foregroundStyle(.secondary)
                }
            }
            valuePicker(value: value, range: range)
        }
    }

    /// Горизонтальный ряд бейджей-чисел; тап выбирает значение.
    private func valuePicker(value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(range), id: \.self) { n in
                    let on = value.wrappedValue == n
                    Text("\(n)")
                        .font(.subheadline.weight(.bold)).monospacedDigit()
                        .frame(width: 38, height: 34)
                        .background(on ? AnyShapeStyle(Theme.accentGradient)
                                       : AnyShapeStyle(Color.black.opacity(0.05)),
                                    in: Capsule())
                        .foregroundStyle(on ? .white : .primary)
                        .contentShape(Capsule())
                        .onTapGesture { withAnimation(.snappy) { value.wrappedValue = n } }
                }
            }
            .padding(.vertical, 1)
        }
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
