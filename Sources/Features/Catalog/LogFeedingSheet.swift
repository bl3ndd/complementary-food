import SwiftUI
import SwiftData

/// Лист записи кормления: вкусовая оценка + реакция + заметка (SPEC §5).
/// Главное — «как зашло» крупными плитками; реакция спрятана за «Была реакция?»,
/// потому что в большинстве кормлений её нет; дата — пилюлей в шапке, обычно «сейчас».
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
    /// «Была реакция?» в режиме кормления. В режиме реакции блок открыт всегда.
    @State private var hadReaction = false
    @State private var showDate = false

    private var reactionOpen: Bool { mode == .reaction || hadReaction }
    /// Сказали «была», но не выбрали какая — это не запись реакции.
    private var canSave: Bool { !reactionOpen || reaction != .none }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    // Оба блока в любом режиме: в редакторе записи реакция есть,
                    // а при самой записи её не было — приходилось сохранять и лезть
                    // править. Режим решает только порядок.
                    if mode == .feeding {
                        likingBlock
                        reactionCard
                    } else {
                        reactionCard
                        likingBlock
                    }
                    noteCard
                }
                .padding()
                .padding(.bottom, 8)
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
                    // Запись реакции без реакции — это не запись реакции.
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                    .padding(.horizontal).padding(.top, 8).padding(.bottom, 6)
                    .background(
                        LinearGradient(colors: [Theme.card.opacity(0), Theme.card.opacity(0.9)],
                                       startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
            .onAppear { date = min(initialDate, Date()) }
            .onChange(of: hadReaction) { _, had in
                if !had { reaction = .none; severity = nil }
            }
            .sheet(isPresented: $showDate) { dateSheet }
        }
        .cozySheet()
    }

    // MARK: - Шапка: продукт + когда (пилюля, обычно «сейчас»)

    private var header: some View {
        VStack(spacing: 10) {
            FoodIcon(food: food, size: 72)
            Text(food.localizedName).font(.title2.bold())
            Button { showDate = true } label: {
                Label(dateLabel, systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Theme.card, in: Capsule())
                    .overlay(Capsule().stroke(Theme.hairline, lineWidth: 1))
            }
            .foregroundStyle(.primary)
            .accessibilityHint(Text("Когда давали"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    /// «Сегодня, 15:24» / «Вчера, 9:10» / «12 окт., 9:10». Время, а не только дата:
    /// дневник несут педиатру, и «во сколько дали» — такой же факт, как «что дали».
    private var dateLabel: String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let cal = Calendar.current
        if cal.isDateInToday(date) { return String(localized: "Сегодня, \(time)") }
        if cal.isDateInYesterday(date) { return String(localized: "Вчера, \(time)") }
        return date.formatted(.dateTime.day().month()) + ", " + time
    }

    private var dateSheet: some View {
        NavigationStack {
            DatePicker("", selection: $date, in: ...Date(),
                       displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Theme.accent)
                .padding(.horizontal)
                .navigationTitle(Text("Когда давали"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") { showDate = false }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Как зашло — плитки сами себе поверхность, без карточки вокруг

    private var likingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Как зашло?").font(.headline)
            LikingPicker(selection: $liking)
        }
    }

    // MARK: - Реакция: в кормлении — за вопросом «Была реакция?»

    private var reactionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if mode == .feeding {
                HStack {
                    Text("Была реакция?").font(.headline)
                    Spacer()
                    Picker("Была реакция?", selection: $hadReaction.animation(.snappy)) {
                        Text("Нет").tag(false)
                        Text("Да").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 128)
                }
            } else {
                Text("Что было?").font(.headline)
            }
            if reactionOpen {
                ReactionChips(reaction: $reaction, includeNone: false)
                if reaction != .none {
                    // Тяжесть — факт для журнала и PDF врачу; появляется только по делу.
                    SeverityChips(severity: $severity)
                    Text("Реакция сохранится в журнале. Остановить ввод можно кнопкой в карточке продукта.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .cartoonCard()
    }

    // MARK: - Заметка + фото одной карточкой

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(.top, 2)
                TextField("Например: съел половину", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            }
            Divider()
            PhotosAttachCard(photos: $photos, embedded: true)
        }
        .cartoonCard()
    }

    // MARK: - Сохранение

    private func save() {
        Haptics.success()
        // Заметка пишется в этот же лог кормления (п.20) — отдельной записи нет.
        FeedingService(context: context, childId: child.id).logFeeding(
            food,
            liking: liking,
            reaction: reaction == .none ? nil : reaction,
            date: date,
            note: note.isEmpty ? nil : note,
            severity: reaction == .none ? nil : severity,
            photos: photos)
        NotificationManager.shared.refresh(context: context)
        // Только какие части листа пригодились — без продукта и без самой реакции.
        Analytics.track(.feedingLogged, [
            "mode": mode.rawValue,
            "liking": liking == nil ? "false" : "true",
            "reaction": reaction == .none ? "false" : "true",
            "note": note.isEmpty ? "false" : "true",
            "photo": photos.isEmpty ? "false" : "true",
            "backdated": Calendar.current.isDateInToday(date) ? "false" : "true",
        ])
        onSaved?()
        dismiss()
    }
}
