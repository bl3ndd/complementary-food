import SwiftUI
import SwiftData
import UIKit
import UserNotifications

/// Профиль ребёнка и настройки (SPEC §7). Пять чётких областей по частоте:
/// Малыш → План → Приложение → Данные → О приложении → изолированный сброс.
struct ProfileView: View {
    @Bindable var child: Child
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var logs: [FoodLog]
    @Query private var statuses: [IntroductionStatus]

    @AppStorage("app.language") private var language: AppLanguage = .system
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var showResetConfirm = false
    @State private var showLanguageRestart = false
    @State private var shareFile: ShareableFile?
    @State private var showRecap = false
    @State private var isResetting = false

    private let catalog = FoodCatalog.shared

    var body: some View {
        NavigationStack {
            // Во время сброса снимаем всю форму: она биндит `child` ($name/$birthDate,
            // план), а resetAll его удаляет — рендер с удалённым @Model крашит.
            if isResetting {
                AppBackground()
            } else {
                profileForm
            }
        }
    }

    private var profileForm: some View {
        Form {
                childSection
                planSection
                appSection
                dataSection
                aboutSection
                dangerSection
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Профиль")
            .task {
                await loadNotifStatus()
                // Зажать параметры плана в допустимые границы (legacy/CloudKit-значения
                // вне диапазона иначе не подсветятся в пикере).
                let before = customSignature
                child.clampCustom()
                if customSignature != before { try? context.save() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await loadNotifStatus() } }
            }
            .onChange(of: customSignature) { persist() }
            .onChange(of: language) {
                LanguageManager.apply(language)
                showLanguageRestart = true
            }
            .sheet(item: $shareFile) { ActivityView(items: [$0.url]) }
            .sheet(isPresented: $showRecap) {
                RecapSheet(recap: RecapService(catalog: catalog, logs: logs)
                    .recap(for: Date(), childName: child.name, ageMonths: child.ageInMonths))
            }
            .alert("Сбросить все данные?", isPresented: $showResetConfirm) {
                Button("Сбросить", role: .destructive) { resetAll() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Удалятся профиль ребёнка, история кормлений и свои продукты. Действие необратимо — приложение вернётся к началу.")
            }
            .alert("Язык изменён", isPresented: $showLanguageRestart) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Перезапустите приложение, чтобы применить новый язык.")
            }
    }

    // MARK: - Малыш

    private var childSection: some View {
        Section("Малыш") {
            LabeledContent("Имя") {
                TextField("Имя малыша", text: $child.name)
                    .multilineTextAlignment(.trailing)
            }
            DatePicker("Дата рождения", selection: $child.birthDate,
                       in: ...Date(), displayedComponents: .date)
            LabeledContent("Возраст", value: String(localized: "\(child.ageInMonths) мес"))
        }
    }

    // MARK: - План прикорма (пуш)

    private var planSection: some View {
        Section("План прикорма") {
            CustomPlanEditor(child: child)
        }
    }

    // MARK: - Приложение (напоминания + язык)

    private var appSection: some View {
        Section {
            LabeledContent("Напоминания") {
                Text(notifStatusText)
                    .foregroundStyle(notifStatus == .authorized ? .green : .orange)
            }
            if notifStatus != .authorized {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Включить в настройках", systemImage: "bell.badge")
                }
            }
            Picker(selection: $language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.title).tag(lang)
                }
            } label: {
                Label("Язык", systemImage: "globe")
            }
        } header: {
            Text("Приложение")
        } footer: {
            Text("Напоминания держат введённые аллергены под контролем — без них трекер не сработает. Язык применяется после перезапуска.")
        }
    }

    // MARK: - Данные (экспорт / рекап / сброс живёт отдельно)

    private var dataSection: some View {
        Section("Данные") {
            Button { exportPDF(.pediatric) } label: {
                Label("Дневник для педиатра", systemImage: "doc.richtext")
            }
            .disabled(!hasActualLogs)

            Button { exportPDF(.avoid) } label: {
                Label("Список «не давать»", systemImage: "nosign")
            }
            .disabled(!hasAvoidItems)

            Button { showRecap = true } label: {
                Label("Рекап месяца", systemImage: "party.popper")
            }
            .disabled(!RecapService(catalog: catalog, logs: logs).hasData(for: Date()))
        }
    }

    // MARK: - О приложении (легалка + версия + кредиты в одном месте)

    private var aboutSection: some View {
        Section {
            Link(destination: AppLinks.supportMailto) {
                Label(String(localized: "support.link", defaultValue: "Поддержка"), systemImage: "envelope")
            }
            Link(destination: AppLinks.privacyPolicyURL) {
                Label("Политика конфиденциальности", systemImage: "lock.shield")
            }
            Link(destination: AppLinks.termsURL) {
                Label("Условия использования", systemImage: "doc.text")
            }
            Link(destination: AppLinks.methodologyInfoURL) {
                Label("Источники методики", systemImage: "book")
            }
            LabeledContent("Версия", value: Bundle.main.appVersion)
        } header: {
            Text("О приложении")
        } footer: {
            Text(Disclaimer.medical + "\n\n" + String(localized: "Иконки: OpenMoji (CC BY-SA 4.0)"))
                .font(.footnote)
        }
    }

    // MARK: - Опасная зона (изолирована, в самом низу)

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) { showResetConfirm = true } label: {
                Label("Сбросить все данные", systemImage: "trash")
            }
        } footer: {
            Text("Сначала выгрузите данные (Данные → Дневник для педиатра) — после сброса восстановить нельзя.")
        }
    }

    // MARK: - Действия

    private enum ExportKind { case pediatric, avoid }

    private func exportPDF(_ kind: ExportKind) {
        let export = DiaryPDFExport.make(child: child, logs: logs, statuses: statuses)
        let url = kind == .pediatric ? export.writeTempFile() : export.writeAvoidTempFile()
        if let url { shareFile = ShareableFile(url: url) }
    }

    private var hasAvoidItems: Bool {
        statuses.contains { $0.state == .paused || $0.state == .allergy }
    }

    /// Есть ли фактические (не запланированные) записи — PDF-дневник по фактам.
    private var hasActualLogs: Bool { logs.contains { !$0.planned } }

    /// Полный сброс: удаляем все данные → RootView покажет онбординг.
    private func resetAll() {
        // Сначала снимаем форму (её биндинги к child), потом на следующем тике удаляем
        // модели — иначе рендер формы поймает уже удалённый child.
        isResetting = true
        DispatchQueue.main.async {
            NotificationManager.shared.clearAll()
            // LogPhoto удаляем явно: bulk-delete FoodLog НЕ применяет cascade (иначе
            // фото остаются орфанами в сторе/CloudKit навсегда).
            try? context.delete(model: LogPhoto.self)
            try? context.delete(model: FoodLog.self)
            try? context.delete(model: IntroductionStatus.self)
            try? context.delete(model: CustomFood.self)
            try? context.delete(model: Child.self)
            try? context.save()
            FoodCatalog.setCustom([])
            // Дисклеймер-гейт сбрасывается в конце нового онбординга (OnboardingView.finish),
            // а не здесь — иначе он мигает на ещё живом MainTabView во время сноса.
        }
    }

    private var notifStatusText: String {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return String(localized: "Включены")
        case .denied:                               return String(localized: "Выключены")
        default:                                    return String(localized: "Не запрошены")
        }
    }

    @MainActor private func loadNotifStatus() async {
        notifStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Подпись custom-параметров — чтобы сохранять/перепланировать при правке плана.
    private var customSignature: String {
        "\(child.customStartAgeMonths)/\(child.customObservationDaysRegular)/\(child.customObservationDaysAllergen)/\(child.customAllergenFrequencyPerWeek)/\(child.customAllergenGroupsRaw)"
    }

    private func persist() {
        try? context.save()
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
    }
}
