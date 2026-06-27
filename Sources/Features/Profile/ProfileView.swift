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
                    if let url = URL(string: p.sourceURL) {
                        Link(destination: url) {
                            Label(p.source, systemImage: "doc.text.magnifyingglass")
                                .font(.footnote)
                        }
                    }
                    Text(p.caveat)
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("О приложении") {
                    Link(destination: AppLinks.privacyPolicyURL) {
                        Label("Политика конфиденциальности", systemImage: "lock.shield")
                    }
                    Link(destination: AppLinks.termsURL) {
                        Label("Условия использования", systemImage: "doc.text")
                    }
                    Link(destination: AppLinks.supportMailto) {
                        Label("Поддержка", systemImage: "envelope")
                    }
                    LabeledContent("Версия", value: Bundle.main.appVersion)
                }

                Section {
                    Text("⚠️ \(Disclaimer.medical)")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Иконки: OpenMoji (CC BY-SA 4.0)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Профиль")
            .onChange(of: child.feedingProfileId) {
                try? context.save()
                NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
            }
        }
    }
}
