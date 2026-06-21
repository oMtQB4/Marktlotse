//
//  OpenGTINService.swift
//  Marktlotse
//
//  Product lookup using the OpenGTINDB API (https://opengtindb.org/api.php).
//  The API returns plain text key=value lines (ISO-8859-1 encoded), not JSON.
//

import Foundation

/// Abstraction so the lookup backend can be swapped or mocked.
protocol ProductLookupService {
    func lookup(barcode: String) async throws -> Article
    /// Optionally open the network connection ahead of the first lookup.
    func warmUp()
}

extension ProductLookupService {
    func warmUp() {}
}

enum ProductLookupError: LocalizedError {
    case notFound
    case invalidBarcode
    case network(Error)
    case server(code: Int)

    var errorDescription: String? {
        switch self {
        case .notFound: return "Zu diesem Barcode wurde kein Produkt gefunden."
        case .invalidBarcode: return "Der Barcode ist ungültig."
        case .network: return "Keine Verbindung zur Produktdatenbank."
        case .server(let code): return "Die Produktdatenbank meldete einen Fehler (\(code))."
        }
    }
}

final class OpenGTINService: ProductLookupService {

    private let session: URLSession
    private let queryIDProvider: () -> String
    private let baseURL = URL(string: "https://opengtindb.org/")!

    init(session: URLSession = .shared, queryIDProvider: @escaping () -> String) {
        self.session = session
        self.queryIDProvider = queryIDProvider
    }

    func lookup(barcode: String) async throws -> Article {
        guard Barcode.isLookupCandidate(barcode) else {
            throw ProductLookupError.invalidBarcode
        }

        let ean = Barcode.normalizedEAN(barcode)
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ean", value: ean),
            URLQueryItem(name: "cmd", value: "query"),
            URLQueryItem(name: "queryid", value: queryIDProvider())
        ]
        guard let url = components.url else { throw ProductLookupError.invalidBarcode }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue("Marktlotse/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProductLookupError.network(error)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ProductLookupError.server(code: http.statusCode)
        }

        let body = decode(data)
        let fields = Self.parse(body)

        // error=0 means success; anything else (or missing) means not found.
        if let errorValue = fields["error"], errorValue != "0" {
            throw ProductLookupError.notFound
        }

        let title = fields["name"] ?? fields["detailname"]
        guard let title, !title.isEmpty else {
            throw ProductLookupError.notFound
        }

        return Article(
            barcode: barcode,
            title: title,
            manufacturer: fields["vendor"],
            detailName: fields["detailname"],
            descriptionText: fields["descr"],
            category: fields["maincat"] ?? fields["subcat"],
            source: .openGTIN
        )
    }

    /// OpenGTINDB serves ISO-8859-1; fall back gracefully.
    private func decode(_ data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if let latin1 = String(data: data, encoding: .isoLatin1) { return latin1 }
        return String(decoding: data, as: UTF8.self)
    }

    /// Parses the plain-text "key=value" response into a dictionary.
    static func parse(_ body: String) -> [String: String] {
        var result: [String: String] = [:]
        for rawLine in body.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let separatorIndex = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<separatorIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            result[key.lowercased()] = value
        }
        return result
    }
}
