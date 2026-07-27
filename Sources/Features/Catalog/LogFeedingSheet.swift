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
    /// Начальная дата (для записи «за этот день» из деталей дня); клампится к сегодня.
    var initialDate: Date = Date()
    /// Вызывается только при сохранении (не при «Отмена») — чтобы внешний быстрый
    /// лист закрылся лишь после записи, а по отмене вернул к списку продуктов.
    var onSaved: (() -> Void)? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var liking: Liking?
    @State private var reaction: ReactionType = .none
    @State private var severity: ReactionSeverity?
    @State private var note = ""
    @State private var date = Date()
    @State private var photos: [Data] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if mode == .feeding { likingCard }
                    if mode == .reaction { reactionCard }
                    detailsCard
                    PhotosAttachCard(photos: $photos)
                }
                .padding()
            }
            .background(AppBackground())
            .scrollDismissesKeyboard(.interactively)
            .hideKeyboardOnTap()
            .navigationTitle(mode == .feeding ? Text("Запись кормления") : Text("Запись реакции"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            // Кнопка всегда на виду — не нужно скроллить до низа.
            .safeAreaInset(edge: .bottom) {
                BigButton(title: "Сохранить") { save() }
                    .padding(.horizontal).padding(.top, 8).padding(.bottom, 6)
                    .background(
                        LinearGradient(colors: [Theme.card.opacity(0), Theme.card.opacity(0.9)],
                                       startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
            .onAppear { date = min(initialDate, Date()) }
        }
        .cozySheet()
    }

    // MARK: - Шапка с продуктом (без карточной обвязки — воздух)

    private var header: some View {
        VStack(spacing: 8) {
            FoodIcon(food: food, size: 64)
            Text(food.localizedName).font(.title3.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    // MARK: - Детали: дата + заметка одной карточкой

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Время, а не только дата: дневник несут педиатру, и «во сколько дали»
            // — такой же факт, как «что дали». Иначе запись за вчера получала
            // время момента ввода записи.
            DatePicker(selection: $date, in: ...Date(),
                       displayedComponents: [.date, .hourAndMinute]) {
                Label("Когда давали", systemImage: "calendar")
                    .font(.subheadline.weight(.medium))
            }
            .tint(Theme.accent)
            Divider()
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.top, 2)
                TextField("Например: съел половину", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
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

    // MARK: - Реакция (компактные чипы)

    private var reactionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Реакция").font(.headline)
            ReactionChips(reaction: $reaction)
            if reaction != .none {
                // Тяжесть — факт для журнала и PDF врачу; появляется только по делу.
                SeverityChips(severity: $severity)
                Label("Реакция сохранится в журнале. Остановить ввод можно кнопкой в карточке продукта.",
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .cartoonCard()
    }

    // MARK: - Сохранение

    private func save() {
        Haptics.success()
        // Заметка пишется в этот же лог кормления (п.20) — отдельной записи нет.
        FeedingService(context: context).logFeeding(
            food,
            liking: liking,
            reaction: reaction == .none ? nil : reaction,
            date: date,
            note: note.isEmpty ? nil : note,
            severity: reaction == .none ? nil : severity,
            photos: photos)
        NotificationManager.shared.refresh(context: context, profile: child.feedingProfile)
        onSaved?()
        dismiss()
    }
}
