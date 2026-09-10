import AppKit
import AVFoundation
import Darwin
import Foundation
import ImageIO
import Vision

enum PocketItemKind: String, CaseIterable, Identifiable {
    case screenshot
    case recording
    case board

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .screenshot:
            "Screenshot"
        case .recording:
            "Recording"
        case .board:
            "Board"
        }
    }

    var systemImage: String {
        switch self {
        case .screenshot:
            "photo"
        case .recording:
            "video"
        case .board:
            "rectangle.stack"
        }
    }
}

struct PocketItem: Identifiable {
    let id: URL
    let url: URL
    let name: String
    let kind: PocketItemKind
    let modifiedAt: Date
    let sizeInBytes: Int64
    let thumbnail: NSImage

    var subtitle: String {
        "\(kind.displayName) - \(Self.dateFormatter.string(from: modifiedAt))"
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }

    var dateText: String {
        Self.dateFormatter.string(from: modifiedAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct SearchMatch: Equatable {
    let reason: String
    let score: Int
}

struct PocketItemMetadata: Codable, Equatable {
    var title = ""
    var note = ""
    var project = ""
    var category = ""
    var tags = ""
    var detectedText = ""
    var ocrSignature = ""
    var isPinned = false

    var hasContent: Bool {
        isPinned || !searchText.isEmpty || !ocrSignature.isEmpty
    }

    var searchText: String {
        [title, note, project, category, tags, detectedText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var hasDetectedText: Bool {
        !detectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// One recognized text line and its position on the image (normalized, top-left origin).
struct OCRTextBox: Codable, Equatable {
    var text: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
}

// Editable, non-destructive board layout so a saved moodboard can be reopened and rearranged.
struct StoredBoardPlacement: Codable {
    var sourcePath: String
    var caption: String
    var centerX: CGFloat
    var centerY: CGFloat
    var widthFraction: CGFloat
}

struct StoredBoardDocument: Codable {
    var title: String
    var aspect: String
    var background: String
    var hasRoundedCorners: Bool
    var hasShadow: Bool
    var showsTitle: Bool
    var placements: [StoredBoardPlacement]
}

enum OCRTextRecognizer {
    struct Result {
        var text: String
        var boxes: [OCRTextBox]
    }

    static func recognizeText(in imageURL: URL, languages: [String]) throws -> String {
        try recognize(in: imageURL, languages: languages).text
    }

    static func recognize(in imageURL: URL, languages: [String]) throws -> Result {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(url: imageURL)
        try handler.perform([request])

        let observations = request.results ?? []
        var lines: [String] = []
        var boxes: [OCRTextBox] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else {
                continue
            }
            lines.append(candidate.string)

            // Vision's boundingBox is normalized with a bottom-left origin; flip to top-left.
            let box = observation.boundingBox
            boxes.append(
                OCRTextBox(
                    text: candidate.string,
                    x: box.minX,
                    y: 1 - box.maxY,
                    width: box.width,
                    height: box.height
                )
            )
        }

        return Result(text: lines.joined(separator: "\n"), boxes: boxes)
    }
}

@MainActor
final class AppState: ObservableObject {
    let appName = "Scap"

    @Published var statusMessage = "Ready"
    @Published var searchQuery = ""
    @Published private(set) var libraryItems: [PocketItem] = []
    @Published private(set) var metadataByPath: [String: PocketItemMetadata] = [:]
    @Published private(set) var projects: [String] = []
    @Published private(set) var projectColors: [String: String] = [:]
    // Editable, non-destructive annotation layers (encoded JSON) keyed by source file path.
    @Published private(set) var annotationLayersByPath: [String: Data] = [:]
    // Recognized-text bounding boxes (encoded JSON) keyed by source file path.
    @Published private(set) var textBoxesByPath: [String: Data] = [:]
    // Editable board layouts (encoded JSON) keyed by the saved board's file path.
    @Published private(set) var boardDocumentsByPath: [String: Data] = [:]
    @Published private(set) var savedSearches: [String] = []
    private var backfillAttemptedPaths: Set<String> = []
    private var decodedTextBoxCache: [String: [OCRTextBox]] = [:]
    private var foldedDetectedTextCache: [String: String] = [:]
    @Published private(set) var ocrInProgressPaths: Set<String> = []
    @Published private(set) var watchedFolderURL: URL?
    @Published private(set) var libraryMessage = "Choose a folder or import screenshots and recordings to start your pocket."
    @Published private(set) var lastImportSummary = "No files imported yet."

    private let watchedFolderKey = "scap.watchedFolderPath"
    private let metadataKey = "scap.itemMetadataByPath"
    private let projectsKey = "scap.projects"
    private let projectColorsKey = "scap.projectColors"
    private let annotationsKey = "scap.annotationLayersByPath"
    private let textBoxesKey = "scap.textBoxesByPath"
    private let boardDocumentsKey = "scap.boardDocumentsByPath"
    private let savedSearchesKey = "scap.savedSearches"
    private let launchDate = Date()
    private var watcher: DispatchSourceFileSystemObject?
    private var watcherFileDescriptor: CInt = -1
    private var scanTask: DispatchWorkItem?

    private let supportedImageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif"]
    private let supportedVideoExtensions: Set<String> = ["mov", "mp4", "m4v"]

    private static let generatedFileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter
    }()

    var recentCaptureCount: Int {
        libraryItems.count
    }

    var screenshotCount: Int {
        libraryItems.filter { $0.kind == .screenshot }.count
    }

    var recordingCount: Int {
        libraryItems.filter { $0.kind == .recording }.count
    }

    var pinnedCount: Int {
        libraryItems.filter { metadata(for: $0).isPinned }.count
    }

    var recognizedTextCount: Int {
        libraryItems.filter { metadata(for: $0).hasDetectedText }.count
    }

    var projectNames: [String] {
        let metadataProjects = metadataByPath.values
            .map { $0.project.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Array(Set(projects + metadataProjects))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var librarySizeText: String {
        let size = libraryItems.reduce(Int64(0)) { partialResult, item in
            partialResult + item.sizeInBytes
        }

        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var emptyStateTitle: String {
        "Your pocket is empty."
    }

    var emptyStateMessage: String {
        "Import screenshots or choose the folder where macOS saves them."
    }

    var watchedFolderPath: String {
        watchedFolderURL?.path ?? "No folder selected"
    }

    var watchedFolderName: String {
        watchedFolderURL?.lastPathComponent ?? "No folder"
    }

    var defaultPocketFolderURL: URL {
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures", isDirectory: true)

        return picturesURL.appendingPathComponent("Scap", isDirectory: true)
    }

    var filteredItems: [PocketItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return libraryItems
        }

        return libraryItems
            .compactMap { item -> (item: PocketItem, match: SearchMatch)? in
                guard let match = searchMatch(for: item, query: query) else {
                    return nil
                }

                return (item, match)
            }
            .sorted { lhs, rhs in
                if lhs.match.score != rhs.match.score {
                    return lhs.match.score > rhs.match.score
                }

                return lhs.item.modifiedAt > rhs.item.modifiedAt
            }
            .map(\.item)
    }

    var hasActiveSearch: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init() {
        restoreProjects()
        restoreProjectColors()
        restoreMetadata()
        restoreAnnotationLayers()
        restoreTextBoxes()
        restoreBoardDocuments()
        restoreSavedSearches()
        restoreWatchedFolder()
    }

    deinit {
        watcher?.cancel()

        if watcherFileDescriptor >= 0 {
            close(watcherFileDescriptor)
        }
    }

    func chooseWatchedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Folder"
        panel.message = "Choose the folder where macOS saves screenshots and screen recordings."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            return
        }

        setWatchedFolder(folderURL)
    }

    func importFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Import"
        panel.message = "Choose screenshots or screen recordings to add to Scap."

        guard panel.runModal() == .OK else {
            return
        }

        importURLs(panel.urls)
    }

    func refreshLibrary() {
        scanWatchedFolder()
    }

    func useScapFolderForSystemScreenshots() {
        let folderURL = defaultPocketFolderURL

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try runProcess("/usr/bin/defaults", arguments: ["write", "com.apple.screencapture", "location", folderURL.path])
            try? runProcess("/usr/bin/killall", arguments: ["SystemUIServer"])

            setWatchedFolder(folderURL)
            statusMessage = "Screenshot folder set"
            lastImportSummary = "macOS screenshots now save to \(folderURL.lastPathComponent)."
            libraryMessage = "New screenshots and recordings made with macOS shortcuts will appear here."
        } catch {
            statusMessage = "Setup failed"
            libraryMessage = "Scap could not set the macOS screenshot folder automatically."
            lastImportSummary = error.localizedDescription
        }
    }

    func resetSystemScreenshotFolderToDesktop() {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)

        do {
            try runProcess("/usr/bin/defaults", arguments: ["write", "com.apple.screencapture", "location", desktopURL.path])
            try? runProcess("/usr/bin/killall", arguments: ["SystemUIServer"])

            setWatchedFolder(desktopURL)
            statusMessage = "Desktop restored"
            lastImportSummary = "macOS screenshots now save to Desktop."
            libraryMessage = "Watching \(desktopURL.path)"
        } catch {
            statusMessage = "Reset failed"
            lastImportSummary = error.localizedDescription
        }
    }

    func revealWatchedFolder() {
        guard let watchedFolderURL else {
            chooseWatchedFolder()
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([watchedFolderURL])
    }

    func openItem(_ item: PocketItem) {
        NSWorkspace.shared.open(item.url)
    }

    func revealItem(_ item: PocketItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func saveAnnotatedCopy(_ image: NSImage, basedOn item: PocketItem) -> Bool {
        guard let pngData = pngData(for: image) else {
            statusMessage = "Annotation failed"
            lastImportSummary = "Scap could not render the annotated image."
            return false
        }

        let folderURL = item.url.deletingLastPathComponent()
        let timestamp = Self.generatedFileDateFormatter.string(from: Date())
        let baseName = sanitizedFileName("\(displayName(for: item)) - Annotated \(timestamp)")
        let destinationURL = uniqueFileURL(
            in: folderURL,
            baseName: baseName,
            extension: "png"
        )

        do {
            try pngData.write(to: destinationURL, options: .atomic)
            guard let generatedItem = makePocketItem(from: destinationURL) else {
                statusMessage = "Annotation saved"
                lastImportSummary = "Annotated copy was saved, but Scap could not index it yet."
                scheduleFolderScan()
                return true
            }

            var merged: [URL: PocketItem] = [:]
            (libraryItems + [generatedItem]).forEach { merged[$0.id] = $0 }
            libraryItems = sortedItems(Array(merged.values))

            var copiedMetadata = metadata(for: item)
            copiedMetadata.title = "\(displayName(for: item)) Annotated"
            if copiedMetadata.hasContent {
                metadataByPath[destinationURL.path] = copiedMetadata
                persistMetadata()
            }

            queueOCR(for: [generatedItem], includeExistingFiles: true)
            statusMessage = "Annotation saved"
            lastImportSummary = "Annotated copy saved to Scap."
            scheduleFolderScan()
            return true
        } catch {
            statusMessage = "Annotation failed"
            lastImportSummary = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func saveBoard(_ image: NSImage, title: String, sourceItems: [PocketItem]) -> URL? {
        guard let pngData = pngData(for: image) else {
            statusMessage = "Board failed"
            lastImportSummary = "Scap could not render the board."
            return nil
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let boardTitle = trimmedTitle.isEmpty ? "Untitled Board" : trimmedTitle
        let timestamp = Self.generatedFileDateFormatter.string(from: Date())
        let folderURL = watchedFolderURL ?? sourceItems.first?.url.deletingLastPathComponent() ?? defaultPocketFolderURL
        let baseName = sanitizedFileName("\(boardTitle) - \(timestamp)")
        let destinationURL = uniqueFileURL(
            in: folderURL,
            baseName: baseName,
            extension: "png"
        )

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            try pngData.write(to: destinationURL, options: .atomic)

            guard let generatedItem = makePocketItem(from: destinationURL) else {
                statusMessage = "Board saved"
                lastImportSummary = "Board was saved, but Scap could not index it yet."
                scheduleFolderScan()
                return destinationURL
            }

            var merged: [URL: PocketItem] = [:]
            (libraryItems + [generatedItem]).forEach { merged[$0.id] = $0 }
            libraryItems = sortedItems(Array(merged.values))

            let inheritedProject = sharedProjectName(from: sourceItems)
            let inheritedTags = inheritedTags(from: sourceItems)
            var metadata = PocketItemMetadata()
            metadata.title = boardTitle
            metadata.category = "Board"
            metadata.project = inheritedProject
            metadata.tags = inheritedTags
            metadata.note = "Created from \(sourceItems.count) screenshot\(sourceItems.count == 1 ? "" : "s")."
            metadataByPath[destinationURL.path] = metadata
            persistMetadata()

            statusMessage = "Board saved"
            lastImportSummary = "Board saved to Scap."
            scheduleFolderScan()
            return destinationURL
        } catch {
            statusMessage = "Board failed"
            lastImportSummary = error.localizedDescription
            return nil
        }
    }

    /// Overwrite an existing board's PNG in place (used when editing a saved board).
    @discardableResult
    func updateBoardImage(_ image: NSImage, at url: URL) -> Bool {
        guard let pngData = pngData(for: image) else {
            return false
        }
        do {
            try pngData.write(to: url, options: .atomic)
            if let refreshed = makePocketItem(from: url) {
                var merged: [URL: PocketItem] = [:]
                libraryItems.forEach { merged[$0.id] = $0 }
                merged[refreshed.id] = refreshed
                libraryItems = sortedItems(Array(merged.values))
            }
            statusMessage = "Board updated"
            lastImportSummary = "Board changes saved."
            scheduleFolderScan()
            return true
        } catch {
            statusMessage = "Board failed"
            lastImportSummary = error.localizedDescription
            return false
        }
    }

    // MARK: - Editable board documents

    func hasBoardDocument(for item: PocketItem) -> Bool {
        boardDocumentsByPath[item.url.path] != nil
    }

    func boardDocument(forPath path: String) -> StoredBoardDocument? {
        guard let data = boardDocumentsByPath[path],
              let doc = try? JSONDecoder().decode(StoredBoardDocument.self, from: data) else {
            return nil
        }
        return doc
    }

    func setBoardDocument(_ document: StoredBoardDocument, forPath path: String) {
        if let data = try? JSONEncoder().encode(document) {
            boardDocumentsByPath[path] = data
            persistBoardDocuments()
        }
    }

    private func restoreBoardDocuments() {
        guard let stored = UserDefaults.standard.dictionary(forKey: boardDocumentsKey) as? [String: Data] else {
            return
        }
        boardDocumentsByPath = stored
    }

    private func persistBoardDocuments() {
        UserDefaults.standard.set(boardDocumentsByPath, forKey: boardDocumentsKey)
    }

    func metadata(for item: PocketItem) -> PocketItemMetadata {
        metadataByPath[item.url.path] ?? PocketItemMetadata()
    }

    func displayName(for item: PocketItem) -> String {
        let title = metadata(for: item).title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? item.name : title
    }

    func isRecognizingText(for item: PocketItem) -> Bool {
        ocrInProgressPaths.contains(item.url.path)
    }

    func clearSearch() {
        searchQuery = ""
    }

    // MARK: - Saved searches

    func saveCurrentSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              !savedSearches.contains(where: { $0.localizedCaseInsensitiveCompare(query) == .orderedSame }) else {
            return
        }
        savedSearches.append(query)
        persistSavedSearches()
        statusMessage = "Search saved"
    }

    func applySavedSearch(_ query: String) {
        searchQuery = query
    }

    func removeSavedSearch(_ query: String) {
        savedSearches.removeAll { $0 == query }
        persistSavedSearches()
    }

    var isCurrentSearchSaved: Bool {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return savedSearches.contains { $0.localizedCaseInsensitiveCompare(query) == .orderedSame }
    }

    private func restoreSavedSearches() {
        guard let stored = UserDefaults.standard.array(forKey: savedSearchesKey) as? [String] else {
            return
        }
        savedSearches = stored
    }

    private func persistSavedSearches() {
        UserDefaults.standard.set(savedSearches, forKey: savedSearchesKey)
    }

    func searchMatchReason(for item: PocketItem) -> String? {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return nil
        }

        return searchMatch(for: item, query: query)?.reason
    }

    func updateMetadata(_ metadata: PocketItemMetadata, for item: PocketItem) {
        let path = item.url.path
        var updatedMetadata = metadata
        let projectName = updatedMetadata.project.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMetadata.project = projectName

        if let existingMetadata = metadataByPath[path] {
            updatedMetadata.detectedText = existingMetadata.detectedText
            updatedMetadata.ocrSignature = existingMetadata.ocrSignature
        }

        if updatedMetadata.hasContent {
            metadataByPath[path] = updatedMetadata
        } else {
            metadataByPath.removeValue(forKey: path)
        }

        if !projectName.isEmpty {
            createProject(named: projectName)
        }

        persistMetadata()
        libraryItems = sortedItems(libraryItems)
        statusMessage = "Details saved"
        lastImportSummary = "Saved details for \(displayName(for: item))."
    }

    /// Append one or more comma-separated tags to every given item, skipping duplicates.
    func addTags(_ tagsText: String, to items: [PocketItem]) {
        let newTags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !newTags.isEmpty, !items.isEmpty else {
            return
        }

        for item in items {
            var metadata = metadata(for: item)
            var existing = metadata.tags
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for tag in newTags where !existing.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) {
                existing.append(tag)
            }

            metadata.tags = existing.joined(separator: ", ")
            updateMetadata(metadata, for: item)
        }

        statusMessage = "Tags added"
        lastImportSummary = "Added tags to \(items.count) item\(items.count == 1 ? "" : "s")."
    }

    func assignItem(_ item: PocketItem, toProject projectName: String?) {
        var metadata = metadata(for: item)
        metadata.project = projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateMetadata(metadata, for: item)

        if metadata.project.isEmpty {
            statusMessage = "Moved to Unassigned"
            lastImportSummary = "\(displayName(for: item)) is no longer assigned to a project."
        } else {
            statusMessage = "Moved to \(metadata.project)"
            lastImportSummary = "\(displayName(for: item)) moved to \(metadata.project)."
        }
    }

    func assignItems(_ items: [PocketItem], toProject projectName: String?) {
        guard !items.isEmpty else {
            return
        }

        let targetProject = projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !targetProject.isEmpty {
            createProject(named: targetProject)
        }

        items.forEach { item in
            var metadata = metadata(for: item)
            metadata.project = targetProject

            if metadata.hasContent {
                metadataByPath[item.url.path] = metadata
            } else {
                metadataByPath.removeValue(forKey: item.url.path)
            }
        }

        persistMetadata()
        libraryItems = sortedItems(libraryItems)

        if targetProject.isEmpty {
            statusMessage = "Moved to Unassigned"
            lastImportSummary = "\(items.count) file\(items.count == 1 ? "" : "s") moved to Unassigned."
        } else {
            statusMessage = "Moved to \(targetProject)"
            lastImportSummary = "\(items.count) file\(items.count == 1 ? "" : "s") moved to \(targetProject)."
        }
    }

    func importDroppedFiles(_ urls: [URL], toProject projectName: String?) {
        let importedItems = urls.compactMap(makePocketItem(from:))
        guard !importedItems.isEmpty else {
            statusMessage = "Nothing imported"
            lastImportSummary = "Dropped files are not supported screenshots or recordings."
            return
        }

        let targetProject = projectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !targetProject.isEmpty {
            createProject(named: targetProject)
        }

        if !targetProject.isEmpty {
            importedItems.forEach { item in
                var metadata = metadata(for: item)
                metadata.project = targetProject
                metadataByPath[item.url.path] = metadata
            }
            persistMetadata()
        }

        var merged: [URL: PocketItem] = [:]
        (libraryItems + importedItems).forEach { item in
            merged[item.id] = item
        }

        libraryItems = sortedItems(Array(merged.values))
        queueOCR(for: importedItems, includeExistingFiles: true)

        if targetProject.isEmpty {
            statusMessage = "Imported \(importedItems.count)"
            lastImportSummary = "Imported \(importedItems.count) file\(importedItems.count == 1 ? "" : "s")."
        } else {
            statusMessage = "Imported to \(targetProject)"
            lastImportSummary = "Imported \(importedItems.count) file\(importedItems.count == 1 ? "" : "s") to \(targetProject)."
        }
    }

    func createProject(named name: String) {
        let projectName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectName.isEmpty else {
            return
        }

        guard !projects.contains(where: { $0.localizedCaseInsensitiveCompare(projectName) == .orderedSame }) else {
            return
        }

        projects.append(projectName)
        projects.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        persistProjects()
        lastImportSummary = "\(projectName) is ready."
    }

    func projectColorName(for projectName: String) -> String {
        let key = projectColorKey(for: projectName)
        return projectColors[key] ?? defaultProjectColorName(for: projectName)
    }

    func setProjectColor(_ colorName: String, for projectName: String) {
        let key = projectColorKey(for: projectName)
        guard !key.isEmpty else {
            return
        }

        projectColors[key] = colorName
        persistProjectColors()
        lastImportSummary = "\(projectName) now uses \(colorName.lowercased())."
    }

    func renameProject(from oldName: String, to newName: String) {
        let originalName = oldName.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !originalName.isEmpty, !projectName.isEmpty else {
            return
        }

        guard originalName.localizedCaseInsensitiveCompare(projectName) != .orderedSame else {
            return
        }

        guard !projectNames.contains(where: { $0.localizedCaseInsensitiveCompare(projectName) == .orderedSame }) else {
            lastImportSummary = "\(projectName) already exists."
            return
        }

        projects.removeAll { $0.localizedCaseInsensitiveCompare(originalName) == .orderedSame }
        projects.append(projectName)
        projects.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        metadataByPath = metadataByPath.mapValues { metadata in
            var updatedMetadata = metadata
            if updatedMetadata.project.localizedCaseInsensitiveCompare(originalName) == .orderedSame {
                updatedMetadata.project = projectName
            }
            return updatedMetadata
        }

        let oldColorKey = projectColorKey(for: originalName)
        let newColorKey = projectColorKey(for: projectName)
        if let color = projectColors.removeValue(forKey: oldColorKey) {
            projectColors[newColorKey] = color
        }

        persistProjects()
        persistMetadata()
        persistProjectColors()
        lastImportSummary = "\(originalName) renamed to \(projectName)."
    }

    func rescanText(for item: PocketItem) {
        queueOCR(for: item, force: true)
    }

    func rescanAllText() {
        let screenshots = libraryItems.filter { $0.kind == .screenshot }
        guard !screenshots.isEmpty else {
            statusMessage = "No screenshots"
            lastImportSummary = "Text recognition is available for screenshots, not recordings."
            return
        }

        screenshots.forEach { queueOCR(for: $0, force: true) }
        statusMessage = "Scanning \(screenshots.count)"
        lastImportSummary = "Recognizing text in \(screenshots.count) screenshot\(screenshots.count == 1 ? "" : "s")."
    }

    func deleteItem(_ item: PocketItem) {
        do {
            let displayName = displayName(for: item)
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
            libraryItems.removeAll { $0.id == item.id }
            metadataByPath.removeValue(forKey: item.url.path)
            persistMetadata()
            statusMessage = "Moved to Trash"
            lastImportSummary = "\(displayName) was moved to Trash."
            scheduleFolderScan()
        } catch {
            statusMessage = "Delete failed"
            lastImportSummary = error.localizedDescription
        }
    }

    func deleteItems(_ items: [PocketItem]) {
        guard !items.isEmpty else {
            return
        }

        var deletedIDs = Set<URL>()
        var failureCount = 0

        for item in items {
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
                deletedIDs.insert(item.id)
            } catch {
                failureCount += 1
            }
        }

        if !deletedIDs.isEmpty {
            libraryItems.removeAll { deletedIDs.contains($0.id) }
            deletedIDs.forEach { metadataByPath.removeValue(forKey: $0.path) }
            persistMetadata()
            statusMessage = "Moved \(deletedIDs.count) to Trash"
            lastImportSummary = failureCount == 0
                ? "\(deletedIDs.count) file\(deletedIDs.count == 1 ? "" : "s") moved to Trash."
                : "\(deletedIDs.count) moved to Trash, \(failureCount) failed."
            scheduleFolderScan()
        } else {
            statusMessage = "Delete failed"
            lastImportSummary = "No selected files could be moved to Trash."
        }
    }

    func beginCaptureMode(_ mode: CaptureMode, trigger: String) {
        statusMessage = "Import ready"
        libraryMessage = "Scap now collects existing screenshots and recordings instead of capturing the screen."

        if watchedFolderURL == nil {
            chooseWatchedFolder()
        } else {
            WindowRouter.shared.showLibraryWindow()
        }
    }

    private func restoreWatchedFolder() {
        guard let path = UserDefaults.standard.string(forKey: watchedFolderKey), !path.isEmpty else {
            return
        }

        let folderURL = URL(fileURLWithPath: path, isDirectory: true)
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            UserDefaults.standard.removeObject(forKey: watchedFolderKey)
            return
        }

        setWatchedFolder(folderURL)
    }

    private func restoreMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metadataKey),
              let metadata = try? JSONDecoder().decode([String: PocketItemMetadata].self, from: data) else {
            return
        }

        metadataByPath = metadata
    }

    // MARK: - Editable annotation layers

    /// The saved, editable annotation layer for an item (if any). Encoded by the editor.
    func annotationLayerData(for item: PocketItem) -> Data? {
        annotationLayersByPath[item.url.path]
    }

    func hasAnnotationLayer(for item: PocketItem) -> Bool {
        annotationLayersByPath[item.url.path] != nil
    }

    /// Store (or clear, when `data` is nil) the editable annotation layer for an item.
    func setAnnotationLayerData(_ data: Data?, for item: PocketItem) {
        if let data {
            annotationLayersByPath[item.url.path] = data
        } else {
            annotationLayersByPath.removeValue(forKey: item.url.path)
        }
        persistAnnotationLayers()
    }

    private func restoreAnnotationLayers() {
        guard let stored = UserDefaults.standard.dictionary(forKey: annotationsKey) as? [String: Data] else {
            return
        }
        annotationLayersByPath = stored
    }

    private func persistAnnotationLayers() {
        UserDefaults.standard.set(annotationLayersByPath, forKey: annotationsKey)
    }

    // MARK: - OCR text boxes

    /// Recognized-text boxes for an item (normalized, top-left origin). Decodes lazily and
    /// caches the result so it isn't re-parsed on every SwiftUI render (e.g. per keystroke).
    func textBoxes(for item: PocketItem) -> [OCRTextBox] {
        let path = item.url.path
        if let cached = decodedTextBoxCache[path] {
            return cached
        }
        let boxes: [OCRTextBox]
        if let data = textBoxesByPath[path],
           let decoded = try? JSONDecoder().decode([OCRTextBox].self, from: data) {
            boxes = decoded
        } else {
            boxes = []
        }
        decodedTextBoxCache[path] = boxes
        return boxes
    }

    /// Quietly capture word boxes for a screenshot that already has recognized text but no
    /// stored boxes (e.g. scanned before this feature existed). Runs at most once per item
    /// per session and — crucially — does NOT flag the item as "scanning", so it never shows
    /// a spinner or blocks the detected-text view.
    func backfillTextBoxesIfNeeded(for item: PocketItem) {
        guard item.kind == .screenshot else {
            return
        }
        let path = item.url.path
        let metadata = metadata(for: item)
        guard metadata.hasDetectedText,
              textBoxesByPath[path] == nil,
              !backfillAttemptedPaths.contains(path),
              !ocrInProgressPaths.contains(path) else {
            return
        }

        backfillAttemptedPaths.insert(path)
        let imageURL = item.url
        let appState = self
        let languages = ocrRecognitionLanguages
        Task.detached(priority: .utility) {
            guard let recognition = try? OCRTextRecognizer.recognize(in: imageURL, languages: languages) else {
                return
            }
            await appState.storeTextBoxes(recognition.boxes, for: path)
        }
    }

    private func storeTextBoxes(_ boxes: [OCRTextBox], for path: String) {
        setTextBoxes(boxes, for: path)
    }

    private func setTextBoxes(_ boxes: [OCRTextBox], for path: String) {
        if boxes.isEmpty {
            textBoxesByPath.removeValue(forKey: path)
        } else if let data = try? JSONEncoder().encode(boxes) {
            textBoxesByPath[path] = data
        }
        decodedTextBoxCache[path] = boxes
        persistTextBoxes()
    }

    private func restoreTextBoxes() {
        guard let stored = UserDefaults.standard.dictionary(forKey: textBoxesKey) as? [String: Data] else {
            return
        }
        textBoxesByPath = stored
    }

    private func persistTextBoxes() {
        UserDefaults.standard.set(textBoxesByPath, forKey: textBoxesKey)
    }

    private func restoreProjects() {
        guard let data = UserDefaults.standard.data(forKey: projectsKey),
              let savedProjects = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }

        projects = Array(Set(savedProjects.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func restoreProjectColors() {
        guard let data = UserDefaults.standard.data(forKey: projectColorsKey),
              let savedColors = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }

        projectColors = savedColors
    }

    private func persistMetadata() {
        guard let data = try? JSONEncoder().encode(metadataByPath) else {
            return
        }

        UserDefaults.standard.set(data, forKey: metadataKey)
    }

    private func persistProjects() {
        guard let data = try? JSONEncoder().encode(projects) else {
            return
        }

        UserDefaults.standard.set(data, forKey: projectsKey)
    }

    private func persistProjectColors() {
        guard let data = try? JSONEncoder().encode(projectColors) else {
            return
        }

        UserDefaults.standard.set(data, forKey: projectColorsKey)
    }

    private func projectColorKey(for projectName: String) -> String {
        projectName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func defaultProjectColorName(for projectName: String) -> String {
        let colors = ["Blue", "Mint", "Orange", "Purple", "Pink", "Teal", "Yellow"]
        let seed = projectColorKey(for: projectName)
            .unicodeScalars
            .reduce(0) { partialResult, scalar in
                partialResult + Int(scalar.value)
            }

        return colors[seed % colors.count]
    }

    private func setWatchedFolder(_ folderURL: URL) {
        watchedFolderURL = folderURL
        UserDefaults.standard.set(folderURL.path, forKey: watchedFolderKey)
        statusMessage = "Watching \(folderURL.lastPathComponent)"
        libraryMessage = "Watching \(folderURL.path)"
        startWatching(folderURL)
        scanWatchedFolder()
    }

    private func importURLs(_ urls: [URL]) {
        let items = urls.compactMap(makePocketItem(from:))
        guard !items.isEmpty else {
            statusMessage = "Nothing imported"
            lastImportSummary = "No supported screenshots or recordings were selected."
            return
        }

        var merged: [URL: PocketItem] = [:]
        (libraryItems + items).forEach { item in
            merged[item.id] = item
        }

        libraryItems = sortedItems(Array(merged.values))
        queueOCR(for: items, includeExistingFiles: true)
        statusMessage = "Imported \(items.count)"
        lastImportSummary = "Imported \(items.count) file\(items.count == 1 ? "" : "s")."
    }

    private func scanWatchedFolder() {
        guard let watchedFolderURL else {
            libraryItems = []
            statusMessage = "Ready"
            libraryMessage = "Choose a folder or import screenshots and recordings to start your pocket."
            return
        }

        let fileURLs = filesInFolder(watchedFolderURL)
        let items = sortedItems(fileURLs.compactMap(makePocketItem(from:)))

        libraryItems = items
        queueOCR(for: items, includeExistingFiles: shouldScanExistingFilesWithOCR)
        statusMessage = items.isEmpty ? "Watching empty folder" : "Watching \(items.count) files"
        lastImportSummary = items.isEmpty
            ? "No screenshots or recordings found in \(watchedFolderURL.lastPathComponent)."
            : "Indexed \(items.count) file\(items.count == 1 ? "" : "s") from \(watchedFolderURL.lastPathComponent)."
    }

    private func filesInFolder(_ folderURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { element in
            guard let fileURL = element as? URL else {
                return nil
            }

            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true, kind(for: fileURL) != nil else {
                return nil
            }

            return fileURL
        }
    }

    private func makePocketItem(from url: URL) -> PocketItem? {
        guard let kind = kind(for: url) else {
            return nil
        }

        let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modifiedAt = resourceValues?.contentModificationDate ?? Date()
        let sizeInBytes = Int64(resourceValues?.fileSize ?? 0)

        return PocketItem(
            id: url,
            url: url,
            name: url.deletingPathExtension().lastPathComponent,
            kind: kind,
            modifiedAt: modifiedAt,
            sizeInBytes: sizeInBytes,
            thumbnail: thumbnail(for: url, kind: kind)
        )
    }

    private func pngData(for image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    private func sanitizedFileName(_ name: String) -> String {
        let illegalCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let components = name.components(separatedBy: illegalCharacters)
        let sanitized = components.joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? "Annotated Screenshot" : sanitized
    }

    private func uniqueFileURL(in folderURL: URL, baseName: String, extension fileExtension: String) -> URL {
        var candidate = folderURL.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension(fileExtension)
            index += 1
        }

        return candidate
    }

    private func sharedProjectName(from items: [PocketItem]) -> String {
        let projectNames = Set(
            items
                .map { metadata(for: $0).project.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        return projectNames.count == 1 ? projectNames.first ?? "" : ""
    }

    private func inheritedTags(from items: [PocketItem]) -> String {
        let tags = items.flatMap { item in
            metadata(for: item).tags
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        return Array(Set(tags))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .joined(separator: ", ")
    }

    private func sortedItems(_ items: [PocketItem]) -> [PocketItem] {
        items.sorted { lhs, rhs in
            let lhsPinned = metadata(for: lhs).isPinned
            let rhsPinned = metadata(for: rhs).isPinned

            if lhsPinned != rhsPinned {
                return lhsPinned && !rhsPinned
            }

            return lhs.modifiedAt > rhs.modifiedAt
        }
    }

    // Case- AND diacritic-insensitive normalization for search. Unicode diacritic folding
    // handles ą/ć/ę/ó/ś/ń/ź/ż, and ł/Ł (a stroked letter, not a diacritic) is mapped by hand
    // so Polish queries like "krakow" match "Kraków" and "laczka" matches "łączka".
    static func searchFold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: "ł", with: "l")
            .replacingOccurrences(of: "Ł", with: "l")
            .lowercased()
    }

    private func foldedDetectedText(_ text: String, path: String) -> String {
        if let cached = foldedDetectedTextCache[path] {
            return cached
        }
        let folded = Self.searchFold(text)
        foldedDetectedTextCache[path] = folded
        return folded
    }

    private func searchMatch(for item: PocketItem, query: String) -> SearchMatch? {
        let metadata = metadata(for: item)
        let foldedQuery = Self.searchFold(query)
        let path = item.url.path
        let fields: [(label: String, value: String, score: Int)] = [
            ("Title", displayName(for: item), 110),
            ("Tags", metadata.tags, 105),
            ("Project", metadata.project, 95),
            ("Category", metadata.category, 90),
            ("Note", metadata.note, 80),
            ("Detected Text", foldedDetectedText(metadata.detectedText, path: path), 75),
            ("Filename", item.name, 65),
            ("Kind", item.kind.displayName, 50),
            ("Date", item.dateText, 40),
            ("Size", item.sizeText, 30),
            ("Path", item.url.path, 25)
        ]

        return fields.compactMap { field in
            // Detected Text is pre-folded (cached); the other fields are short, fold inline.
            let haystack = field.label == "Detected Text" ? field.value : Self.searchFold(field.value)
            guard haystack.contains(foldedQuery) else {
                return nil
            }

            return SearchMatch(reason: field.label, score: field.score)
        }
        .max { $0.score < $1.score }
    }

    private var isAutomaticOCREnabled: Bool {
        loadBoolSetting(SettingsKeys.automaticOCR, fallback: true)
    }

    private var shouldScanExistingFilesWithOCR: Bool {
        loadBoolSetting(SettingsKeys.scanExistingFilesWithOCR, fallback: true)
    }

    private var ocrRecognitionLanguages: [String] {
        let languages = OCRLanguagePreference.enabledRecognitionCodes()
        return languages.isEmpty ? ["en-US"] : languages
    }

    private func queueOCR(for items: [PocketItem], includeExistingFiles: Bool) {
        items.forEach { item in
            if includeExistingFiles || item.modifiedAt >= launchDate {
                queueOCR(for: item, force: false)
            }
        }
    }

    private func queueOCR(for item: PocketItem, force: Bool) {
        guard force || isAutomaticOCREnabled else {
            return
        }

        guard item.kind == .screenshot else {
            if force {
                statusMessage = "OCR unavailable"
                lastImportSummary = "Text recognition is available for screenshots, not recordings."
            }
            return
        }

        let path = item.url.path
        let signature = ocrSignature(for: item)
        let metadata = metadata(for: item)

        guard force || metadata.ocrSignature != signature else {
            return
        }

        guard !ocrInProgressPaths.contains(path) else {
            return
        }

        ocrInProgressPaths.insert(path)

        if force {
            statusMessage = "Scanning text"
            lastImportSummary = "Recognizing text in \(displayName(for: item))."
        }

        let imageURL = item.url
        let appState = self
        let languages = ocrRecognitionLanguages
        Task.detached(priority: .utility) {
            let result: Result<OCRTextRecognizer.Result, Error>

            do {
                result = .success(try OCRTextRecognizer.recognize(in: imageURL, languages: languages))
            } catch {
                result = .failure(error)
            }

            await appState.finishOCR(path: path, signature: signature, result: result, force: force)
        }
    }

    private func finishOCR(path: String, signature: String, result: Result<OCRTextRecognizer.Result, Error>, force: Bool) {
        ocrInProgressPaths.remove(path)

        switch result {
        case .success(let recognition):
            var metadata = metadataByPath[path] ?? PocketItemMetadata()
            metadata.detectedText = recognition.text.trimmingCharacters(in: .whitespacesAndNewlines)
            metadata.ocrSignature = signature
            foldedDetectedTextCache.removeValue(forKey: path)

            if metadata.hasContent {
                metadataByPath[path] = metadata
            } else {
                metadataByPath.removeValue(forKey: path)
            }

            setTextBoxes(recognition.boxes, for: path)
            persistMetadata()

            if force {
                statusMessage = metadata.hasDetectedText ? "Text recognized" : "No text found"
                lastImportSummary = metadata.hasDetectedText
                    ? "Detected text was saved locally."
                    : "No readable text was found in this screenshot."
            }
        case .failure(let error):
            if force {
                statusMessage = "OCR failed"
                lastImportSummary = error.localizedDescription
            }
        }
    }

    private func ocrSignature(for item: PocketItem) -> String {
        "\(Int(item.modifiedAt.timeIntervalSince1970)):\(item.sizeInBytes)"
    }

    private func loadBoolSetting(_ key: String, fallback: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return fallback
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    private func kind(for url: URL) -> PocketItemKind? {
        let ext = url.pathExtension.lowercased()
        if supportedImageExtensions.contains(ext) {
            if url.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveContains("board") {
                return .board
            }

            return .screenshot
        }

        if supportedVideoExtensions.contains(ext) {
            return .recording
        }

        return nil
    }

    private func thumbnail(for url: URL, kind: PocketItemKind) -> NSImage {
        // Boards are image files too — load their picture, not the generic file icon.
        if kind == .screenshot || kind == .board {
            // Downsample to a small thumbnail via ImageIO. Full-resolution images (e.g. a
            // 3200×1800 board PNG) can fail to composite in a tile and show blank — and they
            // waste memory across a big library. A small thumbnail renders reliably.
            if let image = downsampledImage(at: url, maxPixel: 640) {
                return image
            }
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        if kind == .recording, let image = videoThumbnail(for: url) {
            return image
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 160, height: 100)
        return icon
    }

    private func downsampledImage(at url: URL, maxPixel: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func videoThumbnail(for url: URL) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 300)

        do {
            let image = try generator.copyCGImage(at: .zero, actualTime: nil)
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        } catch {
            return nil
        }
    }

    private func runProcess(_ executablePath: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw CocoaError(.executableLoad)
        }
    }

    private func startWatching(_ folderURL: URL) {
        watcher?.cancel()
        watcher = nil

        if watcherFileDescriptor >= 0 {
            close(watcherFileDescriptor)
            watcherFileDescriptor = -1
        }

        watcherFileDescriptor = open(folderURL.path, O_EVTONLY)
        guard watcherFileDescriptor >= 0 else {
            statusMessage = "Watch failed"
            libraryMessage = "Scap could not watch \(folderURL.path). Import files manually."
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: watcherFileDescriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.scheduleFolderScan()
        }

        source.setCancelHandler { [weak self] in
            guard let self else {
                return
            }

            if watcherFileDescriptor >= 0 {
                close(watcherFileDescriptor)
                watcherFileDescriptor = -1
            }
        }

        watcher = source
        source.resume()
    }

    private func scheduleFolderScan() {
        scanTask?.cancel()

        let task = DispatchWorkItem { [weak self] in
            self?.scanWatchedFolder()
        }

        scanTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
    }
}
