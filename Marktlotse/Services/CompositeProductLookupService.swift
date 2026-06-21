//
//  CompositeProductLookupService.swift
//  Marktlotse
//
//  Queries several product databases in order and returns the first match.
//  Used to combine Open Food Facts (food focus) with OpenGTINDB (broad).
//

import Foundation

final class CompositeProductLookupService: ProductLookupService {

    private let services: [ProductLookupService]

    init(services: [ProductLookupService]) {
        self.services = services
    }

    func lookup(barcode: String) async throws -> Article {
        guard Barcode.isLookupCandidate(barcode) else {
            throw ProductLookupError.invalidBarcode
        }

        var lastError: Error = ProductLookupError.notFound

        for service in services {
            do {
                return try await service.lookup(barcode: barcode)
            } catch let error as ProductLookupError {
                switch error {
                case .invalidBarcode:
                    throw error            // no point trying other sources
                case .notFound, .network, .server:
                    lastError = error      // try the next source
                }
            } catch {
                lastError = error
            }
        }

        throw lastError
    }
}
