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

    /// Поля «чем полезен / нутриенты» (п.12): декодируются и когда есть, и когда нет.
    func testDecodeBenefitsAndNutrientsOptional() throws {
        let json = """
        { "version": 1, "foods": [
            { "id": "zucchini", "name": "Кабачок", "category": "vegetable",
              "emoji": "🥒", "isAllergen": false, "allergenGroup": null, "minAgeMonths": 4,
              "benefits": "Лёгкий овощ.", "nutrients": ["Калий", "Витамин C"] },
            { "id": "plain", "name": "Без полей", "category": "other",
              "emoji": "🍎", "isAllergen": false, "allergenGroup": null, "minAgeMonths": 6 }
        ] }
        """.data(using: .utf8)!

        let decoded = try FoodCatalog.decode(json)
        let z = try XCTUnwrap(decoded.food(id: "zucchini"))
        XCTAssertEqual(z.benefits, "Лёгкий овощ.")
        XCTAssertEqual(z.nutrients, ["Калий", "Витамин C"])
        XCTAssertNotNil(z.localizedBenefits)

        let plain = try XCTUnwrap(decoded.food(id: "plain"))
        XCTAssertNil(plain.benefits)
        XCTAssertNil(plain.nutrients)
        XCTAssertNil(plain.localizedBenefits)
    }

    /// Каждый каталожный продукт имеет описание пользы и список нутриентов (п.12).
    func testEveryBundledFoodHasBenefitsAndNutrients() {
        for food in catalog.foods {
            XCTAssertFalse(food.benefits?.isEmpty ?? true, "у \(food.id) нет описания пользы")
            XCTAssertFalse(food.nutrients?.isEmpty ?? true, "у \(food.id) пустые нутриенты")
        }
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

    /// Каталог перестроен (п.14/18): воды нет, псевдо-категории «аллерген» нет —
    /// аллергенность определяется флагом, а не категорией.
    func testCatalogHasNoWaterAndRealCategories() {
        XCTAssertNil(catalog.food(id: "water"), "вода убрана из каталога (п.18)")
        let allowed = Set(FoodCategory.allCases)   // .allergen в перечислении больше нет
        for food in catalog.all {
            XCTAssertTrue(allowed.contains(food.category), "у \(food.id) категория вне перечисления")
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

    // MARK: - Нечёткий поиск и поиск по группе (п.1/17)

    func testSearchToleratesTypos() {
        let local = FoodCatalog(foods: [
            Food(id: "zucchini", name: "Кабачок", category: .vegetable, emoji: "🥒",
                 isAllergen: false, allergenGroup: nil, minAgeMonths: 4),
        ])
        XCTAssertEqual(local.search("кабчок").map(\.id), ["zucchini"])   // пропущена буква (подпоследовательность)
        XCTAssertEqual(local.search("кабачёк").map(\.id), ["zucchini"])  // замена буквы (Левенштейн 1)
    }

    func testSearchByCategoryNameReturnsWholeGroup() {
        let local = FoodCatalog(foods: [
            Food(id: "zucchini", name: "Кабачок", category: .vegetable, emoji: "🥒",
                 isAllergen: false, allergenGroup: nil, minAgeMonths: 4),
            Food(id: "broccoli", name: "Брокколи", category: .vegetable, emoji: "🥦",
                 isAllergen: false, allergenGroup: nil, minAgeMonths: 4),
            Food(id: "apple", name: "Яблоко", category: .fruit, emoji: "🍎",
                 isAllergen: false, allergenGroup: nil, minAgeMonths: 5),
        ])
        XCTAssertEqual(Set(local.search("овощи").map(\.id)), ["zucchini", "broccoli"],
                       "«овощи» показывает всю категорию овощей (п.17)")
    }

    func testSearchByAllergenGroupName() {
        let local = FoodCatalog(foods: [
            Food(id: "bread", name: "Хлеб", category: .other, emoji: "🍞",
                 isAllergen: true, allergenGroup: .gluten, minAgeMonths: 8),
            Food(id: "apple", name: "Яблоко", category: .fruit, emoji: "🍎",
                 isAllergen: false, allergenGroup: nil, minAgeMonths: 5),
        ])
        XCTAssertEqual(local.search("глютен").map(\.id), ["bread"],
                       "запрос по группе аллергена находит продукт группы")
    }

    func testSearchRanksExactBeforeSubstring() {
        let local = FoodCatalog(foods: [
            Food(id: "nosok", name: "Носок", category: .other, emoji: "🧦",
                 isAllergen: false, allergenGroup: nil, minAgeMonths: 6),
            Food(id: "sok", name: "Сок", category: .other, emoji: "🧃",
                 isAllergen: false, allergenGroup: nil, minAgeMonths: 6),
        ])
        XCTAssertEqual(local.search("сок").map(\.id).first, "sok",
                       "точное совпадение ранжируется выше вхождения")
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
