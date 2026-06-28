import SwiftUI
import SwiftData

/// Гейт: нет ребёнка → онбординг; есть → основное приложение (SPEC §12).
struct RootView: View {
    @Query private var children: [Child]

    var body: some View {
        Group {
            if let child = children.first {
                MainTabView(child: child)
            } else {
                OnboardingView()
            }
        }
        .tint(Theme.accent)
        .fontDesign(.rounded)            // мультяшный скруглённый шрифт по всему приложению
        .preferredColorScheme(.light)    // палитра светлая и фиксированная — тёмную тему не поддерживаем
        .environment(\.locale, .ru)      // пока ru-only: даты/пикеры по-русски (снять при локализации)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Child.self, IntroductionStatus.self, FoodLog.self, CustomFood.self],
                        inMemory: true)
}
