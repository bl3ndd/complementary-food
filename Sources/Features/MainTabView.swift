import SwiftUI
import SwiftData

struct MainTabView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @Query private var statuses: [IntroductionStatus]
    @Query private var logs: [FoodLog]
    @ObservedObject private var router = AppRouter.shared
    @AppStorage("disclaimer.acknowledged") private var disclaimerAcked = false

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
                // Держим расписание напоминаний в актуальном виде при запуске.
                NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
            }
            .sheet(isPresented: Binding(get: { !disclaimerAcked },
                                        set: { if !$0 { disclaimerAcked = true } })) {
                DisclaimerGateSheet { disclaimerAcked = true }
            }
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

/// Одноразовый дисклеймер при первом входе в приложение (App Review 1.4.1 / страховка).
/// Не совет — а явное «мы только дневник, решения с педиатром».
private struct DisclaimerGateSheet: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 56)).foregroundStyle(Theme.accent)
            Text("Прежде чем начать").font(.title2.bold())
            Text(Disclaimer.medical)
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            BigButton(title: "Понятно") { onAccept() }
        }
        .padding(28)
        .background(AppBackground())
        .interactiveDismissDisabled()
    }
}
