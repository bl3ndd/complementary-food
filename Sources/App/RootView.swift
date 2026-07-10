import SwiftUI
import SwiftData

/// Гейт: нет ребёнка → онбординг; есть → основное приложение (SPEC §12).
struct RootView: View {
    @Query private var children: [Child]

    var body: some View {
        Group {
            if let child = children.first {
                MainTabView(child: child)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        // Мягкий кроссфейд онбординг ↔ приложение (финиш онбординга / сброс данных).
        .animation(.easeInOut(duration: 0.45), value: children.isEmpty)
        .tint(Theme.accent)
        .fontDesign(.rounded)            // мультяшный скруглённый шрифт по всему приложению
        .preferredColorScheme(.light)    // палитра светлая и фиксированная — тёмную тему не поддерживаем
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Child.self, IntroductionStatus.self, FoodLog.self, LogPhoto.self, CustomFood.self],
                        inMemory: true)
}
