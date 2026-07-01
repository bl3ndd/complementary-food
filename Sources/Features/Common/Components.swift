import SwiftUI

/// Маленькая капсула-факт.
struct Chip: View {
    let text: String
    let icon: String?
    let color: Color

    init(_ text: String, icon: String? = nil, color: Color = .secondary) {
        self.text = text
        self.icon = icon
        self.color = color
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.caption2) }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(color.opacity(0.16), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.20), lineWidth: 1))
        .foregroundStyle(color)
    }
}

/// Крупная primary-кнопка на всю ширину с градиентом и мягкой тенью.
struct BigButton: View {
    let title: LocalizedStringKey
    var tint: Color? = nil          // nil → фирменный градиент-акцент
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(backgroundGradient, in: Capsule())
                .shadow(color: (tint ?? Theme.accent).opacity(0.35), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private var backgroundGradient: LinearGradient {
        if let tint {
            LinearGradient(colors: [tint, tint.opacity(0.82)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Theme.accentGradient
        }
    }
}

/// Вторичная (контурная) кнопка на всю ширину — для менее частых действий
/// (например «была реакция»), чтобы не перетягивать внимание с главной.
struct GhostButton: View {
    let title: LocalizedStringKey
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(tint.opacity(0.10), in: Capsule())
                .overlay(Capsule().stroke(tint.opacity(0.40), lineWidth: 1.5))
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

/// Компактная капсула-кнопка действия (например «Дал», «Полить»).
struct PillButton: View {
    let title: LocalizedStringKey
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(LinearGradient(colors: [tint, tint.opacity(0.82)],
                                           startPoint: .top, endPoint: .bottom),
                            in: Capsule())
                .shadow(color: tint.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(BouncyButtonStyle())
    }
}

/// Flow-раскладка: элементы идут в ряд и переносятся на новую строку, сохраняя
/// собственный размер. Для тегов/чипов — без обрезки текста и с ровными отступами.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: maxWidth == .infinity ? widest : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                      proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
