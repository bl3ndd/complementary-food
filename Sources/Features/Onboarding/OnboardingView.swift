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
            stepView(emoji: "🍼", title: "Дневник прикорма",
                     text: "Поможем ввести прикорм без паники: что вводить, когда и не забыть про аллергены.")
        case 1:
            disclaimerStep
        case 2:
            childStep
        default:
            methodologyStep
        }
    }

    private func stepView(emoji: String, title: String, text: String) -> some View {
        VStack(spacing: 16) {
            Text(emoji).font(.system(size: 72))
            Text(title).font(.largeTitle.bold())
            Text(text).foregroundStyle(.secondary).padding(.horizontal)
        }
    }

    private var disclaimerStep: some View {
        VStack(spacing: 16) {
            Text("⚠️").font(.system(size: 64))
            Text("Важно").font(.title.bold())
            Text("Это не медицинский совет. Сроки введения продуктов и аллергенов обязательно согласуй с педиатром.")
                .foregroundStyle(.secondary)
            Toggle("Понятно, беру ответственность на себя", isOn: $acceptedDisclaimer)
                .padding(.top)
                .padding(.horizontal)
        }
    }

    private var childStep: some View {
        VStack(spacing: 16) {
            Text("👶").font(.system(size: 64))
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
            Text("📋").font(.system(size: 64))
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
                    .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(profileId == preset.id ? Theme.accent : .clear, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var button: some View {
        Button(action: next) {
            Text(step >= 3 ? "Погнали!" : "Далее")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProceed ? Color.accentColor : Color.gray,
                            in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
        }
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
