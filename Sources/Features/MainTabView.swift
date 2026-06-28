import SwiftUI
import SwiftData

struct MainTabView: View {
    let child: Child
    @Environment(\.modelContext) private var context
    @State private var tab: Tab = .today

    enum Tab { case today, catalog, calendar, profile }

    var body: some View {
        tabs
            .task {
                // Подмешиваем свои продукты в каталог (для истории/календаря).
                let customs = (try? context.fetch(FetchDescriptor<CustomFood>())) ?? []
                FoodCatalog.setCustom(customs)
                // Держим расписание напоминаний в актуальном виде при запуске.
                NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
            }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            DashboardView(child: child, goToCatalog: { tab = .catalog })
                .tabItem { Label("Сегодня", systemImage: "sun.max.fill") }
                .tag(Tab.today)

            CatalogView(child: child)
                .tabItem { Label("Каталог", systemImage: "list.bullet") }
                .tag(Tab.catalog)

            CalendarView()
                .tabItem { Label("Календарь", systemImage: "calendar") }
                .tag(Tab.calendar)

            ProfileView(child: child)
                .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
    }
}
