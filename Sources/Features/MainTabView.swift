import SwiftUI

struct MainTabView: View {
    let child: Child
    @Environment(\.modelContext) private var context

    var body: some View {
        tabs
            .task {
                // Держим расписание напоминаний в актуальном виде при запуске.
                NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
            }
    }

    private var tabs: some View {
        TabView {
            DashboardView(child: child)
                .tabItem { Label("Сегодня", systemImage: "sun.max.fill") }

            CatalogView(child: child)
                .tabItem { Label("Каталог", systemImage: "list.bullet") }

            CalendarView()
                .tabItem { Label("Календарь", systemImage: "calendar") }

            ProfileView(child: child)
                .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
        }
    }
}
