import SwiftUI
import SwiftData

/// Онбординг (SPEC §12): Welcome → Ребёнок → Методика. Дисклеймер смягчён —
/// мягкая сноска на welcome, полный текст в «О приложении». Пуши тут НЕ просим —
/// контекстно при вводе первого аллергена.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var name = ""
    @State private var birthDate = Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date()
    @State private var profileId = FeedingProfile.who.id
    /// Черновик для настроек «своего плана» (вставляется в контекст только в finish).
    @State private var draftChild = Child()

    private let lastStep = 2

    var body: some View {
        VStack(spacing: 16) {
            Group {
                switch step {
                case 0:  centered(welcomeStep)
                case 1:  centered(childStep)
                default: methodologyStep
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
            Text(Disclaimer.welcome)
                .font(.caption2).foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
    }

    private var childStep: some View {
        VStack(spacing: 16) {
            haloMascot(.curious, color: Theme.sky)
            Text("О ребёнке").font(.title.bold())
            Form {
                TextField("Имя (необязательно)", text: $name)
                DatePicker("Дата рождения", selection: $birthDate,
                           in: ...Date(), displayedComponents: .date)
            }
            .frame(height: 140)
            .scrollContentBackground(.hidden)
        }
    }

    private var methodologyStep: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Методика прикорма").font(.title2.bold())
                Text("Выбери готовую или собери свой план. Можно сменить позже.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ForEach(FeedingProfile.presets) { preset in
                    MethodologyCard(profile: preset, selected: profileId == preset.id) {
                        withAnimation(.snappy) { profileId = preset.id }
                    }
                }

                MethodologyCard(profile: FeedingProfile.custom(from: draftChild),
                                selected: profileId == FeedingProfile.customId) {
                    withAnimation(.snappy) { profileId = FeedingProfile.customId }
                }

                if profileId == FeedingProfile.customId {
                    CustomPlanEditor(child: draftChild)
                }
            }
            .padding(.vertical, 8)
        }
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

    private var button: some View {
        Button(action: next) {
            Text(step >= lastStep ? "Погнали! 🚀" : "Далее")
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Theme.accentGradient)
                .clipShape(Capsule())
                .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func next() {
        if step >= lastStep {
            finish()
        } else {
            withAnimation { step += 1 }
        }
    }

    private func finish() {
        let child = Child(name: name, birthDate: birthDate, feedingProfileId: profileId)
        if profileId == FeedingProfile.customId {
            child.customStartAgeMonths = draftChild.customStartAgeMonths
            child.customObservationDays = draftChild.customObservationDays
            child.customAllergenFrequencyPerWeek = draftChild.customAllergenFrequencyPerWeek
            child.customAllergenGroupsRaw = draftChild.customAllergenGroupsRaw
            child.clampCustom()
        }
        context.insert(child)
        try? context.save()
    }
}
