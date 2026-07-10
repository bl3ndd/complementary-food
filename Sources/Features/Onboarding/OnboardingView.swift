import SwiftUI
import SwiftData

/// Онбординг (SPEC §12): Welcome → Ребёнок → Методика. Медицинский дисклеймер —
/// в Профиле (секция «Важно»). Пуши тут НЕ просим — сразу после дисклеймер-гейта.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var name = ""
    @State private var birthDate = Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date()
    /// Черновик для настроек «своего плана» (вставляется в контекст только в finish).
    @State private var draftChild = Child()
    /// id продуктов, уже введённых до начала работы с приложением (п.23).
    @State private var introduced: Set<String> = []

    private let catalog = FoodCatalog.shared
    private let lastStep = 3

    var body: some View {
        VStack(spacing: 16) {
            Group {
                switch step {
                case 0:  centered(welcomeStep)
                case 1:  centered(childStep)
                case 2:  planStep
                default: alreadyStep
                }
            }
            .frame(maxHeight: .infinity)
            button
            if step > 0 {
                Button("Назад") { withAnimation { step -= 1 } }
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(AppBackground())
    }

    private func centered<V: View>(_ view: V) -> some View {
        VStack {
            Spacer(minLength: 0)
            view.multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Шаги

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            haloMascot(.happy)
            Text("Pudding").font(.largeTitle.bold())
            Text("Дневник прикорма без паники: что вводить, когда и не забыть про аллергены.")
                .foregroundStyle(.secondary).padding(.horizontal)
        }
    }

    private var childStep: some View {
        VStack(spacing: 16) {
            haloMascot(.curious, color: Theme.sky)
            Text("О ребёнке").font(.title.bold())
            VStack(spacing: 4) {
                TextField("Имя малыша", text: $name)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.vertical, 12)
                Divider()
                HStack {
                    Text("Дата рождения").foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: $birthDate, in: ...Date(),
                               displayedComponents: .date)
                        .labelsHidden()
                }
                .padding(.vertical, 6)
            }
            .cartoonCard()
        }
    }

    private var planStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Свой план прикорма").font(.title2.bold())
                Text("Настрой старт, окна наблюдения и аллергены. Можно изменить позже.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                PlanDetailEditor(child: draftChild)
            }
            .padding(.top, 28)
            .padding(.bottom, 8)
            .padding(.horizontal, 3)
        }
        .scrollIndicators(.hidden)
    }

    private var alreadyStep: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Что уже ввели?").font(.title2.bold())
                Text("Отметь продукты, которые малыш уже пробовал без проблем. Можно пропустить.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(catalog.foods) { food in introducedChip(food) }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 3)
        }
        .scrollIndicators(.hidden)
    }

    private func introducedChip(_ food: Food) -> some View {
        let on = introduced.contains(food.id)
        return Button {
            Haptics.select()
            withAnimation(.snappy) {
                if on { introduced.remove(food.id) } else { introduced.insert(food.id) }
            }
        } label: {
            HStack(spacing: 8) {
                FoodIcon(food: food, size: 32)
                Text(food.localizedName).font(.subheadline.weight(.semibold))
                    .foregroundStyle(on ? Theme.accent : .primary).lineLimit(1)
                Spacer(minLength: 0)
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote).foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(on ? Theme.accent.opacity(0.14) : Color.black.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(on ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    /// Маскот-гид в мягком цветном круге.
    private func haloMascot(_ mood: MascotMood, color: Color = Theme.accent) -> some View {
        Mascot(mood: mood, size: 96)
            .gentleBob()
            .frame(width: 132, height: 132)
            .background(Theme.softGradient(color), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
            .shadow(color: color.opacity(0.25), radius: 16, y: 8)
    }

    // MARK: - Кнопка / переходы

    /// Имя необязательно (SPEC §12) — двигаться можно всегда.
    private var canProceed: Bool { true }

    private var button: some View {
        Button(action: next) {
            HStack(spacing: 8) {
                Text(step >= lastStep ? String(localized: "Погнали!") : String(localized: "Далее"))
                    .font(.headline.bold())
                if step >= lastStep {
                    OpenMojiIcon(asset: "ui_rocket", fallback: "🚀", size: 22)
                }
            }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background {
                    if canProceed { Theme.accentGradient } else { Color.gray.opacity(0.4) }
                }
                .clipShape(Capsule())
                .shadow(color: Theme.accent.opacity(canProceed ? 0.35 : 0), radius: 10, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!canProceed)
    }

    private func next() {
        if step >= lastStep {
            finish()
        } else {
            withAnimation { step += 1 }
        }
    }

    private func finish() {
        // Новый онбординг = свежий старт: дисклеймер-гейт должен всплыть снова (в т.ч.
        // после сброса). Чистим ДО создания Child — гейт всплывёт на свежем MainTabView,
        // без мигания на старом. На первой установке флаг и так false — no-op.
        UserDefaults.standard.removeObject(forKey: "disclaimer.acknowledged")
        let child = Child(name: name.trimmingCharacters(in: .whitespaces),
                          birthDate: birthDate, feedingProfileId: FeedingProfile.customId)
        child.customStartAgeMonths = draftChild.customStartAgeMonths
        child.customObservationDaysRegular = draftChild.customObservationDaysRegular
        child.customObservationDaysAllergen = draftChild.customObservationDaysAllergen
        child.customAllergenFrequencyPerWeek = draftChild.customAllergenFrequencyPerWeek
        child.customAllergenGroupsRaw = draftChild.customAllergenGroupsRaw
        child.clampCustom()
        context.insert(child)
        if !introduced.isEmpty {
            let foods = introduced.compactMap { catalog.food(id: $0) }
            FeedingService(context: context).markIntroduced(foods)
        }
        try? context.save()
    }
}
