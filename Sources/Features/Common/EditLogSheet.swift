import SwiftUI
import SwiftData

/// Редактирование записи журнала: дата, вкусовая оценка, реакция, заметка + удаление
/// (core-дневник — запись можно поправить/удалить, п.20). Для запланированного ввода
/// (`planned`) — упрощённый режим: только дата (будущее разрешено) + заметка + удалить план.
struct EditLogSheet: View {
    @Bindable var log: FoodLog
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FocusState private var noteFocused: Bool

    @State private var date: Date
    @State private var liking: Liking?
    @State private var reaction: ReactionType
    @State private var severity: ReactionSeverity?
    @State private var note: String
    @State private var photos: [Data]
    @State private var confirmDelete = false

    init(log: FoodLog) {
        self.log = log
        _date = State(initialValue: log.date)
        _liking = State(initialValue: log.liking)
        _reaction = State(initialValue: log.reaction ?? .none)
        _severity = State(initialValue: log.severity)
        _note = State(initialValue: log.note ?? "")
        _photos = State(initialValue: log.photoDatas)
    }

    private var isPlanned: Bool { log.planned }
    private var minPlanDate: Date { Calendar.current.startOfDay(for: Date()) }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    datePicker
                        .tint(Theme.accent)
                        .cartoonCard()

                    if !isPlanned {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Как зашло?").font(.headline)
                            LikingPicker(selection: $liking)
                        }
                        .cartoonCard()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Реакция").font(.headline)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(ReactionType.allCases, id: \.self) { reactionButton($0) }
                            }
                            if reaction != .none {
                                Text("Насколько сильно?")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                SeverityPicker(selection: $severity)
                            }
                        }
                        .cartoonCard()

                        PhotosAttachCard(photos: $photos)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Заметка").font(.headline)
                        TextField("Например: съел половину", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($noteFocused)
                            .padding(12)
                            .background(Color.black.opacity(0.03),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .cartoonCard()

                    GhostButton(title: isPlanned ? "Удалить план" : "Удалить запись",
                                tint: .red) { confirmDelete = true }
                }
                .padding()
            }
            .background(AppBackground())
            .scrollDismissesKeyboard(.interactively)
            .hideKeyboardOnTap()
            .navigationTitle(Text(isPlanned ? String(localized: "План") : String(localized: "Запись")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { save() } }
            }
            .alert(Text(isPlanned ? String(localized: "Удалить план?")
                                  : String(localized: "Удалить запись?")),
                   isPresented: $confirmDelete) {
                Button("Удалить", role: .destructive) { deleteLog() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Действие нельзя отменить.")
            }
        }
    }

    /// Для плана дата может быть в будущем; для факта — не позже сегодня (п.22).
    @ViewBuilder private var datePicker: some View {
        if isPlanned {
            DatePicker(selection: $date, in: minPlanDate..., displayedComponents: .date) { dateLabel }
        } else {
            DatePicker(selection: $date, in: ...Date(), displayedComponents: .date) { dateLabel }
        }
    }

    private var dateLabel: some View {
        Label("Когда", systemImage: "calendar").font(.subheadline.weight(.medium))
    }

    private func reactionButton(_ r: ReactionType) -> some View {
        let selected = reaction == r
        let tint = (r == .none) ? Theme.mint : Color.orange
        return Button {
            withAnimation(.snappy) { reaction = r }
        } label: {
            VStack(spacing: 6) {
                OpenMojiIcon(asset: "react_\(r.rawValue)", fallback: r.emoji, size: 30)
                Text(r.title).font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(selected ? tint : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(selected ? tint.opacity(0.16) : Color.black.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? tint : .clear, lineWidth: 2))
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func save() {
        log.date = date
        if !isPlanned {
            log.liking = liking
            log.reaction = reaction == .none ? nil : reaction
            log.severity = reaction == .none ? nil : severity
            // Пересобираем фото только если реально менялись — иначе лишняя перезапись
            // external-storage/CloudKit при правке одной заметки.
            if photos != log.photoDatas {
                FeedingService(context: context).setPhotos(photos, on: log)
            }
        }
        log.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        try? context.save()
        dismiss()
    }

    private func deleteLog() {
        context.delete(log)
        try? context.save()
        dismiss()
    }
}
