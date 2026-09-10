import AppKit
import Foundation
import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .system:
            "System"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            nil
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }
    }
}

enum SettingsKeys {
    static let launchAtLogin = "settings.launchAtLogin"
    static let showQuickSaveAfterCapture = "settings.showQuickSaveAfterCapture"
    static let captureShortcut = "settings.captureShortcut"
    static let appearance = "settings.appearance"
    static let automaticOCR = "settings.automaticOCR"
    static let scanExistingFilesWithOCR = "settings.scanExistingFilesWithOCR"
    static let recognizeEnglishText = "settings.recognizeEnglishText"
    static let recognizePolishText = "settings.recognizePolishText"
    static let enabledOCRLanguageCodes = "settings.enabledOCRLanguageCodes"
}

struct OCRLanguagePreference: Identifiable, Hashable {
    let displayName: String
    let recognitionCode: String

    var id: String {
        recognitionCode
    }

    static let defaultCodes: Set<String> = ["en-US", "pl-PL"]

    static let all: [OCRLanguagePreference] = [
        OCRLanguagePreference(displayName: "English", recognitionCode: "en-US"),
        OCRLanguagePreference(displayName: "Polish", recognitionCode: "pl-PL"),
        OCRLanguagePreference(displayName: "German", recognitionCode: "de-DE"),
        OCRLanguagePreference(displayName: "French", recognitionCode: "fr-FR"),
        OCRLanguagePreference(displayName: "Spanish", recognitionCode: "es-ES"),
        OCRLanguagePreference(displayName: "Italian", recognitionCode: "it-IT"),
        OCRLanguagePreference(displayName: "Portuguese", recognitionCode: "pt-BR"),
        OCRLanguagePreference(displayName: "Dutch", recognitionCode: "nl-NL"),
        OCRLanguagePreference(displayName: "Czech", recognitionCode: "cs-CZ"),
        OCRLanguagePreference(displayName: "Ukrainian", recognitionCode: "uk-UA"),
        OCRLanguagePreference(displayName: "Russian", recognitionCode: "ru-RU"),
        OCRLanguagePreference(displayName: "Japanese", recognitionCode: "ja-JP"),
        OCRLanguagePreference(displayName: "Korean", recognitionCode: "ko-KR"),
        OCRLanguagePreference(displayName: "Chinese Simplified", recognitionCode: "zh-Hans"),
        OCRLanguagePreference(displayName: "Chinese Traditional", recognitionCode: "zh-Hant")
    ]

    static func enabledCodes(from defaults: UserDefaults = .standard) -> Set<String> {
        if let storedCodes = defaults.array(forKey: SettingsKeys.enabledOCRLanguageCodes) as? [String],
           !storedCodes.isEmpty {
            return Set(storedCodes)
        }

        var fallbackCodes = Set<String>()

        if loadBool(from: defaults, key: SettingsKeys.recognizeEnglishText, fallback: true) {
            fallbackCodes.insert("en-US")
        }

        if loadBool(from: defaults, key: SettingsKeys.recognizePolishText, fallback: true) {
            fallbackCodes.insert("pl-PL")
        }

        return fallbackCodes.isEmpty ? defaultCodes : fallbackCodes
    }

    static func enabledRecognitionCodes(from defaults: UserDefaults = .standard) -> [String] {
        let enabledCodes = enabledCodes(from: defaults)

        return all
            .filter { enabledCodes.contains($0.recognitionCode) }
            .map(\.recognitionCode)
    }

    private static func loadBool(from defaults: UserDefaults, key: String, fallback: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return fallback
        }

        return defaults.bool(forKey: key)
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: SettingsKeys.launchAtLogin)
        }
    }

    @Published var showQuickSaveAfterCapture: Bool {
        didSet {
            defaults.set(showQuickSaveAfterCapture, forKey: SettingsKeys.showQuickSaveAfterCapture)
        }
    }

    @Published var captureShortcut: KeyboardShortcut {
        didSet {
            save(captureShortcut, forKey: SettingsKeys.captureShortcut)
        }
    }

    @Published var appearance: AppearancePreference {
        didSet {
            defaults.set(appearance.rawValue, forKey: SettingsKeys.appearance)
            applyAppearance()
        }
    }

    @Published var automaticOCR: Bool {
        didSet {
            defaults.set(automaticOCR, forKey: SettingsKeys.automaticOCR)
        }
    }

    @Published var scanExistingFilesWithOCR: Bool {
        didSet {
            defaults.set(scanExistingFilesWithOCR, forKey: SettingsKeys.scanExistingFilesWithOCR)
        }
    }

    @Published private(set) var enabledOCRLanguageCodes: Set<String>

    var ocrRecognitionLanguages: [String] {
        OCRLanguagePreference.all
            .filter { enabledOCRLanguageCodes.contains($0.recognitionCode) }
            .map(\.recognitionCode)
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.launchAtLogin = defaults.bool(forKey: SettingsKeys.launchAtLogin)

        if defaults.object(forKey: SettingsKeys.showQuickSaveAfterCapture) == nil {
            self.showQuickSaveAfterCapture = true
        } else {
            self.showQuickSaveAfterCapture = defaults.bool(forKey: SettingsKeys.showQuickSaveAfterCapture)
        }

        self.captureShortcut = Self.loadShortcut(
            from: defaults,
            key: SettingsKeys.captureShortcut,
            fallback: .defaultCapture
        )

        if let storedAppearance = defaults.string(forKey: SettingsKeys.appearance),
           let appearance = AppearancePreference(rawValue: storedAppearance) {
            self.appearance = appearance
        } else {
            self.appearance = .system
        }

        self.automaticOCR = Self.loadBool(
            from: defaults,
            key: SettingsKeys.automaticOCR,
            fallback: true
        )
        self.scanExistingFilesWithOCR = Self.loadBool(
            from: defaults,
            key: SettingsKeys.scanExistingFilesWithOCR,
            fallback: true
        )
        self.enabledOCRLanguageCodes = OCRLanguagePreference.enabledCodes(from: defaults)

        Task { @MainActor in
            applyAppearance()
        }
    }

    func isOCRLanguageEnabled(_ language: OCRLanguagePreference) -> Bool {
        enabledOCRLanguageCodes.contains(language.recognitionCode)
    }

    func setOCRLanguage(_ language: OCRLanguagePreference, isEnabled: Bool) {
        var updatedCodes = enabledOCRLanguageCodes

        if isEnabled {
            updatedCodes.insert(language.recognitionCode)
        } else {
            updatedCodes.remove(language.recognitionCode)
        }

        guard !updatedCodes.isEmpty else {
            NSSound.beep()
            return
        }

        enabledOCRLanguageCodes = updatedCodes
        persistOCRLanguages()
    }

    func enableAllOCRLanguages() {
        enabledOCRLanguageCodes = Set(OCRLanguagePreference.all.map(\.recognitionCode))
        persistOCRLanguages()
    }

    private func applyAppearance() {
        NSApplication.shared.appearance = appearance.nsAppearance
    }

    private func save(_ shortcut: KeyboardShortcut, forKey key: String) {
        guard let data = try? JSONEncoder().encode(shortcut) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    private static func loadShortcut(
        from defaults: UserDefaults,
        key: String,
        fallback: KeyboardShortcut
    ) -> KeyboardShortcut {
        guard let data = defaults.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data),
              shortcut.hasModifier else {
            return fallback
        }

        return shortcut
    }

    private static func loadBool(from defaults: UserDefaults, key: String, fallback: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else {
            return fallback
        }

        return defaults.bool(forKey: key)
    }

    private func persistOCRLanguages() {
        defaults.set(
            OCRLanguagePreference.all
                .map(\.recognitionCode)
                .filter { enabledOCRLanguageCodes.contains($0) },
            forKey: SettingsKeys.enabledOCRLanguageCodes
        )
    }
}
