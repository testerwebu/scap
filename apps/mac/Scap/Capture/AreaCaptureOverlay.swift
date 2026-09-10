import AppKit
import CoreGraphics

struct AreaSelection {
    let displayID: CGDirectDisplayID
    let screenFrame: CGRect
    let backingScaleFactor: CGFloat
    let rectInScreenPoints: CGRect
    let rectInGlobalPoints: CGRect
}

@MainActor
final class AreaCaptureOverlay {
    private var windows: [AreaSelectionWindow] = []
    private var completion: ((AreaSelection?) -> Void)?

    func start(completion: @escaping (AreaSelection?) -> Void) {
        self.completion = completion

        windows = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.displayID else {
                return nil
            }

            let window = AreaSelectionWindow(screen: screen)
            let view = AreaSelectionView(
                screen: screen,
                displayID: displayID,
                onComplete: { [weak self] selection in
                    self?.finish(with: selection)
                },
                onCancel: { [weak self] in
                    self?.finish(with: nil)
                }
            )

            window.cancelHandler = { [weak self] in
                self?.finish(with: nil)
            }
            window.contentView = view
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)

            return window
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.orderFrontRegardless()
        windows.first?.makeKey()
    }

    func cancel() {
        finish(with: nil)
    }

    private func finish(with selection: AreaSelection?) {
        let handler = completion
        completion = nil

        windows.forEach { $0.close() }
        windows.removeAll()

        handler?(selection)
    }
}

private final class AreaSelectionWindow: NSWindow {
    var cancelHandler: (() -> Void)?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setFrame(screen.frame, display: true)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            cancelHandler?()
            return
        }

        super.keyDown(with: event)
    }
}

private final class AreaSelectionView: NSView {
    private let screen: NSScreen
    private let displayID: CGDirectDisplayID
    private let onComplete: (AreaSelection) -> Void
    private let onCancel: () -> Void

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    init(
        screen: NSScreen,
        displayID: CGDirectDisplayID,
        onComplete: @escaping (AreaSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.screen = screen
        self.displayID = displayID
        self.onComplete = onComplete
        self.onCancel = onCancel

        super.init(frame: CGRect(origin: .zero, size: screen.frame.size))

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.32).setFill()
        bounds.fill()

        guard let selectionRect else {
            return
        }

        if let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.setBlendMode(.clear)
            context.fill(selectionRect)
            context.restoreGState()
        }

        NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
        selectionRect.fill()

        let border = NSBezierPath(roundedRect: selectionRect, xRadius: 3, yRadius: 3)
        border.lineWidth = 2
        NSColor.white.withAlphaComponent(0.95).setStroke()
        border.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPoint = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)

        guard let selectionRect, selectionRect.width >= 6, selectionRect.height >= 6 else {
            onCancel()
            return
        }

        let globalRect = CGRect(
            x: screen.frame.minX + selectionRect.minX,
            y: screen.frame.minY + selectionRect.minY,
            width: selectionRect.width,
            height: selectionRect.height
        )

        let selection = AreaSelection(
            displayID: displayID,
            screenFrame: screen.frame,
            backingScaleFactor: screen.backingScaleFactor,
            rectInScreenPoints: selectionRect,
            rectInGlobalPoints: globalRect
        )

        onComplete(selection)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }

        super.keyDown(with: event)
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else {
            return nil
        }

        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
        .intersection(bounds)
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        return CGDirectDisplayID(number.uint32Value)
    }
}
