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
            Text(text).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.14), in: Capsule())
        .foregroundStyle(color)
    }
}

/// Кольцо прогресса с числом по центру.
struct ProgressRing: View {
    let value: Int
    let total: Int
    var size: CGFloat = 56

    private var fraction: Double {
        total == 0 ? 0 : min(1, Double(value) / Double(total))
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.accent.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)").font(.headline.bold())
        }
        .frame(width: size, height: size)
    }
}

/// Крупная primary-кнопка на всю ширину.
struct BigButton: View {
    let title: String
    var tint: Color = Theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).fontWeight(.semibold).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }
}
