import SwiftUI
import UIKit
import PhotosUI

extension View {
    /// Прячет клавиатуру по тапу по пустому месту (тапы по полям/кнопкам не перехватываются).
    func hideKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
    }
}

extension AllergenStatus {
    var color: Color {
        switch self {
        case .ok:      return .green
        case .dueSoon: return .orange
        case .overdue: return .red
        }
    }
}

extension IntroState {
    var color: Color {
        switch self {
        case .notIntroduced: return .gray
        case .introducing:   return .blue
        case .introduced:    return .green
        case .paused:        return .orange
        case .allergy:       return .red
        }
    }
}

/// Уменьшает и сжимает фото перед сохранением в SwiftData/CloudKit (внешнее
/// хранилище, но всё же — не тащим многомегабайтные оригиналы).
func compressedImageData(_ data: Data, maxDim: CGFloat = 1200, quality: CGFloat = 0.7) -> Data? {
    guard let img = UIImage(data: data) else { return nil }
    let longest = max(img.size.width, img.size.height)
    let scale = min(1, maxDim / longest)
    if scale >= 1 { return img.jpegData(compressionQuality: quality) }
    let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
    let resized = UIGraphicsImageRenderer(size: size).image { _ in
        img.draw(in: CGRect(origin: .zero, size: size))
    }
    return resized.jpegData(compressionQuality: quality)
}


/// Капсула-бейдж со статусом.
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

/// Компактный чип выбора: OpenMoji-иконка + подпись в капсуле.
/// Заменил огромные плитки на экранах записи/правки (label = title, пинится E2E).
struct SelectChip: View {
    let title: String
    let asset: String
    let fallback: String
    var tint: Color = Theme.accent
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                OpenMojiIcon(asset: asset, fallback: fallback, size: 22)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? tint : .primary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(selected ? tint.opacity(0.15) : Theme.fill,
                        in: Capsule())
            .overlay(Capsule().stroke(selected ? tint : Theme.hairline,
                                      lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Шкала вкуса чипами (SPEC §5). Тап по выбранной снимает выбор.
struct LikingPicker: View {
    @Binding var selection: Liking?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Liking.allCases, id: \.self) { liking in
                SelectChip(title: liking.shortTitle,
                           asset: "like_\(liking.rawValue)", fallback: liking.emoji,
                           selected: selection == liking) {
                    Haptics.select()
                    selection = selection == liking ? nil : liking
                }
            }
        }
        .animation(.snappy, value: selection)
    }
}

/// Чипы реакции — общие для записи кормления и правки записи.
struct ReactionChips: View {
    @Binding var reaction: ReactionType

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(ReactionType.selectableCases, id: \.self) { r in
                SelectChip(title: r.title,
                           asset: "react_\(r.rawValue)", fallback: r.emoji,
                           tint: r == .none ? Theme.mint : .orange,
                           selected: reaction == r) {
                    Haptics.select()
                    withAnimation(.snappy) { reaction = r }
                }
            }
        }
    }
}

/// Выбор тяжести реакции — показывается только когда реакция выбрана. Это факт для
/// журнала и PDF, на стейт-машину ввода не влияет (SPEC §4.4).
struct SeverityChips: View {
    @Binding var severity: ReactionSeverity?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(ReactionSeverity.allCases, id: \.self) { s in
                chip(s)
            }
        }
    }

    private func chip(_ s: ReactionSeverity) -> some View {
        let selected = severity == s
        return Button {
            Haptics.select()
            withAnimation(.snappy) { severity = selected ? nil : s }
        } label: {
            HStack(spacing: 6) {
                // Тяжесть точками: ●○○ / ●●○ / ●●● — читается без чтения подписи.
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < s.dots ? Color.orange : Color.orange.opacity(0.25))
                            .frame(width: 6, height: 6)
                    }
                }
                Text(s.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? Color.orange : .primary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(selected ? Color.orange.opacity(0.15) : Theme.fill, in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.orange : Theme.hairline,
                                      lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel(Text(s.title))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

extension Date {
    /// Короткая дата «день месяц» в локали устройства (склонения/порядок — системные).
    var shortDate: String {
        formatted(.dateTime.day().month())
    }
}

/// Карточка «Фото» для записи (тарелка/сыпь-доказательство): несколько фото —
/// лента миниатюр (тап → полноэкранный просмотр, ✕ — убрать) + выбор из галереи
/// (до 5 за раз). Фото ужимается перед сохранением. Общая для листов записи.
struct PhotosAttachCard: View {
    @Binding var photos: [Data]
    @State private var items: [PhotosPickerItem] = []
    @State private var viewing: PhotoIndex?

    private struct PhotoIndex: Identifiable { let id: Int }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Фото").font(.headline)
                if !photos.isEmpty {
                    Text("\(photos.count)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
            }
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { idx, data in
                            if let ui = UIImage(data: data) {
                                Image(uiImage: ui).resizable().scaledToFill()
                                    .frame(width: 74, height: 74)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        // Удаляем по значению, а не по захваченному idx —
                                        // индекс мог устареть при быстрых тапах/анимации.
                                        Button { photos.removeAll { $0 == data } } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.body)
                                                .foregroundStyle(.white, .black.opacity(0.45))
                                        }
                                        .padding(3)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture { viewing = PhotoIndex(id: idx) }
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
            PhotosPicker(selection: $items, maxSelectionCount: 5, matching: .images,
                         photoLibrary: .shared()) {
                Label(photos.isEmpty ? "Добавить фото" : "Добавить ещё", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .cartoonCard()
        .fullScreenCover(item: $viewing) { PhotoViewer(photos: photos, start: $0.id) }
        .onChange(of: items) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                var added: [Data] = []
                for it in newItems {
                    if let raw = try? await it.loadTransferable(type: Data.self),
                       let small = compressedImageData(raw) { added.append(small) }
                }
                let toAdd = added
                await MainActor.run { photos.append(contentsOf: toAdd); items = [] }
            }
        }
    }
}

/// Системный share sheet (UIActivityViewController) для шаринга файла —
/// например PDF-дневника «для педиатра».
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Обёртка-URL для `.sheet(item:)` (URL не Identifiable).
struct ShareableFile: Identifiable {
    let id = UUID()
    let url: URL
}
