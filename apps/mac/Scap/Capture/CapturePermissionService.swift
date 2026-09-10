import AppKit
import CoreGraphics
import Foundation

enum ScreenRecordingPermissionStatus: Equatable {
    case granted
    case missing
    case unknown

    var displayName: String {
        switch self {
        case .granted:
            "Screen Recording allowed"
        case .missing:
            "Screen Recording permission needed"
        case .unknown:
            "Screen Recording status unknown"
        }
    }
}

enum CapturePermissionService {
    static let screenRecordingServiceName = "ScreenCapture"

    static func screenRecordingStatus() -> ScreenRecordingPermissionStatus {
        if CGPreflightScreenCaptureAccess() {
            return .granted
        }

        return .missing
    }

    static func requestScreenRecordingPermission() -> ScreenRecordingPermissionStatus {
        if CGRequestScreenCaptureAccess() {
            return .granted
        }

        return screenRecordingStatus()
    }

    static func openScreenRecordingSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenRecording"
        ]

        for urlString in urls {
            guard let url = URL(string: urlString) else {
                continue
            }

            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    static func resetScreenRecordingPermission(bundleIdentifier: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", screenRecordingServiceName, bundleIdentifier]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
