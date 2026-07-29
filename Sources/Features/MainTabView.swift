import SwiftUI
import SwiftData

struct MainTabView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var logs: [FoodLog]
    @ObservedObject private var router = AppRouter.shared
    @Environment(\.scenePhase) private var scenePhase

    enum Tab { case today, catalog, calendar, allergens, profile }

    /// Сколько аллергенов «пора освежить» — для бейджа на табе.
    private var dueCount: Int {
        AllergenMaintenance(catalog: .shared, profile: child.feedingProfile,
                            statuses: statuses, logs: logs).dueForDashboard().count
    }

    var body: some View {
        tabs
            .task {
                // Подмешиваем свои продукты в каталог (для истории/календаря).
                let customs = (try? context.fetch(FetchDescriptor<CustomFood>())) ?? []
                FoodCatalog.setCustom(customs)
                // Разрешение на уведомления просим сразу после онбординга:
                // ensureAuthorized промптит только в notDetermined, т.е. один раз.
                await NotificationManager.shared.ensureAuthorized()
                // Окно наблюдения закрывается само (кнопки «Ввёл успешно» нет),
                // поэтому при каждом запуске догоняем то, что дозрело, пока
                // приложение было закрыто.
                syncIntroductions()
            }
            .onChange(of: scenePhase) { _, phase in
                // И при возврате из фона: день мог смениться.
                if phase == .active { syncIntroductions() }
            }
    }

    /// Закрывает дозревшие окна наблюдения и переставляет напоминания.
    /// Заодно разово подтягивает план на новые дефолты окон (2/3), если юзер
    /// их не менял руками.
    private func syncIntroductions() {
        if PlanMigration.ObservationWindowsV2.apply(to: child) {
            try? context.save()
        }
        FeedingService(context: context).completeDueIntroductions(profile: child.feedingProfile)
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
    }

    private var tabs: some View {
        TabView(selection: $router.selectedTab) {
            DashboardView(child: child, goToCatalog: { router.selectedTab = .catalog })
                .tabItem { Label("Сегодня", systemImage: "sun.max.fill") }
                .tag(Tab.today)

            CatalogView(child: child)
                .tabItem { Label("Каталог", systemImage: "list.bullet") }
                .tag(Tab.catalog)

            CalendarView()
                .tabItem { Label("Календарь", systemImage: "calendar") }
                .tag(Tab.calendar)

            NavigationStack {
                AllergensView(child: child)
                    .background(AppBackground())
                    .navigationTitle("Аллергены")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Аллергены", systemImage: "exclamationmark.shield.fill") }
            .tag(Tab.allergens)
            .badge(dueCount)

            ProfileView(child: child)
                .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
    }
}

