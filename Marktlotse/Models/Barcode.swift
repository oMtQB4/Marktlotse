//
//  Barcode.swift
//  Marktlotse
//
//  Lightweight barcode validation helpers, replacing the old DatabaseHandler
//  barcode-type checks. Only consumer product codes (GTIN/EAN/UPC/ISBN) are
//  supported now.
//

import Foundation

enum Barcode {

    /// Whether the string consists only of digits.
    static func isNumeric(_ code: String) -> Bool {
        !code.isEmpty && code.allSatisfy { $0.isNumber }
    }

    /// A GTIN is a numeric code of length 8, 12, 13 or 14.
    static func isGTIN(_ code: String) -> Bool {
        guard isNumeric(code) else { return false }
        return [8, 12, 13, 14].contains(code.count)
    }

    /// ISBN-10 / ISBN-13 (digits, optional trailing X for ISBN-10).
    static func isISBN(_ code: String) -> Bool {
        let trimmed = code.uppercased()
        if trimmed.count == 13, isNumeric(trimmed),
           trimmed.hasPrefix("978") || trimmed.hasPrefix("979") {
            return true
        }
        if trimmed.count == 10 {
            let head = trimmed.prefix(9)
            let last = trimmed.suffix(1)
            return head.allSatisfy { $0.isNumber } && (last == "X" || last.first!.isNumber)
        }
        return false
    }

    /// Any code we are willing to look up.
    static func isLookupCandidate(_ code: String) -> Bool {
        isGTIN(code) || isISBN(code) || (isNumeric(code) && code.count >= 6)
    }

    /// Validates the GTIN check digit (EAN-13/EAN-8, UPC-A, GTIN-14). Real retail
    /// codes always satisfy this, so a failing check digit signals a misread.
    /// Returns false for anything that isn't a GTIN-length numeric code.
    static func hasValidCheckDigit(_ code: String) -> Bool {
        guard isGTIN(code) else { return false }
        let digits = code.compactMap { $0.wholeNumberValue }
        guard digits.count == code.count, let check = digits.last else { return false }
        // Weight the data digits 3,1,3,1,… from the right.
        let sum = digits.dropLast().reversed().enumerated().reduce(0) { acc, pair in
            acc + pair.element * (pair.offset.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - (sum % 10)) % 10 == check
    }

    /// Normalises an EAN/GTIN for the OpenGTINDB query (13 digits, left padded).
    static func normalizedEAN(_ code: String) -> String {
        guard isNumeric(code) else { return code }
        if code.count >= 13 { return String(code.suffix(13)) }
        return String(repeating: "0", count: 13 - code.count) + code
    }
}
