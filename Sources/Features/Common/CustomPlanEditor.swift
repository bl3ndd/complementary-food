import SwiftUI

/// Редактор «своего плана» прикорма. По умолчанию свёрнут до сводки (прогрессивное
/// раскрытие), параметры выбираются тапом по значению (выпадающее меню), а не +/-.
struct CustomPlanEditor: View {
    @Bindable var child: Child
    @State private var expanded = false
    @State private var shownInfo: PlanInfo?

    private let limits = FeedingProfile.CustomLimits.self

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
            summaryRow
            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider()
                    paramRow("calendar", "Старт прикорма", color: Theme.sunny, info: .start,
                             value: $child.customStartAgeMonths, range: limits.startAge, unit: "мес")
                    paramRow("eye.fill", "Окно: обычный продукт", color: Theme.sky, info: .windowRegular,
                             value: $child.customObservationDaysRegular, range: limits.observation, unit: "дн")
                    paramRow("exclamationmark.triangle.fill", "Окно: аллерген", color: Theme.accentDeep, info: .windowAllergen,
                             value: $child.customObservationDaysAllergen, range: limits.observation, unit: "дн")
                    paramRow("repeat", "Частота аллергена", color: Theme.mint, info: .frequency,
                             value: $child.customAllergenFrequencyPerWeek, range: limits.frequency, unit: "×/нед")
                    Divider()
                    Text("Аллергены для ввода").font(.subheadline.bold())
                    allergenGrid
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartoonCard()
    }

    // MARK: - Сводка + раскрытие (прогрессивное раскрытие, вариант C)

    private var summaryRow: some View {
        Button { withAnimation(.smooth(duration: 0.28)) { expanded.toggle() } } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Твой план прикорма").font(.subheadline.bold()).foregroundStyle(.primary)
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: expanded ? "chevron.up" : "slider.horizontal.3")
                    .font(.subheadline).foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Theme.accent.opacity(0.12), in: Circle())
            }
        }
        .buttonStyle(.plain)
    }

    private var summary: String {
        String(localized: "Старт \(child.customStartAgeMonths) мес · окна \(child.customObservationDaysRegular)/\(child.customObservationDaysAllergen) дн · аллерген \(child.customAllergenFrequencyPerWeek)×/нед")
    }

    // MARK: - Параметр: тап по значению → выпадающее меню (вариант A)

    private func paramRow(_ icon: String, _ title: LocalizedStringKey, color: Color, info: PlanInfo,
                          value: Binding<Int>, range: ClosedRange<Int>, unit: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            iconChip(icon, color)
            HStack(spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                infoButton(info)
            }
            Spacer(minLength: 8)
            Menu {
                Picker("", selection: value) {
                    ForEach(Array(range), id: \.self) { n in
                        valueText(n, unit).tag(n)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    valueText(value.wrappedValue, unit).font(.subheadline.bold()).monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.accent.opacity(0.12), in: Capsule())
            }
        }
    }

    private func valueText(_ n: Int, _ unit: LocalizedStringKey) -> Text {
        Text("\(n) ") + Text(unit)
    }

    private func iconChip(_ icon: String, _ color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.softGradient(color))
            Image(systemName: icon).font(.footnote).foregroundStyle(color)
        }
        .frame(width: 30, height: 30)
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
