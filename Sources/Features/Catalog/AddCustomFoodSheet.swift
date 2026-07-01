import SwiftUI
import SwiftData

/// Добавление своего продукта (категория «Другое»): название, иконка-эмодзи из
/// сетки, возраст. Сохраняет `CustomFood` и обновляет реестр каталога.
struct AddCustomFoodSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = CustomFoodIcons.options.first?.emoji ?? "🍎"
    @State private var minAge = 6
    @State private var isAllergen = false

    private let columns = [GridItem(.adaptive(minimum: 50), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    preview
                    nameCard
                    emojiCard
                    ageCard
                    allergenCard
                    BigButton(title: "Добавить") { save() }
                        .padding(.top, 4)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Свой продукт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 8) {
            OpenMojiIcon(asset: CustomFoodIcons.asset(for: emoji) ?? "", fallback: emoji, size: 52)
                .frame(width: 84, height: 84)
                .background(Theme.softGradient(Theme.lilac),
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.6), lineWidth: 1))
            Text(name.isEmpty ? String(localized: "Название") : name)
                .font(.headline)
                .foregroundStyle(name.isEmpty ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Название").font(.subheadline.bold())
            TextField("Например: компот", text: $name)
                .padding(12)
                .background(Color.black.opacity(0.03),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .cartoonCard()
    }

    private var emojiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Иконка").font(.subheadline.bold())
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(CustomFoodIcons.options, id: \.code) { opt in
                    Button { emoji = opt.emoji } label: {
                        OpenMojiIcon(asset: "pick_\(opt.code)", fallback: opt.emoji, size: 30)
                            .frame(width: 50, height: 50)
                            .background(emoji == opt.emoji ? Theme.accent.opacity(0.16) : Color.black.opacity(0.03),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(emoji == opt.emoji ? Theme.accent : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cartoonCard()
    }

    private var allergenCard: some View {
        Toggle(isOn: $isAllergen) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Это аллерген").font(.subheadline.weight(.medium))
                Text("Пометим как аллерген и будем осторожнее при вводе.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .tint(Theme.accent)
        .cartoonCard()
    }

    private var ageCard: some View {
        Stepper(value: $minAge, in: 4...18) {
            HStack {
                Text("С какого возраста").font(.subheadline.weight(.medium))
                Spacer()
                Text("\(minAge) мес").font(.subheadline.bold()).foregroundStyle(Theme.accent)
            }
        }
        .cartoonCard()
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let food = CustomFood(name: trimmed, emoji: emoji,
                              minAgeMonths: minAge, isAllergen: isAllergen)
        context.insert(food)
        try? context.save()
        let all = (try? context.fetch(FetchDescriptor<CustomFood>())) ?? []
        FoodCatalog.setCustom(all)
        // Свой продукт — сразу в коллекцию: помечаем введённым (ты его добавил — он «твой»).
        // markIntroduced НЕ создаёт запись в дневнике, только статус.
        FeedingService(context: context).markIntroduced([food.asFood])
        dismiss()
    }
}
