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
        // Цвета экранов (гамма), а не системные синий/зелёный — иначе бейджи
        // спорили с остальной палитрой.
        case .notIntroduced: return .gray
        case .introducing:   return Theme.sky
        case .introduced:    return Theme.mint
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

/// Шкала вкуса — три крупные плитки в ряд (SPEC §5): попадает большой палец одной
/// руки, пока второй держишь ребёнка. Тап по выбранной снимает выбор.
struct LikingPicker: View {
    @Binding var selection: Liking?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Liking.allCases, id: \.self) { liking in
                let on = selection == liking
                // Пока ничего не выбрано — все лица цветные; после выбора остальные гаснут.
                let lit = on || selection == nil
                Button {
                    Haptics.select()
                    withAnimation(.snappy) { selection = on ? nil : liking }
                } label: {
                    VStack(spacing: 8) {
                        OpenMojiIcon(asset: "like_\(liking.rawValue)", fallback: liking.emoji, size: 40)
                            .grayscale(lit ? 0 : 1)
                            .opacity(lit ? 1 : 0.35)
                            .scaleEffect(on ? 1.1 : 1)
                        Text(liking.title)
                            .font(.footnote.weight(on ? .semibold : .regular))
                            .foregroundStyle(on ? Theme.accent : .secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(on ? Theme.accent.opacity(0.10) : .clear,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(liking.title))
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(6)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
    }
}

/// Виды реакции — таблетки по ширине текста, с переносом. Без эмодзи: рвота и стул
/// картинками на экране, где мама отмечает реакцию у ребёнка, читались несерьёзно.
struct ReactionChips: View {
    @Binding var reaction: ReactionType
    /// В листе «Запись реакции» выбора «Нет реакции» нет: он был выбран по
    /// умолчанию, и запись реакции сохранялась без реакции.
    var includeNone = true

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(ReactionType.selectableCases.filter { includeNone || $0 != .none }, id: \.self) { r in
                let on = reaction == r
                let tint = r == .none ? Theme.mint : Color.orange
                Button {
                    Haptics.select()
                    withAnimation(.snappy) { reaction = r }
                } label: {
                    Text(r.title)
                        .font(.subheadline.weight(on ? .semibold : .regular))
                        .foregroundStyle(on ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(on ? tint : Theme.fill, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Тяжесть реакции — сегмент из трёх, выбор можно снять. Показывается только когда
/// реакция выбрана. Это факт для журнала и PDF, на стейт-машину ввода не влияет (SPEC §4.4).
struct SeverityChips: View {
    @Binding var severity: ReactionSeverity?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ReactionSeverity.allCases, id: \.self) { s in
                let on = severity == s
                Button {
                    Haptics.select()
                    withAnimation(.snappy) { severity = on ? nil : s }
                } label: {
                    HStack(spacing: 6) {
                        // Тяжесть точками: ●○○ / ●●○ / ●●● — читается без подписи.
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(i < s.dots ? Color.orange : Color.orange.opacity(0.25))
                                    .frame(width: 5, height: 5)
                            }
                        }
                        Text(s.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(on ? Color.orange : .primary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(on ? Theme.card : .clear, in: Capsule())
                    .overlay(Capsule().stroke(on ? Color.orange : .clear, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(s.title))
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(Theme.fill, in: Capsule())
    }
}

extension Date {
    /// Короткая дата «день месяц» в локали устройства (склонения/порядок — системные).
    var shortDate: String {
        formatted(.dateTime.day().month())
    }
}

extension String {
    /// Заглавная только у ПЕРВОГО символа. `.capitalized` поднимает каждое слово и
    /// в русских датах превращает «июль 2026 г.» в «Июль 2026 Г.», а «ср, 27 июн» —
    /// в «Ср, 27 Июн».
    var firstCapitalized: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

/// Карточка «Фото» для записи (тарелка/сыпь-доказательство): несколько фото —
/// лента миниатюр (тап → полноэкранный просмотр, ✕ — убрать) + выбор из галереи
/// (до 5 за раз). Фото ужимается перед сохранением. Общая для листов записи.
struct PhotosAttachCard: View {
    @Binding var photos: [Data]
    /// Внутри чужой карточки (лист записи): без заголовка «Фото» и своей подложки.
    var embedded = false
    @State private var items: [PhotosPickerItem] = []
    @State private var viewing: PhotoIndex?

    private struct PhotoIndex: Identifiable { let id: Int }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !embedded {
                HStack {
                    Text("Фото").font(.headline)
                    if !photos.isEmpty {
                        Text("\(photos.count)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    }
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
                                        .accessibilityLabel(Text("Удалить фото"))
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
                Label(photos.isEmpty ? String(localized: "Добавить фото") : String(localized: "Добавить ещё"), systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .modifier(CardUnlessEmbedded(embedded: embedded))
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

private struct CardUnlessEmbedded: ViewModifier {
    let embedded: Bool
    func body(content: Content) -> some View {
        if embedded { content } else { content.cartoonCard() }
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

/// Фото малыша в профиле: аватар + выбор из галереи, тап по крестику — убрать.
///
/// Через системный `PhotosPicker`, поэтому доступ ко всей галерее не запрашивается
/// и purpose string не нужен (важно для App Review 5.1.1). Картинка ужимается тем
/// же `compressedImageData`, что и фото записей.
struct ChildPhotoRow: View {
    @Binding var photo: Data?
    @State private var item: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 14) {
            if let photo, let ui = UIImage(data: photo) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Circle().fill(Theme.fill)
                    .frame(width: 56, height: 56)
                    .overlay(Image(systemName: "person.crop.circle")
                        .font(.title2).foregroundStyle(.secondary))
            }

            PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                Text(photo == nil ? String(localized: "Добавить фото") : String(localized: "Заменить фото"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

            Spacer(minLength: 0)

            if photo != nil {
                Button {
                    photo = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Удалить фото"))
            }
        }
        .onChange(of: item) { _, new in
            guard let new else { return }
            Task {
                let raw = try? await new.loadTransferable(type: Data.self)
                let small = raw.flatMap { compressedImageData($0) }
                await MainActor.run { if let small { photo = small }; item = nil }
            }
        }
    }
}
