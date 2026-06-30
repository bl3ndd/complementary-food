import SwiftUI

/// Одна строка журнала прикорма — общий вид для ленты Календаря и деталей дня.
/// Чисто презентационный: тап/«Выполнено» вешает родитель (строка лишь сообщает,
/// что она нажимается, шевроном — это снимало находку «не видно, что тапается»).
struct DiaryEntryRow: View {
    let entry: DayEntry
    /// Показать кнопку «Выполнено» (запланированный ввод, который уже можно дать).
    var showDone: Bool = false
    var onDone: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let food = entry.food {
                FoodIcon(food: food)
            } else {
                EmojiAvatar(emoji: "🍽️", asset: "ui_plate")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.food?.localizedName ?? entry.foodName).font(.headline)
                HStack(spacing: 6) {
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.caption).foregroundStyle(.secondary)
                    StatusBadge(text: entry.type == .intro
                                ? String(localized: "Ввод")
                                : String(localized: "maintenance.type", defaultValue: "Поддержка"),
                                color: entry.type == .intro ? Theme.accent : .blue)
                    if entry.planned {
                        StatusBadge(text: String(localized: "план"), color: Theme.lilac)
                    }
                    if let reaction = entry.reaction, reaction != .none {
                        StatusBadge(text: reaction.title, color: .red)
                    }
                }
                if let note = entry.log.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            trailing
        }
        .cartoonCard()
        .contentShape(Rectangle())
    }

    @ViewBuilder private var trailing: some View {
        if showDone, let onDone {
            PillButton(title: "Выполнено") { onDone() }
        } else {
            HStack(spacing: 8) {
                if !entry.planned, let liking = entry.liking {
                    OpenMojiIcon(asset: "like_\(liking.rawValue)", fallback: liking.emoji, size: 30)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
