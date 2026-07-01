import SwiftUI
import UIKit

/// Кэш уменьшённых иконок. OpenMoji-PNG — 618×618; показываются по 24–88pt. Держать
/// и композить полноразмерные текстуры дорого (лагают переходы/списки). Декодим в
/// нужный размер один раз и кэшируем. Синхронно — чтобы работал `ImageRenderer`
/// (рекап-карточка снимает вьюху сразу, без ожидания async-загрузки).
final class IconCache {
    static let shared = IconCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 400
        return c
    }()

    /// Первая существующая иконка из списка кандидатов, уменьшённая до `px` пикселей.
    func thumbnail(_ candidates: [String], px: CGFloat) -> UIImage? {
        let side = max(1, px.rounded())
        let key = "\(candidates.joined(separator: "|"))@\(Int(side))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        var result: UIImage?
        let target = CGSize(width: side, height: side)
        for name in candidates {
            if let full = UIImage(named: name) {
                result = full.preparingThumbnail(of: target) ?? full
                break
            }
        }
        if let result { cache.setObject(result, forKey: key) }
        return result
    }
}

/// Иллюстрация OpenMoji по имени ассета с фолбэком на системный эмодзи.
/// Используется там, где нужна «красивая» иконка вместо дефолтного эмодзи
/// (оценка вкуса, реакция) — единый стиль с иконками продуктов.
struct OpenMojiIcon: View {
    let asset: String
    let fallback: String
    var size: CGFloat = 30
    @Environment(\.displayScale) private var scale

    var body: some View {
        if let image = IconCache.shared.thumbnail([asset], px: size * scale) {
            Image(uiImage: image).resizable().scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(fallback).font(.system(size: size))
        }
    }
}

/// Иллюстрация продукта в цветной скруглённой плитке.
/// Порядок фолбэка: иконка продукта → OpenMoji по эмодзи → иконка категории → эмодзи.
/// Иллюстрации — OpenMoji (CC BY-SA 4.0).
struct FoodIcon: View {
    let food: Food
    var size: CGFloat = 46
    @Environment(\.displayScale) private var scale

    /// Имена ассетов-кандидатов (просто строки, без загрузки картинок).
    private var candidates: [String] {
        // Свои продукты — OpenMoji-иконка по выбранному эмодзи (без подмены категорией).
        if food.id.hasPrefix("custom-") {
            return CustomFoodIcons.asset(for: food.emoji).map { [$0] } ?? []
        }
        var names = ["food_\(food.id)"]
        if let pick = CustomFoodIcons.asset(for: food.emoji) { names.append(pick) }
        names.append("cat_\(food.category.rawValue)")
        return names
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(Theme.softGradient(Theme.categoryColor(food.category)))
                .overlay(RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                    .stroke(.white.opacity(0.6), lineWidth: 1))
            if let image = IconCache.shared.thumbnail(candidates, px: size * scale) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.15)
            } else {
                // Фолбэк-эмодзи: центрируем в фиксированном квадрате, чтобы иконки не
                // «съезжали» из-за разного бейзлайна/ширины эмодзи (п.13).
                Text(food.emoji)
                    .font(.system(size: size * 0.55))
                    .frame(width: size, height: size)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: size, height: size)
    }
}
