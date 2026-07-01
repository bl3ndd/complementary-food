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

/// Шкала вкуса крупными карточками (SPEC §5). Тап по выбранной снимает выбор.
struct LikingPicker: View {
    @Binding var selection: Liking?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Liking.allCases, id: \.self) { liking in
                card(liking)
            }
        }
        .animation(.snappy, value: selection)
    }

    private func card(_ liking: Liking) -> some View {
        let selected = selection == liking
        return Button {
            selection = selected ? nil : liking
        } label: {
            VStack(spacing: 8) {
                OpenMojiIcon(asset: "like_\(liking.rawValue)",
                             fallback: liking.emoji, size: 56)
                    .scaleEffect(selected ? 1.08 : 1)
                Text(liking.shortTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(selected ? Theme.accent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selected ? Theme.accent.opacity(0.12) : Color.black.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Theme.accent : .clear, lineWidth: 2.5)
            )
            .opacity(selection == nil || selected ? 1 : 0.55)
        }
        .buttonStyle(BouncyButtonStyle())
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
