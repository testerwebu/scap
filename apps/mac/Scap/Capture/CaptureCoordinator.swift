import AppKit
import Foundation

@MainActor
final class CaptureCoordinator {
    private var areaOverlay: AreaCaptureOverlay?
    private var hiddenWindows: [NSWindow] = []
    private var captureTask: Task<Void, Never>?

    func startAreaCapture(completion: @escaping (Result<TemporaryCapture, CaptureCoordinatorError>) -> Void) {
        cancelAreaCapture()
        hideVisibleApplicationWindows()

        let overlay = AreaCaptureOverlay()
        areaOverlay = overlay

        overlay.start { [weak self] selection in
            guard let self else {
                return
            }

            areaOverlay = nil

            guard let selection else {
                restoreHiddenApplicationWindows()
                completion(.failure(.cancelled))
                return
            }

            captureSelectedArea(selection, completion: completion)
        }
    }

    func cancelAreaCapture() {
        areaOverlay?.cancel()
        areaOverlay = nil
        captureTask?.cancel()
        captureTask = nil
        restoreHiddenApplicationWindows()
    }

    private func captureSelectedArea(
        _ selection: AreaSelection,
        completion: @escaping (Result<TemporaryCapture, CaptureCoordinatorError>) -> Void
    ) {
        captureTask = Task { [weak self] in
            guard let self else {
                return
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Scap-\(UUID().uuidString).png")

            do {
                let result: ScreenCaptureResult
                if #available(macOS 14.0, *) {
                    result = try await ScreenCaptureService.captureAreaWithScreenCaptureKit(
                        selection,
                        outputURL: outputURL
                    )
                } else {
                    result = try ScreenCaptureService.captureArea(selection)
                }

                guard !Task.isCancelled else {
                    cleanupTemporaryFile(at: result.fileURL)
                    restoreHiddenApplicationWindows()
                    return
                }

                captureTask = nil
                restoreHiddenApplicationWindows()
                completion(.success(TemporaryCapture(
                    image: result.image,
                    mode: .area,
                    createdAt: Date(),
                    pixelSize: result.pixelSize,
                    fileURL: result.fileURL,
                    backendName: result.backendName,
                    diagnosticMessage: result.diagnosticMessage
                )))
            } catch {
                cleanupTemporaryFile(at: outputURL)

                guard !Task.isCancelled else {
                    restoreHiddenApplicationWindows()
                    return
                }

                captureTask = nil
                restoreHiddenApplicationWindows()
                completion(.failure(.captureFailed(error.localizedDescription)))
            }
        }
    }

    private func hideVisibleApplicationWindows() {
        hiddenWindows = NSApp.windows.filter { window in
            window.isVisible && window.level.rawValue < NSWindow.Level.screenSaver.rawValue
        }

        hiddenWindows.forEach { window in
            window.orderOut(nil)
        }
    }

    private func restoreHiddenApplicationWindows() {
        guard !hiddenWindows.isEmpty else {
            return
        }

        let windowsToRestore = hiddenWindows
        hiddenWindows.removeAll()

        windowsToRestore.forEach { window in
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func cleanupTemporaryFile(at fileURL: URL?) {
        guard let fileURL else {
            return
        }

        try? FileManager.default.removeItem(at: fileURL)
    }
}

enum CaptureCoordinatorError: LocalizedError, Equatable {
    case cancelled
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Area capture was cancelled."
        case .captureFailed(let message):
            message
        }
    }
}
