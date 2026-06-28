import SwiftUI
import SwiftData

/// Онбординг (SPEC §12): Welcome → Ребёнок → Методика. Медицинский дисклеймер —
/// в Профиле (секция «Важно»). Пуши тут НЕ просим — контекстно при первом аллергене.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var name = ""
    @State private var birthDate = Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date()
    /// Черновик для настроек «своего плана» (вставляется в контекст только в finish).
    @State private var draftChild = Child()

    private let lastStep = 2

    var body: some View {
        VStack(spacing: 16) {
            Group {
                switch step {
                case 0:  centered(welcomeStep)
                case 1:  centered(childStep)
                default: planStep
                }
            }
            .frame(maxHeight: .infinity)
            button
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

                CustomPlanEditor(child: draftChild)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 3)
        }
        .scrollIndicators(.hidden)
    }

    /// Маскот-гид в мягком цветном круге.
    private func haloMascot(_ mood: MascotMood, color: Color = Theme.accent) -> some View {
        Mascot(mood: mood, size: 96)
            .frame(width: 132, height: 132)
            .background(Theme.softGradient(color), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1.5))
            .shadow(color: color.opacity(0.25), radius: 16, y: 8)
    }

    // MARK: - Кнопка / переходы

    /// На шаге «О ребёнке» имя обязательно.
    private var canProceed: Bool {
        step != 1 || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var button: some View {
        Button(action: next) {
            Text(step >= lastStep ? String(localized: "Погнали! 🚀") : String(localized: "Далее"))
                .font(.headline.bold())
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
        let child = Child(name: name.trimmingCharacters(in: .whitespaces),
                          birthDate: birthDate, feedingProfileId: FeedingProfile.customId)
        child.customStartAgeMonths = draftChild.customStartAgeMonths
        child.customObservationDaysRegular = draftChild.customObservationDaysRegular
        child.customObservationDaysAllergen = draftChild.customObservationDaysAllergen
        child.customAllergenFrequencyPerWeek = draftChild.customAllergenFrequencyPerWeek
        child.customAllergenGroupsRaw = draftChild.customAllergenGroupsRaw
        child.clampCustom()
        context.insert(child)
        try? context.save()
    }
}
