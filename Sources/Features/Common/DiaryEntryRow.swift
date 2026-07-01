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
    @State private var showPhotos = false

    private var hasBadges: Bool {
        entry.planned || (entry.reaction ?? .none) != .none
    }

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
                // Тип «ввод/поддержка» не показываем — чистый дневник: запись
                // это просто кормление. Значимы только план и реакция.
                if hasBadges {
                    FlowLayout(spacing: 6) {
                        if entry.planned {
                            StatusBadge(text: String(localized: "план"), color: Theme.lilac)
                        }
                        if let reaction = entry.reaction, reaction != .none {
                            StatusBadge(text: reaction.title, color: .red)
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
        .fullScreenCover(isPresented: $showPhotos) {
            PhotoViewer(photos: entry.log.photoDatas)
        }
    }

    @ViewBuilder private var trailing: some View {
        if showDone, let onDone {
            PillButton(title: "Выполнено") { onDone() }
        } else {
            HStack(spacing: 8) {
                photoThumb
                if !entry.planned, let liking = entry.liking {
                    OpenMojiIcon(asset: "like_\(liking.rawValue)", fallback: liking.emoji, size: 30)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Миниатюра первого фото + «+N», тап → полноэкранный просмотр.
    @ViewBuilder private var photoThumb: some View {
        let datas = entry.log.photoDatas
        if let first = datas.first, let ui = UIImage(data: first) {
            Button { showPhotos = true } label: {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if datas.count > 1 {
                            Text("+\(datas.count - 1)")
                                .font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 3).padding(.vertical, 1)
                                .background(.black.opacity(0.55), in: Capsule())
                                .padding(1)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
    }
}
