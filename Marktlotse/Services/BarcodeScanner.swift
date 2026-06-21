//
//  BarcodeScanner.swift
//  Marktlotse
//
//  Abstraction over a barcode input source. Today only the device camera is
//  implemented, but this protocol lets a BLE / HID scanner be added later
//  without touching the rest of the app.
//

import Foundation

/// The kind of input a scanner uses.
enum ScannerKind: String, CaseIterable, Identifiable {
    case camera
    // case bluetooth   // reserved for a future external scanner

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .camera: return "Kamera"
        }
    }
}

/// A source that produces scanned barcode strings.
protocol BarcodeScannerSource: AnyObject {
    var kind: ScannerKind { get }
    /// Called on the main thread with each newly recognised barcode.
    var onScan: ((String) -> Void)? { get set }
    func start()
    func stop()
}
