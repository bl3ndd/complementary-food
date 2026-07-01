import SwiftUI

/// Детская мультяшная тема: тёплая палитра, скруглённые формы, мягкие тени (SPEC §10).
enum Theme {
    // MARK: - Палитра
    static let accent     = Color(red: 0.99, green: 0.49, blue: 0.31)   // тёплый коралл
    static let accentDeep = Color(red: 0.97, green: 0.33, blue: 0.44)   // коралл → малина
    static let sunny      = Color(red: 1.00, green: 0.78, blue: 0.28)   // солнечный жёлтый
    static let mint       = Color(red: 0.36, green: 0.80, blue: 0.60)   // мятный
    static let sky        = Color(red: 0.40, green: 0.68, blue: 0.95)   // небесный
    static let lilac      = Color(red: 0.66, green: 0.55, blue: 0.93)   // сиреневый

    static let ink        = Color(red: 0.20, green: 0.16, blue: 0.24)   // мягкий «чернильный» текст

    static let bgTop    = Color(red: 1.00, green: 0.98, blue: 0.93)
    static let bgBottom = Color(red: 1.00, green: 0.92, blue: 0.94)

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
    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                           startPoint: .top, endPoint: .bottom)

            blob(Theme.sunny.opacity(0.22), size: 340, x: -130, y: -260)
            blob(Theme.sky.opacity(0.20),   size: 320, x: 150,  y: -120)
            blob(Theme.lilac.opacity(0.17), size: 300, x: -150, y: 320)
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
                .stroke(.white.opacity(0.6), lineWidth: 1))
    }
}

extension View {
    /// Белая карточка со скруглением и мягкой многослойной тенью.
    func cartoonCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 1))
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
