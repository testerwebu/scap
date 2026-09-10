import AppKit
import CoreGraphics
import ImageIO
import Foundation
import ScreenCaptureKit
import UniformTypeIdentifiers

struct ScreenCaptureResult {
    let image: NSImage
    let pixelSize: CGSize
    let fileURL: URL?
    let backendName: String
    let diagnosticMessage: String
}

enum ScreenCaptureError: LocalizedError {
    case displayUnavailable
    case emptySelection
    case failed
    case permissionDeniedOrUnavailable
    case screenCaptureKitUnavailable

    var errorDescription: String? {
        switch self {
        case .displayUnavailable:
            "Scap could not find the selected display."
        case .emptySelection:
            "The selected area is too small to capture."
        case .failed:
            "Scap could not capture the selected area."
        case .permissionDeniedOrUnavailable:
            "macOS did not return screen pixels. Allow Scap in Screen & System Audio Recording, then quit and reopen the app."
        case .screenCaptureKitUnavailable:
            "ScreenCaptureKit area capture requires macOS 14 or newer."
        }
    }
}

enum ScreenCaptureService {
    static let primaryBackendName = "ScreenCaptureKit"

    static func loadCapture(from fileURL: URL) throws -> ScreenCaptureResult {
        guard let data = try? Data(contentsOf: fileURL),
              let image = NSImage(data: data) else {
            throw ScreenCaptureError.failed
        }

        let bitmap = NSBitmapImageRep(data: data)
        let pixelSize = CGSize(
            width: bitmap?.pixelsWide ?? Int(image.size.width),
            height: bitmap?.pixelsHigh ?? Int(image.size.height)
        )

        guard pixelSize.width > 1, pixelSize.height > 1 else {
            throw ScreenCaptureError.emptySelection
        }

        return ScreenCaptureResult(
            image: image,
            pixelSize: pixelSize,
            fileURL: fileURL,
            backendName: "System screencapture",
            diagnosticMessage: "Loaded PNG from \(fileURL.path)."
        )
    }

    @available(macOS 14.0, *)
    static func captureAreaWithScreenCaptureKit(
        _ selection: AreaSelection,
        outputURL: URL
    ) async throws -> ScreenCaptureResult {
        guard selection.rectInScreenPoints.width >= 1, selection.rectInScreenPoints.height >= 1 else {
            throw ScreenCaptureError.emptySelection
        }

        let content = try await shareableContent()
        guard let display = content.displays.first(where: { $0.displayID == selection.displayID }) else {
            throw ScreenCaptureError.displayUnavailable
        }

        let currentApplication = content.applications.first {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }

        let filter: SCContentFilter
        if let currentApplication {
            filter = SCContentFilter(
                display: display,
                excludingApplications: [currentApplication],
                exceptingWindows: []
            )
        } else {
            filter = SCContentFilter(display: display, excludingWindows: [])
        }

        let sourceRect = screenCaptureKitSourceRect(from: selection)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect
        configuration.width = max(1, Int((sourceRect.width * selection.backingScaleFactor).rounded(.up)))
        configuration.height = max(1, Int((sourceRect.height * selection.backingScaleFactor).rounded(.up)))
        configuration.showsCursor = false
        configuration.scalesToFit = false

        let cgImage = try await captureImage(contentFilter: filter, configuration: configuration)
        try writePNG(cgImage, to: outputURL)

        let image = NSImage(cgImage: cgImage, size: selection.rectInScreenPoints.size)
        return ScreenCaptureResult(
            image: image,
            pixelSize: CGSize(width: cgImage.width, height: cgImage.height),
            fileURL: outputURL,
            backendName: primaryBackendName,
            diagnosticMessage: "Captured \(Int(sourceRect.width)) x \(Int(sourceRect.height)) pt from display \(selection.displayID), excluding Scap windows."
        )
    }

    static func captureArea(_ selection: AreaSelection) throws -> ScreenCaptureResult {
        guard selection.rectInScreenPoints.width >= 1, selection.rectInScreenPoints.height >= 1 else {
            throw ScreenCaptureError.emptySelection
        }

        let scale = selection.backingScaleFactor
        let screenHeight = selection.screenFrame.height
        let pixelRect = CGRect(
            x: selection.rectInScreenPoints.minX * scale,
            y: (screenHeight - selection.rectInScreenPoints.maxY) * scale,
            width: selection.rectInScreenPoints.width * scale,
            height: selection.rectInScreenPoints.height * scale
        )
        .integral

        guard let cgImage = CGDisplayCreateImage(selection.displayID, rect: pixelRect) else {
            throw ScreenCaptureError.permissionDeniedOrUnavailable
        }

        guard cgImage.width > 1, cgImage.height > 1 else {
            throw ScreenCaptureError.failed
        }

        let image = NSImage(cgImage: cgImage, size: selection.rectInScreenPoints.size)
        return ScreenCaptureResult(
            image: image,
            pixelSize: CGSize(width: cgImage.width, height: cgImage.height),
            fileURL: nil,
            backendName: "CoreGraphics fallback",
            diagnosticMessage: "Captured display \(selection.displayID) through CGDisplayCreateImage."
        )
    }

    @available(macOS 14.0, *)
    private static func shareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let content else {
                    continuation.resume(throwing: ScreenCaptureError.permissionDeniedOrUnavailable)
                    return
                }

                continuation.resume(returning: content)
            }
        }
    }

    @available(macOS 14.0, *)
    private static func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image else {
                    continuation.resume(throwing: ScreenCaptureError.permissionDeniedOrUnavailable)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private static func screenCaptureKitSourceRect(from selection: AreaSelection) -> CGRect {
        CGRect(
            x: selection.rectInScreenPoints.minX,
            y: selection.screenFrame.height - selection.rectInScreenPoints.maxY,
            width: selection.rectInScreenPoints.width,
            height: selection.rectInScreenPoints.height
        )
        .integral
    }

    private static func writePNG(_ image: CGImage, to fileURL: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ScreenCaptureError.failed
        }

        CGImageDestinationAddImage(destination, image, nil)

        guard CGImageDestinationFinalize(destination) else {
            throw ScreenCaptureError.failed
        }
    }
}
