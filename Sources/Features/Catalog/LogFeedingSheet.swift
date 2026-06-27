import SwiftUI
import SwiftData

/// Лист записи кормления: вкусовая оценка + реакция + заметка (SPEC §5).
/// Мультяшный стиль: карточки, крупные эмодзи-кнопки, фирменная кнопка сохранения.
struct LogFeedingSheet: View {
    let food: Food
    let child: Child

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var liking: Liking?
    @State private var reaction: ReactionType = .none
    @State private var note = ""

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    likingCard
                    reactionCard
                    noteCard
                    BigButton(title: "Сохранить") { save() }
                        .padding(.top, 4)
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Запись кормления")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    // MARK: - Шапка с продуктом

    private var header: some View {
        HStack(spacing: 12) {
            FoodIcon(food: food, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).font(.title3.bold())
                Text("Как прошло кормление?").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .cartoonCard()
    }

    // MARK: - Вкусовая оценка

    private var likingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Как зашло?").font(.headline)
            LikingPicker(selection: $liking)
        }
        .cartoonCard()
    }

    // MARK: - Реакция (эмодзи-кнопки вместо системного пикера)

    private var reactionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Реакция").font(.headline)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ReactionType.allCases, id: \.self) { r in
                    reactionButton(r)
                }
            }
            if reaction != .none {
                Label("Реакция переведёт продукт в «паузу», а если он уже введён — в «аллергию».",
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cartoonCard()
    }

    private func reactionButton(_ r: ReactionType) -> some View {
        let selected = reaction == r
        let tint = (r == .none) ? Theme.mint : Color.orange
        return Button {
            withAnimation(.snappy) { reaction = r }
        } label: {
            VStack(spacing: 6) {
                OpenMojiIcon(asset: "react_\(r.rawValue)", fallback: r.emoji, size: 32)
                Text(r.title).font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(selected ? tint : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(selected ? tint.opacity(0.16) : Color.black.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? tint : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(BouncyButtonStyle())
    }

    // MARK: - Заметка

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Заметка").font(.headline)
            TextField("Например: съел половину", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Color.black.opacity(0.03),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .cartoonCard()
    }

    // MARK: - Сохранение

    private func save() {
        let service = FeedingService(context: context)
        service.logFeeding(food,
                           liking: liking,
                           reaction: reaction == .none ? nil : reaction)
        if !note.isEmpty {
            // заметку кладём отдельной записью-комментарием, чтобы не усложнять API
            context.insert(FoodLog(foodId: food.id, note: note))
            try? context.save()
        }
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
        dismiss()
    }
}
