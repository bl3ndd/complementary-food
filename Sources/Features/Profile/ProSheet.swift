import SwiftUI

/// Экран покупки Pro.
///
/// Разовая покупка, не подписка — поэтому никакого «отменить в любой момент»,
/// сроков и мелкого шрифта про автопродление. Оформление спокойное: список
/// возможностей системными символами, один акцент, много воздуха.
struct ProSheet: View {
    let entitlements: Entitlements

    @ObservedObject private var store = ProStore.shared
    @Environment(\.dismiss) private var dismiss

    private struct Perk: Identifiable {
        let id = UUID()
        let icon: String
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
    }

    private let perks = [
        Perk(icon: "square.stack.3d.down.right",
             title: "Рекап-карусель",
             subtitle: "Коллекция, вехи, первый раз, топ вкусов — карточками для сторис"),
        Perk(icon: "paintpalette",
             title: "Цветовые гаммы",
             subtitle: "Шесть палитр, и они же красят карточки, которыми делишься"),
        Perk(icon: "app.badge",
             title: "Иконки приложения",
             subtitle: "Своя иконка на домашнем экране"),
        Perk(icon: "square.grid.2x2",
             title: "Виджет «Коллекция»",
             subtitle: "Растущая сетка продуктов прямо на домашнем экране"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    perkList
                    if entitlements.isPro { openState } else { buyBlock }
                    legal
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Pudding Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
            }
        }
        .cozySheet()
        .task { await store.refresh() }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Mascot(mood: .cheer, size: 92)
            Text("Дневник остаётся бесплатным")
                .font(.title3.weight(.bold)).multilineTextAlignment(.center)
            Text("Pro добавляет приятное: карточки, гаммы, иконки и виджет. Записи, аллергены, календарь, синхронизация и PDF для педиатра — всегда бесплатно.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var perkList: some View {
        VStack(spacing: 16) {
            ForEach(perks) { perk in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: perk.icon)
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(perk.title).font(.subheadline.weight(.bold))
                        Text(perk.subtitle).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .cartoonCard()
    }

    /// У раннего пользователя Pro уже открыт — и он должен это видеть без всяких
    /// «восстановить покупки». Обещание исполняется молча.
    private var openState: some View {
        VStack(spacing: 10) {
            Label("Pro открыт", systemImage: "checkmark.seal.fill")
                .font(.headline).foregroundStyle(Theme.accent)
            if !entitlements.purchased {
                Text("Ты пришёл в самом начале — Pro твой навсегда, платить не нужно.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .cartoonCard()
    }

    private var buyBlock: some View {
        VStack(spacing: 12) {
            if let error = store.lastError {
                Text(error).font(.footnote).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            BigButton(title: buyTitle) {
                Task { await store.buy() }
            }
            .disabled(store.isLoading || store.product == nil)

            Text("Разовая покупка, не подписка")
                .font(.caption).foregroundStyle(.secondary)

            Button("Восстановить покупки") {
                Task { await store.restore() }
            }
            .font(.footnote)
            .disabled(store.isLoading)
        }
    }

    /// Пока витрина не загрузилась, цену не выдумываем — она задаётся в App Store
    /// Connect и различается по территориям.
    private var buyTitle: LocalizedStringKey {
        if let price = store.product?.displayPrice {
            return "Открыть Pro · \(price)"
        }
        return "Открыть Pro"
    }

    private var legal: some View {
        HStack(spacing: 16) {
            Link("Условия использования", destination: AppLinks.termsURL)
            Link("Политика конфиденциальности", destination: AppLinks.privacyPolicyURL)
        }
        .font(.caption2).foregroundStyle(.secondary)
        .padding(.bottom, 8)
    }
}
