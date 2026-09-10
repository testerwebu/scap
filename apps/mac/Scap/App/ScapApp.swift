import AppKit
import Combine
import SwiftUI

@main
struct ScapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState
    @StateObject private var settingsStore: SettingsStore

    init() {
        let appState = AppState()
        let settingsStore = SettingsStore()
        _appState = StateObject(wrappedValue: appState)
        _settingsStore = StateObject(wrappedValue: settingsStore)
        appDelegate.configure(appState: appState, settingsStore: settingsStore)
    }

    var body: some Scene {
        Window("Scap", id: "library") {
            LibraryView()
                .environmentObject(appState)
                .environmentObject(settingsStore)
                .preferredColorScheme(settingsStore.appearance.colorScheme)
                .background(WindowRouterInstaller())
        }
        .defaultSize(width: 980, height: 680)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    WindowRouter.shared.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Window("Scap Settings", id: "settings") {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(settingsStore)
                .preferredColorScheme(settingsStore.appearance.colorScheme)
                .background(
                    WindowAccessor { window in
                        WindowRouter.shared.settingsWindow = window
                    }
                )
        }
        .defaultSize(width: 620, height: 760)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var appState: AppState?
    private weak var settingsStore: SettingsStore?
    private var statusItem: NSStatusItem?
    private var statusPopover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    func configure(appState: AppState, settingsStore: SettingsStore) {
        self.appState = appState
        self.settingsStore = settingsStore
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureStatusItem()
        configureHotKey()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowRouter.shared.showLibraryWindow()
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func configureHotKey() {
        guard let settingsStore else {
            return
        }

        HotKeyManager.shared.configure(shortcut: settingsStore.captureShortcut) {
            WindowRouter.shared.toggleLibraryWindow()
        }

        settingsStore.$captureShortcut
            .dropFirst()
            .sink { shortcut in
                HotKeyManager.shared.update(shortcut: shortcut)
            }
            .store(in: &cancellables)
    }

    private func configureStatusItem() {
        guard let appState, let settingsStore else {
            return
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 392, height: 560)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appState)
                .environmentObject(settingsStore)
                .preferredColorScheme(settingsStore.appearance.colorScheme)
        )
        statusPopover = popover

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = NSImage(named: "ScapLogo") {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageOnly
            } else if let image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Scap") {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "Scap"
            }
            button.toolTip = "Scap"
            button.action = #selector(toggleStatusPopover(_:))
            button.target = self
        }

        statusItem = item
    }

    @objc private func toggleStatusPopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = statusPopover else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

@MainActor
final class WindowRouter {
    static let shared = WindowRouter()

    var openLibraryWindow: (() -> Void)?
    var openSettingsWindow: (() -> Void)?
    weak var libraryWindow: NSWindow?
    weak var settingsWindow: NSWindow?

    private let libraryPanelSize = NSSize(width: 980, height: 680)
    private let libraryTopOffset: CGFloat = 28

    private init() {}

    func showLibraryWindow() {
        if let libraryWindow {
            configureLibraryPanel(libraryWindow)

            if libraryWindow.isMiniaturized {
                libraryWindow.deminiaturize(nil)
            }

            positionLibraryPanel(libraryWindow)
            libraryWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        openLibraryWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggleLibraryWindow() {
        if let libraryWindow, libraryWindow.isVisible {
            libraryWindow.orderOut(nil)
            return
        }

        showLibraryWindow()
    }

    func showSettingsWindow() {
        if let settingsWindow {
            if settingsWindow.isMiniaturized {
                settingsWindow.deminiaturize(nil)
            }

            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        openSettingsWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }

    func attachLibraryWindow(_ window: NSWindow) {
        libraryWindow = window
        configureLibraryPanel(window)
        positionLibraryPanel(window)
    }

    private func configureLibraryPanel(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.styleMask.insert(.fullSizeContentView)
        window.setContentSize(libraryPanelSize)
        window.minSize = NSSize(width: 760, height: 520)
    }

    private func positionLibraryPanel(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let width = min(libraryPanelSize.width, visibleFrame.width - 32)
        let height = min(libraryPanelSize.height, visibleFrame.height - 56)
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.maxY - height - libraryTopOffset
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}

private struct WindowRouterInstaller: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        WindowAccessor { window in
            WindowRouter.shared.attachLibraryWindow(window)
        }
        .frame(width: 0, height: 0)
        .onAppear {
            WindowRouter.shared.openLibraryWindow = {
                openWindow(id: "library")
                NSApp.activate(ignoringOtherApps: true)
            }

            WindowRouter.shared.openSettingsWindow = {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        resolveWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        resolveWindow(for: nsView)
    }

    private func resolveWindow(for view: NSView) {
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
    }
}
