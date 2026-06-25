import SwiftUI
import SwiftData

/// Профиль ребёнка и настройки методики (SPEC §7).
struct ProfileView: View {
    @Bindable var child: Child
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Ребёнок") {
                    TextField("Имя", text: $child.name)
                    DatePicker("Дата рождения", selection: $child.birthDate,
                               in: ...Date(), displayedComponents: .date)
                    LabeledContent("Возраст", value: "\(child.ageInMonths) мес")
                }

                Section("Методика прикорма") {
                    Picker("Методика", selection: $child.feedingProfileId) {
                        ForEach(FeedingProfile.presets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    let p = child.feedingProfile
                    LabeledContent("Старт", value: "~\(p.startAgeMonths) мес")
                    LabeledContent("Окно наблюдения", value: "\(p.observationDays) дн")
                    LabeledContent("Аллерген", value: "\(p.allergenFrequencyPerWeek)×/нед")
                }

                Section {
                    Text("⚠️ Это не медицинский совет. Сроки введения продуктов и аллергенов согласуй с педиатром.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Иконки: OpenMoji (CC BY-SA 4.0)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .navigationTitle("Профиль")
            .onChange(of: child.feedingProfileId) {
                try? context.save()
                NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
            }
        }
    }
}
