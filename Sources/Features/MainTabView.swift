import SwiftUI

struct MainTabView: View {
    let child: Child

    var body: some View {
        TabView {
            DashboardView(child: child)
                .tabItem { Label("Сегодня", systemImage: "sun.max.fill") }

            CatalogView(child: child)
                .tabItem { Label("Каталог", systemImage: "list.bullet") }

            AllergensView(child: child)
                .tabItem { Label("Аллергены", systemImage: "exclamationmark.shield.fill") }

            ProfileView(child: child)
                .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
        }
    }
}
