import AppKit
import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var isRecordingShortcut = false
    @State private var keyDownMonitor: Any?

    private let ocrLanguageColumns = [
        GridItem(.adaptive(minimum: 170), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scap Settings")
                        .font(.system(size: 17, weight: .semibold))

                    Text("Keep captures local, quiet and native.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Form {
                Section {
                    Toggle("Launch at login", isOn: $settingsStore.launchAtLogin)
                    Toggle("Show quick save panel", isOn: $settingsStore.showQuickSaveAfterCapture)
                } header: {
                    Text("General")
                } footer: {
                    Text("Launch at login is stored locally in Phase 00. The system login item service can be wired later.")
                }

                Section {
                    Picker("Appearance", selection: $settingsStore.appearance) {
                        ForEach(AppearancePreference.allCases) { appearance in
                            Text(appearance.displayName)
                                .tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                }

                Section {
                    LabeledContent("Open Shortcut") {
                        Text(settingsStore.captureShortcut.displayText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button {
                            toggleShortcutRecording()
                        } label: {
                            Label(
                                isRecordingShortcut ? "Press Shortcut..." : "Record Shortcut",
                                systemImage: isRecordingShortcut ? "keyboard.badge.ellipsis" : "keyboard"
                            )
                        }

                        Button("Reset") {
                            settingsStore.captureShortcut = .defaultCapture
                            stopShortcutRecording()
                        }
                        .disabled(settingsStore.captureShortcut == .defaultCapture)
                    }
                } header: {
                    Text("Keyboard Shortcut")
                } footer: {
                    Text("Use at least one modifier key. Default: Control Option S. The shortcut opens Scap so you can import or search files quickly.")
                }

                Section {
                    LabeledContent("Scap Folder", value: appState.defaultPocketFolderURL.path)

                    HStack {
                        Button {
                            appState.useScapFolderForSystemScreenshots()
                        } label: {
                            Label("Use for Screenshots", systemImage: "camera.viewfinder")
                        }

                        Button {
                            appState.resetSystemScreenshotFolderToDesktop()
                        } label: {
                            Label("Reset to Desktop", systemImage: "desktopcomputer")
                        }
                    }
                } header: {
                    Text("System Screenshot Folder")
                } footer: {
                    Text("Use for Screenshots creates a Scap folder in Pictures, tells macOS to save new screenshots and recordings there, and watches it automatically.")
                }

                Section {
                    LabeledContent("Watched Folder", value: appState.watchedFolderName)
                    LabeledContent("Path", value: appState.watchedFolderPath)

                    HStack {
                        Button {
                            appState.chooseWatchedFolder()
                        } label: {
                            Label("Choose Folder", systemImage: "folder.badge.gearshape")
                        }

                        Button {
                            appState.importFiles()
                        } label: {
                            Label("Import Files", systemImage: "tray.and.arrow.down")
                        }

                        Button {
                            appState.refreshLibrary()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }

                        Button {
                            appState.revealWatchedFolder()
                        } label: {
                            Label("Show in Finder", systemImage: "folder")
                        }
                    }
                } header: {
                    Text("Library Source")
                } footer: {
                    Text("Scap watches one local folder and indexes screenshots or screen recordings found there.")
                }

                Section {
                    LabeledContent("Indexed Items", value: "\(appState.libraryItems.count)")
                    LabeledContent("Screenshots", value: "\(appState.screenshotCount)")
                    LabeledContent("Recordings", value: "\(appState.recordingCount)")
                    LabeledContent("Pinned", value: "\(appState.pinnedCount)")
                    LabeledContent("With Detected Text", value: "\(appState.recognizedTextCount)")
                    LabeledContent("Library Size", value: appState.librarySizeText)
                    LabeledContent("Last Import", value: appState.lastImportSummary)
                } header: {
                    Text("Library Status")
                }

                Section {
                    Toggle("Recognize text automatically", isOn: $settingsStore.automaticOCR)
                    Toggle("Scan existing files in watched folders", isOn: $settingsStore.scanExistingFilesWithOCR)
                        .disabled(!settingsStore.automaticOCR)

                    LazyVGrid(columns: ocrLanguageColumns, alignment: .leading, spacing: 8) {
                        ForEach(OCRLanguagePreference.all) { language in
                            Toggle(language.displayName, isOn: ocrLanguageBinding(for: language))
                                .toggleStyle(.checkbox)
                        }
                    }
                    .disabled(!settingsStore.automaticOCR)

                    HStack {
                        Button {
                            settingsStore.enableAllOCRLanguages()
                        } label: {
                            Label("Select All Languages", systemImage: "checklist.checked")
                        }
                    }
                    .disabled(!settingsStore.automaticOCR)

                    Button {
                        appState.rescanAllText()
                    } label: {
                        Label("Re-scan All Screenshots", systemImage: "text.viewfinder")
                    }
                    .disabled(appState.screenshotCount == 0)
                } header: {
                    Text("Text Recognition")
                } footer: {
                    Text("OCR uses Apple Vision locally on this Mac. More enabled languages can make recognition slower. Turning off automatic recognition does not delete text that has already been saved.")
                }

                Section {
                    Text("Scap indexes screenshots and recordings that already exist on your Mac.")
                    Text("No Screen Recording permission is required for the current import-based workflow.")
                    Text("No account is required.")
                } header: {
                    Text("Privacy")
                }

                Section {
                    LabeledContent("Version", value: versionText)
                    LabeledContent("Build", value: buildText)
                } header: {
                    Text("About")
                }
            }
            .formStyle(.grouped)
        }
        .padding(.top, 20)
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
        .frame(width: 620, height: 760, alignment: .topLeading)
        .onDisappear {
            stopShortcutRecording()
        }
    }

    private var versionText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var buildText: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private func ocrLanguageBinding(for language: OCRLanguagePreference) -> Binding<Bool> {
        Binding {
            settingsStore.isOCRLanguageEnabled(language)
        } set: { isEnabled in
            settingsStore.setOCRLanguage(language, isEnabled: isEnabled)
        }
    }

    private func toggleShortcutRecording() {
        if isRecordingShortcut {
            stopShortcutRecording()
        } else {
            startShortcutRecording()
        }
    }

    private func startShortcutRecording() {
        stopShortcutRecording()
        isRecordingShortcut = true

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stopShortcutRecording()
                return nil
            }

            guard let shortcut = KeyboardShortcut.from(event: event) else {
                NSSound.beep()
                return nil
            }

            settingsStore.captureShortcut = shortcut
            stopShortcutRecording()
            return nil
        }
    }

    private func stopShortcutRecording() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }

        keyDownMonitor = nil
        isRecordingShortcut = false
    }
}
