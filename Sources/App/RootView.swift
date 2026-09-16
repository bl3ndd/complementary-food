import SwiftUI
import UIKit
import SwiftData

/// Гейт: нет ребёнка → онбординг; есть → основное приложение (SPEC §12).
struct RootView: View {
    @Query private var children: [Child]
    @Query private var installs: [AppInstall]
    @Environment(\.modelContext) private var context
    @ObservedObject private var proStore = ProStore.shared
    /// Выбранная цветовая гамма. В отличие от языка применяется сразу.
    @AppStorage(Palette.storageKey) private var paletteId: String = Palette.pudding.id
    /// Какой ребёнок открыт. Состояние устройства, а не данные — в стор не кладём.
    @AppStorage(ActiveChild.storageKey) private var activeChildId: String = ""
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
        let appliedPalette = Theme.palette.id

        Group {
            if let child = ActiveChild.resolve(children: children, storedId: activeChildId) {
                MainTabView(child: child)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        // `Theme.*` — обычные статики, SwiftUI не умеет за ними следить. Без этого
        // смена гаммы доходила только до того, что читает `.tint` из окружения
        // (системные кнопки, тумблеры, таббар), а всё, что рисуется через
        // `Theme.accent` напрямую — карточки, кнопки, акцентный текст, — оставалось
        // на старой гамме, пока конкретная вьюха случайно не перерисуется. Смена
        // идентичности пересобирает дерево целиком. Меняется только когда гамма
        // РЕАЛЬНО применилась: попытка выбрать платную без Pro дерево не трогает.
        .id(appliedPalette)
        // Мягкий кроссфейд онбординг ↔ приложение (финиш онбординга / сброс данных).
        .animation(.easeInOut(duration: 0.45), value: children.isEmpty)
        .task {
            // Пишем «когда пришёл» с первого запуска — задним числом это уже
            // не восстановить, а на этом держится обещание ранним пользователям.
            EarlyAdopter(context: context).registerIfNeeded()
            await proStore.refresh()
        }
        .tint(Theme.accent)
        // Алерты и диалоги — это UIKit, SwiftUI-шный `.tint` до них не доходит, и без
        // тинта окна они красились в системный синий. Ассета AccentColor в проекте
        // нет намеренно: он статичный, а цвет зависит от выбранной гаммы.
        .onAppear { applyWindowTint() }
        .onChange(of: appliedPalette) { _, _ in applyWindowTint() }
        .fontDesign(.rounded)            // мультяшный скруглённый шрифт по всему приложению
        // Палитра адаптивная (Theme.dynamic). По умолчанию идём за системой, но даём
        // зафиксировать: дневник ведут ночью, и «всегда тёмная» — законное желание.
        .preferredColorScheme(theme.colorScheme)
    }
}

extension RootView {
    /// Тинт окна под текущую гамму — для UIKit-частей (алерты, диалоги).
    private func applyWindowTint() {
        let tint = UIColor(Theme.accent)
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows { window.tintColor = tint }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Child.self, IntroductionStatus.self, FoodLog.self, LogPhoto.self, CustomFood.self],
                        inMemory: true)
}
