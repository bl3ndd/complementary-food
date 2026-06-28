import XCTest
@testable import Prikorm

/// Тесты каталога продуктов (Task 2): декодинг JSON, валидность данных,
/// группировка по категориям и поиск.
final class FoodCatalogTests: XCTestCase {

    /// Каталог из бандла приложения (хост-таргет тестов).
    private let catalog = FoodCatalog.shared

    // MARK: - Декодинг

    func testBundledJSONDecodesAndIsNonEmpty() {
        XCTAssertFalse(catalog.all.isEmpty, "foods.json должен декодироваться и содержать продукты")
    }

    func testDecodeFromRawData() throws {
        let json = """
        { "version": 1, "foods": [
            { "id": "zucchini", "name": "Кабачок", "category": "vegetable",
              "emoji": "🥒", "isAllergen": false, "allergenGroup": null, "minAgeMonths": 4 },
            { "id": "egg_yolk", "name": "Яичный желток", "category": "egg",
              "emoji": "🥚", "isAllergen": true, "allergenGroup": "egg", "minAgeMonths": 7 }
        ] }
        """.data(using: .utf8)!

        let decoded = try FoodCatalog.decode(json)
        XCTAssertEqual(decoded.all.count, 2)

        let yolk = try XCTUnwrap(decoded.food(id: "egg_yolk"))
        XCTAssertEqual(yolk.name, "Яичный желток")
        XCTAssertEqual(yolk.category, .egg)
        XCTAssertTrue(yolk.isAllergen)
        XCTAssertEqual(yolk.allergenGroup, .egg)
        XCTAssertEqual(yolk.minAgeMonths, 7)

        let zucchini = try XCTUnwrap(decoded.food(id: "zucchini"))
        XCTAssertNil(zucchini.allergenGroup)
        XCTAssertFalse(zucchini.isAllergen)
    }

    func testDecodeThrowsOnMalformedJSON() {
        let bad = #"{ "foods": [ { "id": "x" } ] }"#.data(using: .utf8)!
        XCTAssertThrowsError(try FoodCatalog.decode(bad))
    }

    // MARK: - Целостность данных

    func testEveryFoodHasUniqueId() {
        let ids = catalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "id продуктов должны быть уникальны")
    }

    func testEveryFoodHasNonEmptyNameAndValidAge() {
        for food in catalog.all {
            XCTAssertFalse(food.name.isEmpty, "у \(food.id) пустое имя")
            XCTAssertGreaterThanOrEqual(food.minAgeMonths, 0, "у \(food.id) отрицательный возраст")
        }
    }

    func testAllergenFoodsCarryAnAllergenGroup() {
        for food in catalog.all where food.isAllergen {
            XCTAssertNotNil(food.allergenGroup, "аллерген \(food.id) без allergenGroup")
        }
    }

    // MARK: - Группировка

    func testByCategoryReturnsOnlyThatCategory() {
        for category in FoodCategory.allCases {
            let foods = catalog.byCategory(category)
            XCTAssertTrue(foods.allSatisfy { $0.category == category },
                          "byCategory(\(category)) вернул чужую категорию")
        }
    }

    func testByCategoryPartitionsTheWholeCatalog() {
        let regrouped = FoodCategory.allCases.flatMap { catalog.byCategory($0) }
        XCTAssertEqual(regrouped.count, catalog.all.count,
                       "сумма категорий должна покрывать весь каталог без потерь")
    }

    func testFoodLookupById() {
        let first = try? XCTUnwrap(catalog.all.first)
        if let first {
            XCTAssertEqual(catalog.food(id: first.id)?.id, first.id)
        }
        XCTAssertNil(catalog.food(id: "no-such-food"))
    }

    // MARK: - Поиск

    func testSearchEmptyReturnsEntireCatalog() {
        XCTAssertEqual(catalog.search("").count, catalog.all.count)
        XCTAssertEqual(catalog.search("   ").count, catalog.all.count)
    }

    func testSearchIsCaseInsensitiveSubstring() throws {
        let target = try XCTUnwrap(catalog.all.first)
        // подстрока из середины имени, в нижнем регистре
        let needle = String(target.name.dropFirst().prefix(3)).lowercased()
        guard !needle.isEmpty else { return }
        let results = catalog.search(needle)
        XCTAssertTrue(results.contains { $0.id == target.id },
                      "поиск '\(needle)' должен находить '\(target.name)'")
    }

    func testSearchNoMatchReturnsEmpty() {
        XCTAssertTrue(catalog.search("zzzнетничегоzzz").isEmpty)
    }

    func testSearchIsDiacriticInsensitive() {
        let local = FoodCatalog(foods: [
            Food(id: "egg_yolk", name: "Яичный жёлток", category: .egg,
                 emoji: "🥚", isAllergen: true, allergenGroup: .egg, minAgeMonths: 7),
        ])
        // запрос без «ё» должен находить название с «ё»
        XCTAssertEqual(local.search("желток").map(\.id), ["egg_yolk"])
        XCTAssertEqual(local.search("ЖЁЛТОК").map(\.id), ["egg_yolk"])
    }

    // MARK: - Свои продукты подмешиваются в каталог

    func testCustomFoodsMergeIntoCatalog() {
        let cf = CustomFood(name: "Компот", emoji: "🧃", minAgeMonths: 7)
        FoodCatalog.setCustom([cf])
        defer { FoodCatalog.custom = [] }

        let catalog = FoodCatalog.shared
        XCTAssertEqual(catalog.food(id: cf.id)?.category, .other)
        XCTAssertTrue(catalog.byCategory(.other).contains { $0.id == cf.id })
        XCTAssertTrue(catalog.search("компот").contains { $0.id == cf.id })
        XCTAssertEqual(cf.asFood.emoji, "🧃")
    }

    // MARK: - Локализованное имя (localizedName)

    /// Имя своего продукта (нет в String Catalog) показывается как есть — на любом
    /// языке устройства, без «перевода». `name` остаётся исходным ключом для поиска.
    func testLocalizedNameFallsBackForUnknownName() {
        let custom = Food(id: "custom-xyz", name: "Зубочистка-компот-42", category: .other,
                          emoji: "🧃", isAllergen: false, allergenGroup: nil, minAgeMonths: 8)
        XCTAssertEqual(custom.localizedName, "Зубочистка-компот-42")
        XCTAssertEqual(custom.name, "Зубочистка-компот-42")
    }
}
