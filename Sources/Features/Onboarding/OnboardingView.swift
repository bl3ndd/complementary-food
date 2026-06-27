import SwiftUI
import SwiftData

/// Онбординг (SPEC §12): Welcome → Дисклеймер → Ребёнок → Методика → Готово.
/// Пуши тут НЕ просим — контекстно при вводе первого аллергена.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var acceptedDisclaimer = false
    @State private var name = ""
    @State private var birthDate = Calendar.current.date(byAdding: .month, value: -5, to: Date()) ?? Date()
    @State private var profileId = FeedingProfile.who.id

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
            button
        }
        .padding()
        .multilineTextAlignment(.center)
        .background(AppBackground())
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0:
            stepView(title: "Pudding",
                     text: "Дневник прикорма без паники: что вводить, когда и не забыть про аллергены.")
        case 1:
            disclaimerStep
        case 2:
            childStep
        default:
            methodologyStep
        }
    }

    private func stepView(title: String, text: String) -> some View {
        VStack(spacing: 16) {
            haloMascot(.happy)
            Text(title).font(.largeTitle.bold())
            Text(text).foregroundStyle(.secondary).padding(.horizontal)
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

    private var disclaimerStep: some View {
        VStack(spacing: 16) {
            haloMascot(.worried, color: Theme.sunny)
            Text("Важно").font(.title.bold())
            Text(Disclaimer.medical)
                .foregroundStyle(.secondary)
            Toggle("Понятно, беру ответственность на себя", isOn: $acceptedDisclaimer)
                .padding(.top)
                .padding(.horizontal)
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
        VStack(spacing: 16) {
            haloMascot(.neutral, color: Theme.mint)
            Text("Методика прикорма").font(.title.bold())
            Text("Можно сменить позже в профиле.").font(.footnote).foregroundStyle(.secondary)
            ForEach(FeedingProfile.presets) { preset in
                Button {
                    profileId = preset.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name).font(.headline)
                            Text("Старт ~\(preset.startAgeMonths) мес · аллерген \(preset.allergenFrequencyPerWeek)×/нед")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if profileId == preset.id {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                        }
                    }
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(profileId == preset.id ? Theme.accent : Color.clear, lineWidth: 2.5)
                    )
                    .shadow(color: Theme.accentDeep.opacity(0.10), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var button: some View {
        Button(action: next) {
            Text(step >= 3 ? "Погнали! 🚀" : "Далее")
                .font(.headline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background {
                    if canProceed {
                        Theme.accentGradient
                    } else {
                        Color.gray.opacity(0.5)
                    }
                }
                .clipShape(Capsule())
                .shadow(color: Theme.accent.opacity(canProceed ? 0.35 : 0), radius: 10, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!canProceed)
    }

    private var canProceed: Bool {
        switch step {
        case 1:  return acceptedDisclaimer
        default: return true
        }
    }

    private func next() {
        if step >= 3 {
            finish()
        } else {
            withAnimation { step += 1 }
        }
    }

    private func finish() {
        let child = Child(name: name, birthDate: birthDate, feedingProfileId: profileId)
        context.insert(child)
        try? context.save()
    }
}
