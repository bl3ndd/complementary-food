import SwiftUI

/// Строка-пуш плана прикорма для Профиля: иконка + краткая сводка → отдельный
/// экран с полным редактором (PlanDetailEditor). Обычная строка Form, не карточка.
struct CustomPlanEditor: View {
    @Bindable var child: Child

    var body: some View {
        NavigationLink {
            ScrollView { PlanDetailEditor(child: child).padding() }
                .background(AppBackground())
                .navigationTitle("Твой план прикорма")
                .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.softGradient(Theme.accent))
                    Image(systemName: "slider.horizontal.3").font(.footnote).foregroundStyle(Theme.accent)
                }
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Твой план").font(.subheadline.weight(.medium))
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var summary: String {
        String(localized: "старт \(child.customStartAgeMonths) мес · обычный \(child.customObservationDaysRegular) дн · аллерген \(child.customObservationDaysAllergen) дн · \(child.customAllergenFrequencyPerWeek)×/нед")
    }
}

/// Полная форма настройки «своего плана» (инлайн): параметры тап-меню + аллергены.
/// В онбординге встраивается напрямую, в Профиле — внутрь листа из CustomPlanEditor.
struct PlanDetailEditor: View {
    @Bindable var child: Child
    @State private var shownInfo: PlanInfo?

    private let limits = FeedingProfile.CustomLimits.self

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
        VStack(spacing: 16) {
            // Полноширинные ряды: просто текст + пикер, без иконок.
            VStack(spacing: 6) {
                paramRow("Старт прикорма", info: .start,
                         value: $child.customStartAgeMonths, range: limits.startAge, unit: "мес")
                Divider()
                paramRow("Окно: обычный", info: .windowRegular,
                         value: $child.customObservationDaysRegular, range: limits.observation, unit: "дн")
                Divider()
                paramRow("Окно: аллерген", info: .windowAllergen,
                         value: $child.customObservationDaysAllergen, range: limits.observation, unit: "дн")
                Divider()
                paramRow("Частота аллергена", info: .frequency,
                         value: $child.customAllergenFrequencyPerWeek, range: limits.frequency, unit: "×/нед")
            }
            .cartoonCard()

            VStack(alignment: .leading, spacing: 12) {
                Text("Аллергены для ввода").font(.subheadline.bold())
                allergenGrid
                if child.customAllergenGroups.isEmpty {
                    Label("Не выбран ни один аллерген — трекер поддержки работать не будет.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .cartoonCard()
        }
    }

    // MARK: - Параметр: полноширинный ряд, значение тапается целиком

    private func paramRow(_ title: LocalizedStringKey, info: PlanInfo,
                          value: Binding<Int>, range: ClosedRange<Int>, unit: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.subheadline.weight(.medium))
            infoButton(info)
            Spacer(minLength: 8)
            Menu {
                Picker("", selection: value) {
                    ForEach(Array(range), id: \.self) { n in
                        valueText(n, unit).tag(n)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    valueText(value.wrappedValue, unit)
                        .font(.headline.bold()).monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.bold))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 4)
    }

    private func valueText(_ n: Int, _ unit: LocalizedStringKey) -> Text {
        Text("\(n) ") + Text(unit)
    }

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
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(AllergenGroup.allCases.filter { $0 != .other }, id: \.self) { group in
                allergenChip(group)
            }
        }
    }

    private func allergenChip(_ group: AllergenGroup) -> some View {
        let on = child.customAllergenGroups.contains(group)
        return Button {
            Haptics.select()
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
