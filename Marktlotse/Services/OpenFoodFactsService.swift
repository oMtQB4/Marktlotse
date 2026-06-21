//
//  OpenFoodFactsService.swift
//  Marktlotse
//
//  Product lookup using the Open Food Facts API (https://world.openfoodfacts.org).
//  Uses the public, key-free JSON read API (v2). German product names are
//  preferred when available.
//

import Foundation

final class OpenFoodFactsService: ProductLookupService {

    private let session: URLSession
    private let host = "https://world.openfoodfacts.org"
    // Open Food Facts asks for a descriptive User-Agent.
    private let userAgent = "Marktlotse/1.0 (iOS; de.apps-roters.marktlotse)"

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Opens the TLS connection to the API ahead of the first lookup so that
    /// DNS + TCP + TLS setup isn't paid for on the first scan (that handshake is
    /// the bulk of the "slow first request", especially on cellular). The pooled
    /// connection is then reused by the real lookup. Silent and best-effort.
    func warmUp() {
        guard let url = URL(string: host) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        Task { _ = try? await session.data(for: request) }
    }

    func lookup(barcode: String) async throws -> Article {
        guard Barcode.isLookupCandidate(barcode) else {
            throw ProductLookupError.invalidBarcode
        }

        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents(string: "\(host)/api/v2/product/\(code).json")!
        components.queryItems = [
            URLQueryItem(name: "lc", value: "de"),
            URLQueryItem(name: "fields",
                         value: "code,product_name,product_name_de,generic_name,generic_name_de,brands," +
                                "categories,quantity,serving_size,ingredients_text,ingredients_text_de," +
                                "allergens_tags,labels_tags,nutrition_grades,nova_group,nutriments")
        ]
        guard let url = components.url else { throw ProductLookupError.invalidBarcode }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProductLookupError.network(error)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 { throw ProductLookupError.notFound }
            if !(200...299).contains(http.statusCode) {
                throw ProductLookupError.server(code: http.statusCode)
            }
        }

        let payload: OFFResponse
        do {
            payload = try JSONDecoder().decode(OFFResponse.self, from: data)
        } catch {
            throw ProductLookupError.notFound
        }

        guard payload.status == 1, let product = payload.product else {
            throw ProductLookupError.notFound
        }

        let title = firstNonEmpty(product.productNameDE, product.productName,
                                  product.genericNameDE, product.genericName)
        guard let title else { throw ProductLookupError.notFound }

        return Article(
            barcode: barcode,
            title: title,
            manufacturer: cleaned(product.brands),
            detailName: firstNonEmpty(product.genericNameDE, product.genericName),
            descriptionText: nil,
            category: lastCategory(product.categories),
            source: .openFoodFacts,
            quantity: cleaned(product.quantity),
            servingSize: cleaned(product.servingSize),
            ingredients: firstNonEmpty(product.ingredientsTextDE, product.ingredientsText),
            allergens: parseTags(product.allergensTags, mapping: Self.allergenNamesDE, knownOnly: false),
            labels: parseTags(product.labelsTags, mapping: Self.labelNamesDE, knownOnly: true),
            nutriScore: normalizedGrade(product.nutritionGrades),
            novaGroup: product.novaGroup?.intValue,
            nutrition: makeNutrition(product)
        )
    }

    // MARK: - Mapping helpers

    private func lastCategory(_ raw: String?) -> String? {
        cleaned(raw)?.split(separator: ",").last.map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private func normalizedGrade(_ raw: String?) -> String? {
        guard let g = cleaned(raw)?.lowercased(), ["a", "b", "c", "d", "e"].contains(g) else { return nil }
        return g
    }

    /// Convert Open Food Facts tags (e.g. "en:milk") into readable German names.
    /// When `knownOnly` is true, only tags present in `mapping` are kept (filters
    /// out noisy/foreign-language label tags); otherwise unmapped tags are
    /// prettified and kept (important for allergens).
    private func parseTags(_ tags: [String]?, mapping: [String: String], knownOnly: Bool) -> [String]? {
        guard let tags, !tags.isEmpty else { return nil }
        var seen = Set<String>()
        var names: [String] = []
        for tag in tags {
            let parts = tag.split(separator: ":", maxSplits: 1)
            let key = (parts.count == 2 ? String(parts[1]) : String(parts[0])).lowercased()
            guard let name = mapping[key] ?? (knownOnly ? nil : prettify(key)) else { continue }
            if seen.insert(name).inserted { names.append(name) }
        }
        return names.isEmpty ? nil : names
    }

    private func prettify(_ key: String) -> String {
        key.replacingOccurrences(of: "-", with: " ")
           .replacingOccurrences(of: "_", with: " ")
           .capitalized
    }

    private func makeNutrition(_ p: OFFProduct) -> NutritionFacts? {
        guard let n = p.nutriments else { return nil }
        let facts = NutritionFacts(
            basis: "100 g",
            energyKcal: n.energyKcal,
            fat: n.fat,
            saturatedFat: n.saturatedFat,
            carbohydrates: n.carbohydrates,
            sugars: n.sugars,
            fiber: n.fiber,
            proteins: n.proteins,
            salt: n.salt
        )
        return facts.hasAnyValue ? facts : nil
    }

    // German names for the 14 EU major allergens and common labels.
    private static let allergenNamesDE: [String: String] = [
        "gluten": "Gluten", "milk": "Milch", "eggs": "Eier", "nuts": "Schalenfrüchte",
        "peanuts": "Erdnüsse", "soybeans": "Soja", "celery": "Sellerie", "mustard": "Senf",
        "sesame-seeds": "Sesam", "sesame": "Sesam", "fish": "Fisch",
        "crustaceans": "Krebstiere", "molluscs": "Weichtiere", "lupin": "Lupinen",
        "sulphur-dioxide-and-sulphites": "Schwefeldioxid/Sulfite"
    ]

    private static let labelNamesDE: [String: String] = [
        "vegan": "Vegan", "vegetarian": "Vegetarisch", "organic": "Bio", "eu-organic": "EU-Bio",
        "gluten-free": "Glutenfrei", "no-gluten": "Glutenfrei", "lactose-free": "Laktosefrei",
        "palm-oil-free": "Ohne Palmöl", "fair-trade": "Fair Trade"
    ]

    private func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let value, !value.trimmingCharacters(in: .whitespaces).isEmpty {
                return value.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Decoding

private struct OFFResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let productName: String?
    let productNameDE: String?
    let genericName: String?
    let genericNameDE: String?
    let brands: String?
    let categories: String?
    let quantity: String?
    let servingSize: String?
    let ingredientsText: String?
    let ingredientsTextDE: String?
    let allergensTags: [String]?
    let labelsTags: [String]?
    let nutritionGrades: String?
    let novaGroup: FlexibleInt?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case productNameDE = "product_name_de"
        case genericName = "generic_name"
        case genericNameDE = "generic_name_de"
        case brands
        case categories
        case quantity
        case servingSize = "serving_size"
        case ingredientsText = "ingredients_text"
        case ingredientsTextDE = "ingredients_text_de"
        case allergensTags = "allergens_tags"
        case labelsTags = "labels_tags"
        case nutritionGrades = "nutrition_grades"
        case novaGroup = "nova_group"
        case nutriments
    }
}

/// Decodes a value that may be an Int, Double or String into an Int.
private struct FlexibleInt: Decodable {
    let intValue: Int?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { intValue = i }
        else if let d = try? c.decode(Double.self) { intValue = Int(d) }
        else if let s = try? c.decode(String.self) { intValue = Int(s) }
        else { intValue = nil }
    }
}

/// Open Food Facts nutriment values (per 100 g). Values may be numbers or strings.
private struct OFFNutriments: Decodable {
    let energyKcal: Double?
    let fat: Double?
    let saturatedFat: Double?
    let carbohydrates: Double?
    let sugars: Double?
    let fiber: Double?
    let proteins: Double?
    let salt: Double?

    private struct DynamicKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicKey.self)
        func value(_ key: String) -> Double? {
            guard let k = DynamicKey(stringValue: key) else { return nil }
            if let v = try? c.decode(Double.self, forKey: k) { return v }
            if let s = try? c.decode(String.self, forKey: k) { return Double(s) }
            return nil
        }
        energyKcal = value("energy-kcal_100g")
        fat = value("fat_100g")
        saturatedFat = value("saturated-fat_100g")
        carbohydrates = value("carbohydrates_100g")
        sugars = value("sugars_100g")
        fiber = value("fiber_100g")
        proteins = value("proteins_100g")
        salt = value("salt_100g")
    }
}
