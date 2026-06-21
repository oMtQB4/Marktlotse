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

    /// Normalises an EAN/GTIN for the OpenGTINDB query (13 digits, left padded).
    static func normalizedEAN(_ code: String) -> String {
        guard isNumeric(code) else { return code }
        if code.count >= 13 { return String(code.suffix(13)) }
        return String(repeating: "0", count: 13 - code.count) + code
    }
}
