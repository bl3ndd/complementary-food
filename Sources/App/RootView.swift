import SwiftUI
import SwiftData

/// Гейт: нет ребёнка → онбординг; есть → основное приложение (SPEC §12).
struct RootView: View {
    @Query private var children: [Child]
    @Environment(\.modelContext) private var context
    /// Оформление: система / светлая / тёмная (Профиль → Приложение). Применяется сразу.
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

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
        .task {
            // Пишем «когда пришёл» с первого запуска — задним числом это уже
            // не восстановить, а на этом держится обещание ранним пользователям.
            EarlyAdopter(context: context).registerIfNeeded()
        }
        .tint(Theme.accent)
        .fontDesign(.rounded)            // мультяшный скруглённый шрифт по всему приложению
        // Палитра адаптивная (Theme.dynamic). По умолчанию идём за системой, но даём
        // зафиксировать: дневник ведут ночью, и «всегда тёмная» — законное желание.
        .preferredColorScheme(theme.colorScheme)
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Child.self, IntroductionStatus.self, FoodLog.self, LogPhoto.self, CustomFood.self],
                        inMemory: true)
}
