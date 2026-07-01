import SwiftUI
import UIKit

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
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.food?.localizedName ?? entry.foodName)
                        .font(.headline).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.caption).foregroundStyle(.secondary)
                }
                // Бейджи — отдельной строкой, целыми чипами переносятся на новую
                // строку (FlowLayout), текст внутри не режется.
                FlowLayout(spacing: 6) {
                    StatusBadge(text: entry.type == .intro
                                ? String(localized: "Ввод")
                                : String(localized: "maintenance.type", defaultValue: "Поддержка"),
                                color: entry.type == .intro ? Theme.accent : .blue)
                    if entry.planned {
                        StatusBadge(text: String(localized: "план"), color: Theme.lilac)
                    }
                    if let reaction = entry.reaction, reaction != .none {
                        StatusBadge(text: reaction.title, color: .red)
                        if let severity = entry.log.severity {
                            StatusBadge(text: severity.title, color: severity.color)
                        }
                    }
                }
                if let note = entry.log.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
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
                if let data = entry.log.photo, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
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
