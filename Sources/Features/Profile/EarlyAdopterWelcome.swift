import SwiftUI

/// Разовое приветствие после обновления: ранним пользователям Pro открыт молча,
/// и без этого экрана они бы просто не узнали, что получили его навсегда.
enum EarlyAdopterWelcome {
    static let shownKey = "pro.earlyWelcomeShown"

    /// Только ранним и только если Pro не куплен — купившему «бесплатно, без
    /// покупки» прозвучало бы странно.
    static func shouldShow(_ entitlements: Entitlements, alreadyShown: Bool) -> Bool {
        !alreadyShown && entitlements.isEarlyAdopter && !entitlements.purchased
    }
}

struct EarlyAdopterWelcomeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Mascot(mood: .cheer, size: 92)
                        Text("Pro теперь твой")
                            .font(.title3.weight(.bold))
                        Text("Ты пользуешься Pudding с первой версии, поэтому Pro открыт тебе навсегда — бесплатно, без покупки.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    ProPerkList()

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Как добавить виджет", systemImage: "square.grid.2x2")
                            .font(.subheadline.weight(.bold))
                        Text("Удержи палец на пустом месте домашнего экрана → «Изменить» → «Добавить виджет» → Pudding.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .cartoonCard()

                    BigButton(title: "Отлично") { dismiss() }
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Pudding Pro")
            .navigationBarTitleDisplayMode(.inline)
        }
        .cozySheet()
    }
}
