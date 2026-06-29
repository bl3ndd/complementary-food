import SwiftUI
import SwiftData

/// Лист записи кормления: вкусовая оценка + реакция + заметка (SPEC §5).
/// Мультяшный стиль: карточки, крупные эмодзи-кнопки, фирменная кнопка сохранения.
struct LogFeedingSheet: View {
    /// Режим листа: запись кормления (вкусовая оценка) или отметка реакции.
    enum Mode: String, Identifiable { case feeding, reaction; var id: String { rawValue } }

    let food: Food
    let child: Child
    var mode: Mode = .feeding

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var liking: Liking?
    @State private var reaction: ReactionType = .none
    @State private var note = ""
    @State private var date = Date()

    private let columns = [GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10),
                           GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    dateCard
                    if mode == .feeding { likingCard }
                    if mode == .reaction { reactionCard }
                    noteCard
                    BigButton(title: "Сохранить") { save() }
                        .padding(.top, 4)
                }
                .padding()
            }
            .background(AppBackground())
            .navigationTitle(mode == .feeding ? Text("Запись кормления") : Text("Запись реакции"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    // MARK: - Дата кормления

    private var dateCard: some View {
        DatePicker(selection: $date, in: ...Date(), displayedComponents: .date) {
            Label("Когда давали", systemImage: "calendar")
                .font(.subheadline.weight(.medium))
        }
        .tint(Theme.accent)
        .cartoonCard()
    }

    // MARK: - Шапка с продуктом

    private var header: some View {
        HStack(spacing: 12) {
            FoodIcon(food: food, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.localizedName).font(.title3.bold())
                Text(mode == .feeding
                     ? String(localized: "Как прошло кормление?")
                     : String(localized: "Отметь реакцию на продукт"))
                    .font(.subheadline).foregroundStyle(.secondary)
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
                Label("Реакция сохранится в журнале. Остановить ввод можно кнопкой в карточке продукта.",
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
        // Заметка пишется в этот же лог кормления (п.20) — отдельной записи нет.
        FeedingService(context: context).logFeeding(
            food,
            liking: liking,
            reaction: reaction == .none ? nil : reaction,
            date: date,
            note: note.isEmpty ? nil : note)
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
        dismiss()
    }
}
