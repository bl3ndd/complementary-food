import SwiftUI

/// Настроение бренд-маскота «Pudding».
enum MascotMood: CaseIterable {
    case neutral, happy, cheer, curious, sleepy, worried

    /// Настроение героя по прогрессу ввода продуктов:
    /// ничего не введено → любопытствует, всё введено → ликует, иначе радуется.
    static func forProgress(introduced: Int, total: Int) -> MascotMood {
        guard total > 0, introduced > 0 else { return .curious }
        return introduced >= total ? .cheer : .happy
    }

    /// Настроение сводки аллергенов: есть просроченные/скоро → тревожится, иначе доволен.
    static func forDue(_ count: Int) -> MascotMood {
        count > 0 ? .worried : .happy
    }
}

/// Дуга для улыбок и закрытых глаз: `smiling` → «U» (улыбка),
/// иначе «∩» (грусть / счастливо зажмуренный глаз).
private struct MascotArc: Shape {
    var smiling: Bool
    func path(in r: CGRect) -> Path {
        var p = Path()
        if smiling {
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                           control: CGPoint(x: r.midX, y: r.maxY))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY),
                           control: CGPoint(x: r.midX, y: r.minY))
        }
        return p
    }
}

/// Бренд-маскот «Pudding» — мягкий пудинг-персонаж, нарисованный средствами SwiftUI
/// (плейсхолдер до заказного арта). Лицо меняется по `mood`. Статичный — без анимации.
struct Mascot: View {
    var mood: MascotMood = .neutral
    var size: CGFloat = 96

    private var custard: LinearGradient {
        LinearGradient(colors: [Color(red: 1.00, green: 0.87, blue: 0.55),
                                Color(red: 0.98, green: 0.74, blue: 0.34)],
                       startPoint: .top, endPoint: .bottom)
    }
    private var caramel: LinearGradient {
        LinearGradient(colors: [Color(red: 0.85, green: 0.55, blue: 0.28),
                                Color(red: 0.72, green: 0.42, blue: 0.19)],
                       startPoint: .top, endPoint: .bottom)
    }
    private let line = Color(red: 0.34, green: 0.20, blue: 0.12)

    var body: some View {
        VStack(spacing: -size * 0.11) {
            Ellipse()
                .fill(caramel)
                .frame(width: size * 0.60, height: size * 0.24)
                .overlay(Ellipse().stroke(.white.opacity(0.25), lineWidth: 1))
                .zIndex(1)
            puddingBody
        }
        .frame(width: size, height: size * 0.7)
    }

    private var puddingBody: some View {
        UnevenRoundedRectangle(topLeadingRadius: size * 0.34,
                               bottomLeadingRadius: size * 0.16,
                               bottomTrailingRadius: size * 0.16,
                               topTrailingRadius: size * 0.34,
                               style: .continuous)
            .fill(custard)
            .frame(width: size * 0.80, height: size * 0.56)
            .overlay(face)
            .shadow(color: .black.opacity(0.08), radius: size * 0.06, y: size * 0.03)
    }

    private var face: some View {
        VStack(spacing: size * 0.05) {
            HStack(spacing: size * 0.18) { eye; eye }
                .overlay(alignment: .leading) { cheek.offset(x: -size * 0.05) }
                .overlay(alignment: .trailing) { cheek.offset(x: size * 0.05) }
            mouth
        }
        .offset(y: size * 0.02)
    }

    private var cheek: some View {
        Circle().fill(Theme.accent.opacity(0.30))
            .frame(width: size * 0.07, height: size * 0.07)
    }

    @ViewBuilder private var eye: some View {
        switch mood {
        case .happy, .cheer:
            MascotArc(smiling: false)
                .stroke(line, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                .frame(width: size * 0.12, height: size * 0.07)
        case .sleepy:
            Capsule().fill(line).frame(width: size * 0.12, height: size * 0.028)
        default:
            Circle().fill(line).frame(width: size * 0.085, height: size * 0.085)
        }
    }

    @ViewBuilder private var mouth: some View {
        switch mood {
        case .cheer:
            Ellipse().fill(line).frame(width: size * 0.14, height: size * 0.10)
        case .happy:
            MascotArc(smiling: true)
                .stroke(line, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                .frame(width: size * 0.18, height: size * 0.09)
        case .worried:
            MascotArc(smiling: false)
                .stroke(line, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
                .frame(width: size * 0.16, height: size * 0.08)
        case .curious:
            Circle().stroke(line, lineWidth: size * 0.03)
                .frame(width: size * 0.08, height: size * 0.08)
        case .sleepy, .neutral:
            Capsule().fill(line).frame(width: size * 0.10, height: size * 0.028)
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                  spacing: 24) {
            ForEach(Array(MascotMood.allCases.enumerated()), id: \.offset) { _, mood in
                VStack(spacing: 8) {
                    Mascot(mood: mood, size: 80)
                    Text("\(mood)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
