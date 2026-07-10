import SwiftUI
import UIKit

/// Тактильные отклики на ключевые действия. Без вибро-спама: `success` — только
/// значимые события (запись сохранена, ввод завершён, «Дал»), `select` —
/// чипы/переключатели, `warning` — деструктив, `tap` — лёгкий отклик кнопок.
enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func select()  { UISelectionFeedbackGenerator().selectionChanged() }
    static func tap()     { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

/// Одноразовый залп конфетти — для праздничных моментов («Продукт введён! 🎉»).
/// Кусочки разлетаются из центра и тают; позиции — детерминированно от индекса.
struct ConfettiBurst: View {
    var pieceCount: Int = 26
    @State private var flying = false

    private static let colors: [Color] =
        [Theme.accent, Theme.sunny, Theme.mint, Theme.sky, Theme.lilac]

    private struct Piece: Identifiable {
        let id: Int
        let dx: CGFloat, dy: CGFloat
        let size: CGFloat, rotation: Double, delay: Double, colorIndex: Int

        init(_ i: Int, of n: Int) {
            id = i
            // Псевдослучай от индекса (sin-хэш) — стабильно между рендерами.
            func noise(_ k: Double) -> Double { abs(sin(Double(i) * k)) }
            let angle = Double(i) / Double(n) * 2 * .pi
            let radius = 90 + 70 * noise(12.9898)
            dx = CGFloat(cos(angle) * radius)
            dy = CGFloat(sin(angle) * radius * 0.9 + 60)   // чуть вниз — «оседает»
            size = 7 + 6 * noise(78.233)
            rotation = 200 + 260 * noise(39.425)
            delay = 0.035 * Double(i % 5)
            colorIndex = i % Self.colorCount
        }
        private static let colorCount = 5
    }

    private var pieces: [Piece] { (0..<pieceCount).map { Piece($0, of: pieceCount) } }

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Self.colors[p.colorIndex])
                    .frame(width: p.size, height: p.size * 0.62)
                    .rotationEffect(.degrees(flying ? p.rotation : 0))
                    .offset(x: flying ? p.dx : 0, y: flying ? p.dy : 0)
                    .opacity(flying ? 0 : 1)
                    .animation(.easeOut(duration: 1.15).delay(p.delay), value: flying)
            }
        }
        .onAppear { flying = true }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Мягкое «дыхание» (вертикальный боб) — оживляет маскота. Только для
/// эмоциональных точек (hero главной, онбординг, поздравление), не для рабочих строк.
private struct GentleBob: ViewModifier {
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -3 : 2)
            .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: up)
            .onAppear { up = true }
    }
}

extension View {
    func gentleBob() -> some View { modifier(GentleBob()) }
}

/// Мягкое появление контента: лёгкий fade + подъём с пружиной. Срабатывает ОДИН раз
/// на identity вьюхи (возврат на таб не переигрывает). `delay` — для каскада карточек.
private struct CozyAppear: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func cozyAppear(_ delay: Double = 0) -> some View { modifier(CozyAppear(delay: delay)) }
}
