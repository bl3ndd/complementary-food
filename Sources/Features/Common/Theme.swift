import SwiftUI
import UIKit

/// Детская мультяшная тема: тёплая палитра, скруглённые формы, мягкие тени (SPEC §10).
///
/// **Светлая и тёмная.** Дневник ведут в том числе ночью, с ребёнком на руках —
/// поэтому палитра адаптивная, а не прибитая к светлой. Правило: бренд-акценты
/// (коралл/мята/небо/сирень) в тёмной чуть светлее для контраста на тёмном фоне;
/// поверхности (`card`/`fill`/`hairline`) — семантические, их и надо использовать
/// вместо литералов `.white` / `Color.black.opacity(…)`.
enum Theme {
    /// Пара «цвет для светлой / цвет для тёмной» одним динамическим Color.
    static func dynamic(_ light: Color, _ dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // MARK: - Палитра (бренд)
    static let accent     = dynamic(Color(red: 0.99, green: 0.49, blue: 0.31),
                                    Color(red: 1.00, green: 0.58, blue: 0.42))   // тёплый коралл
    static let accentDeep = dynamic(Color(red: 0.97, green: 0.33, blue: 0.44),
                                    Color(red: 0.98, green: 0.44, blue: 0.54))   // коралл → малина
    static let sunny      = dynamic(Color(red: 1.00, green: 0.78, blue: 0.28),
                                    Color(red: 1.00, green: 0.82, blue: 0.40))   // солнечный жёлтый
    static let mint       = dynamic(Color(red: 0.36, green: 0.80, blue: 0.60),
                                    Color(red: 0.44, green: 0.86, blue: 0.67))   // мятный
    static let sky        = dynamic(Color(red: 0.40, green: 0.68, blue: 0.95),
                                    Color(red: 0.52, green: 0.75, blue: 1.00))   // небесный
    static let lilac      = dynamic(Color(red: 0.66, green: 0.55, blue: 0.93),
                                    Color(red: 0.74, green: 0.65, blue: 0.97))   // сиреневый

    /// Мягкий «чернильный» текст (в тёмной — тёплый почти-белый).
    static let ink        = dynamic(Color(red: 0.20, green: 0.16, blue: 0.24),
                                    Color(red: 0.95, green: 0.93, blue: 0.97))

    // MARK: - Поверхности (семантические)

    /// Фон приложения: тёплый кремовый ↔ глубокий сливовый.
    static let bgTop    = dynamic(Color(red: 1.00, green: 0.98, blue: 0.93),
                                  Color(red: 0.09, green: 0.07, blue: 0.11))
    static let bgBottom = dynamic(Color(red: 1.00, green: 0.92, blue: 0.94),
                                  Color(red: 0.13, green: 0.09, blue: 0.13))

    /// Карточка/лист поверх фона (была прибита к `.white`).
    static let card     = dynamic(.white, Color(red: 0.16, green: 0.14, blue: 0.19))

    /// Лёгкая заливка под чипы/поля ввода (была `Color.black.opacity(0.03…0.05)`).
    static let fill     = dynamic(Color.black.opacity(0.04), Color.white.opacity(0.07))

    /// Волосяная граница карточек и капсул (была `.black.opacity(0.06)`).
    static let hairline = dynamic(Color.black.opacity(0.07), Color.white.opacity(0.12))

    /// Обводка карточки: в светлой — белый блик, в тёмной — мягкий контур.
    static let cardStroke = dynamic(Color.white.opacity(0.9), Color.white.opacity(0.06))

    /// Главный градиент-акцент (кнопки, кольца, герой).
    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Цвет-акцент для категории (для «плиток» с эмодзи).
    static func categoryColor(_ category: FoodCategory) -> Color {
        switch category {
        case .vegetable: return mint
        case .porridge:  return sunny
        case .fruit:     return Color(red: 0.96, green: 0.52, blue: 0.62)
        case .meat:      return Color(red: 0.90, green: 0.45, blue: 0.42)
        case .fish:      return sky
        case .dairy:     return Color(red: 0.55, green: 0.72, blue: 0.95)
        case .egg:       return sunny
        case .other:     return lilac
        case .custom:    return accent
        }
    }

    /// Мягкий вертикальный градиент из одного цвета (для плиток-аватаров).
    static func softGradient(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color.opacity(0.30), color.opacity(0.16)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Градиентный фон приложения с мягкими «облачками» для глубины.
/// Пятна — радиальные градиенты, НЕ `.blur` (живой блюр пересчитывается каждый кадр
/// и рушит FPS на переходах — фон есть на каждом экране, при пуше их сразу два).
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // В тёмной пятна приглушаем: на светлом фоне они дают воздух, на тёмном
        // в полную силу превращаются в грязь.
        let k: Double = scheme == .dark ? 0.55 : 1

        return ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                           startPoint: .top, endPoint: .bottom)

            blob(Theme.sunny.opacity(0.22 * k), size: 340, x: -130, y: -260)
            blob(Theme.sky.opacity(0.20 * k),   size: 320, x: 150,  y: -120)
            blob(Theme.lilac.opacity(0.17 * k), size: 300, x: -150, y: 320)
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(gradient: Gradient(colors: [color, color.opacity(0)]),
                                 center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
            .offset(x: x, y: y)
    }
}

/// Иконка в цветной скруглённой плитке с мягким градиентом.
/// Если задан `asset` — рисуем красивую OpenMoji-картинку (с фолбэком на эмодзи).
struct EmojiAvatar: View {
    let emoji: String
    var asset: String? = nil
    var color: Color = Theme.accent
    var size: CGFloat = 46

    var body: some View {
        Group {
            if let asset {
                OpenMojiIcon(asset: asset, fallback: emoji, size: size * 0.56)
            } else {
                Text(emoji).font(.system(size: size * 0.52))
            }
        }
        .frame(width: size, height: size)
        .background(Theme.softGradient(color),
                    in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .stroke(Theme.cardStroke, lineWidth: 1))
    }
}

extension View {
    /// Белая карточка со скруглением и мягкой многослойной тенью.
    func cartoonCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1))
            // Одна тень вместо двух — каждый .shadow это offscreen-проход на карточку.
            .shadow(color: Theme.accentDeep.opacity(0.12), radius: 14, x: 0, y: 7)
    }
}

/// Кнопочный стиль с лёгким «пружинистым» нажатием.
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
