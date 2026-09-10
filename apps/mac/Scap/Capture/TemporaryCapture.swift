import AppKit
import Foundation

struct TemporaryCapture: Identifiable {
    let id = UUID()
    let image: NSImage
    let mode: CaptureMode
    let createdAt: Date
    let pixelSize: CGSize
    let fileURL: URL?
    let backendName: String
    let diagnosticMessage: String

    var dimensionsText: String {
        "\(Int(pixelSize.width)) x \(Int(pixelSize.height)) px"
    }
}
