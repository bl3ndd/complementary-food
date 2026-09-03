import SwiftUI
import SwiftData

/// Гейт: нет ребёнка → онбординг; есть → основное приложение (SPEC §12).
struct RootView: View {
    @Query private var children: [Child]
    @Query private var installs: [AppInstall]
    @Environment(\.modelContext) private var context
    @ObservedObject private var proStore = ProStore.shared
    /// Выбранная цветовая гамма. В отличие от языка применяется сразу.
    @AppStorage(Palette.storageKey) private var paletteId: String = Palette.pudding.id
    /// Оформление: система / светлая / тёмная (Профиль → Приложение). Применяется сразу.
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .system

    /// Право на Pro. Берём САМУЮ РАННЮЮ запись установки: дубли из CloudKit
    /// (их реально бывает больше одной) не должны отбирать обещанное.
    private var entitlements: Entitlements {
        Entitlements(install: installs.min(by: { $0.firstLaunchedAt < $1.firstLaunchedAt }),
                     purchased: proStore.isPurchased)
    }

    var body: some View {
        // Гамма применяется ДО отрисовки детей, поэтому смена видна сразу, без
        // перезапуска. Без права на Pro платная гамма молча откатывается на базовую.
        let _ = Theme.apply(Palette.allowed(id: paletteId, isPro: entitlements.isPro))

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
            await proStore.refresh()
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
