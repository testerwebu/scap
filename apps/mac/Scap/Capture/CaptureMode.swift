import Foundation

enum CaptureMode: String, CaseIterable, Identifiable {
    case area
    case window
    case screen

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .area:
            "Capture Area"
        case .window:
            "Capture Window"
        case .screen:
            "Capture Screen"
        }
    }

    var shortName: String {
        switch self {
        case .area:
            "Area"
        case .window:
            "Window"
        case .screen:
            "Screen"
        }
    }

    var systemImage: String {
        switch self {
        case .area:
            "selection.pin.in.out"
        case .window:
            "macwindow"
        case .screen:
            "display"
        }
    }
}
