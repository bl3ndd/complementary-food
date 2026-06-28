import SwiftUI
import SwiftData

/// Профиль ребёнка и настройки методики (SPEC §7).
struct ProfileView: View {
    @Bindable var child: Child
    @Environment(\.modelContext) private var context
    @State private var showResetConfirm = false

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
                        ForEach(FeedingProfile.visiblePresets()) { preset in
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
                    Button(role: .destructive) { showResetConfirm = true } label: {
                        Label("Сбросить все данные", systemImage: "trash")
                    }
                }

                Section("Важно") {
                    Label {
                        Text(Disclaimer.medical)
                            .font(.footnote).foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Text("Иконки: OpenMoji (CC BY-SA 4.0)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Профиль")
            .onChange(of: child.feedingProfileId) { persist() }
            .onChange(of: customSignature) { persist() }
            .alert("Сбросить все данные?", isPresented: $showResetConfirm) {
                Button("Сбросить", role: .destructive) { resetAll() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Удалятся профиль ребёнка, история кормлений и свои продукты. Действие необратимо — приложение вернётся к началу.")
            }
        }
    }

    /// Полный сброс: удаляем все данные → RootView покажет онбординг.
    private func resetAll() {
        NotificationManager.shared.clearAll()
        try? context.delete(model: FoodLog.self)
        try? context.delete(model: IntroductionStatus.self)
        try? context.delete(model: CustomFood.self)
        try? context.delete(model: Child.self)
        try? context.save()
        FoodCatalog.setCustom([])
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
