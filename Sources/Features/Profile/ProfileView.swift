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
                        Text("Свой план").tag(FeedingProfile.customId)
                    }
                }

                Section {
                    MethodologyCard(profile: child.feedingProfile, expanded: true)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    if child.feedingProfileId == FeedingProfile.customId {
                        CustomPlanEditor(child: child)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
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
            .onChange(of: child.feedingProfileId) { persist() }
            .onChange(of: customSignature) { persist() }
        }
    }

    /// Подпись custom-параметров — чтобы реагировать на правки своего плана.
    private var customSignature: String {
        "\(child.customStartAgeMonths)/\(child.customObservationDays)/\(child.customAllergenFrequencyPerWeek)/\(child.customAllergenGroupsRaw)"
    }

    private func persist() {
        try? context.save()
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
    }
}
