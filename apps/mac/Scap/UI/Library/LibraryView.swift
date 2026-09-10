import AppKit
import AVKit
import SwiftUI
import UniformTypeIdentifiers

// Inline recording player that keeps a single AVPlayer alive across detail re-renders.
private struct RecordingPlayerView: View {
    let url: URL
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .onChange(of: url) { newURL in
                player.pause()
                player.replaceCurrentItem(with: AVPlayerItem(url: newURL))
            }
            .onDisappear {
                player.pause()
            }
    }
}

private enum LibraryDisplayMode: String, CaseIterable, Identifiable {
    case grid
    case list
    case previewList

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .grid:
            "Tiles"
        case .list:
            "List"
        case .previewList:
            "List + Preview"
        }
    }

    var systemImage: String {
        switch self {
        case .grid:
            "square.grid.2x2"
        case .list:
            "list.bullet"
        case .previewList:
            "rectangle.split.2x1"
        }
    }
}

private enum LibraryFilterMode: String, CaseIterable, Identifiable {
    case all
    case screenshots
    case recordings
    case pinned
    case text

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            "All"
        case .screenshots:
            "Screenshots"
        case .recordings:
            "Recordings"
        case .pinned:
            "Pinned"
        case .text:
            "Text"
        }
    }
}

private enum LibrarySortMode: String, CaseIterable, Identifiable {
    case relevance
    case newest
    case oldest
    case name

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .relevance:
            "Relevance"
        case .newest:
            "Newest"
        case .oldest:
            "Oldest"
        case .name:
            "Name"
        }
    }
}

private struct BoardEditorPayload: Identifiable {
    let id = UUID()
    var items: [PocketItem] = []
    var editURL: URL? = nil
}

struct LibraryView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var pendingDeletion: PocketItem?
    @State private var isShowingDeleteAlert = false
    @State private var annotationItem: PocketItem?
    @State private var boardEditorPayload: BoardEditorPayload?
    @State private var isSelectionMode = false
    @State private var selectedItemIDs = Set<URL>()
    @State private var isShowingBulkDeleteAlert = false
    @State private var isBulkTagPopoverPresented = false
    @State private var bulkTagDraft = ""
    @State private var displayMode: LibraryDisplayMode = .previewList
    @State private var filterMode: LibraryFilterMode = .all
    @State private var sortMode: LibrarySortMode = .relevance
    @State private var selectedDetailItemID: URL?
    @State private var metadataDraft = PocketItemMetadata()
    @State private var detailImage: NSImage?
    @State private var highlightDetectedText = true
    @State private var selectedProjectFilter = "__all_projects__"
    @State private var newProjectName = ""
    @State private var hoveredFilterMode: LibraryFilterMode?
    @State private var hoveredProjectID: String?
    @State private var dropTargetProjectID: String?
    @State private var isProjectSidebarCollapsed = false
    @State private var expandedProjectIDs = Set<String>()
    @State private var renamingProjectID: String?
    @State private var projectRenameDraft = ""
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isProjectRenameFocused: Bool

    private let allProjectsFilter = "__all_projects__"
    private let unassignedProjectFilter = "__unassigned_project__"
    private let projectPreviewLimit = 8

    private var fastMotion: Animation {
        reduceMotion ? .linear(duration: 0.01) : .timingCurve(0.16, 1, 0.3, 1, duration: 0.16)
    }

    private var contentMotion: Animation {
        reduceMotion ? .linear(duration: 0.01) : .timingCurve(0.22, 1, 0.36, 1, duration: 0.22)
    }

    private var sidebarMotion: Animation {
        reduceMotion ? .linear(duration: 0.01) : .timingCurve(0.16, 1, 0.3, 1, duration: 0.24)
    }

    private let columns = [
        GridItem(.adaptive(minimum: 210, maximum: 260), spacing: 12)
    ]

    private var selectedItems: [PocketItem] {
        visibleItems.filter { selectedItemIDs.contains($0.id) }
    }

    private var selectedScreenshotItems: [PocketItem] {
        selectedItems.filter { $0.kind == .screenshot }
    }

    private var visibleItems: [PocketItem] {
        sortItems(filterProject(filterItems(appState.filteredItems)))
    }

    private var hasActiveFilters: Bool {
        filterMode != .all || selectedProjectFilter != allProjectsFilter
    }

    private var selectedDetailItem: PocketItem? {
        guard let selectedDetailItemID else {
            return nil
        }

        return appState.libraryItems.first { $0.id == selectedDetailItemID }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    projectColumn(availableHeight: max(280, geometry.size.height - 40))

                    ScrollView {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 18) {
                                header
                                searchField
                                searchTools
                                sourcePanel

                                if visibleItems.isEmpty {
                                    if appState.libraryItems.isEmpty, !appState.hasActiveSearch, !hasActiveFilters {
                                        emptyState
                                    } else {
                                        noResultsState
                                    }
                                } else {
                                    libraryContent
                                }
                            }
                            .frame(minWidth: 320, maxWidth: .infinity, alignment: .topLeading)

                            if let selectedDetailItem, geometry.size.width > 720 {
                                detailPanel(for: selectedDetailItem)
                                    .transition(
                                        .asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                                            removal: .opacity
                                        )
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height - 40, alignment: .topLeading)
                        .animation(contentMotion, value: selectedDetailItemID)
                        .animation(contentMotion, value: selectedProjectFilter)
                        .animation(contentMotion, value: filterMode)
                    }
                    .scrollIndicators(.visible)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                stickyActionBar
            }
        }
        .frame(minWidth: 760, minHeight: 520, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Move to Trash?", isPresented: $isShowingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                if let pendingDeletion {
                    appState.deleteItem(pendingDeletion)
                }
                pendingDeletion = nil
            }
        } message: {
            Text("This will move \(pendingDeletion?.name ?? "this item") to the macOS Trash.")
        }
        .alert("Move Selected to Trash?", isPresented: $isShowingBulkDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                appState.deleteItems(selectedItems)
                selectedItemIDs.removeAll()
                isSelectionMode = false
            }
        } message: {
            Text("This will move \(selectedItems.count) selected file\(selectedItems.count == 1 ? "" : "s") to the macOS Trash.")
        }
        .sheet(item: $annotationItem) { item in
            AnnotationEditorView(item: item)
                .environmentObject(appState)
        }
        .sheet(item: $boardEditorPayload, onDismiss: exitSelectionMode) { payload in
            Group {
                if let editURL = payload.editURL, let document = appState.boardDocument(forPath: editURL.path) {
                    BoardEditorView(editingBoardAt: editURL, document: document)
                } else {
                    BoardEditorView(items: payload.items)
                }
            }
            .environmentObject(appState)
        }
        .onChange(of: selectedDetailItemID) { _ in
            loadDetailDraft()
        }
        .onChange(of: appState.libraryItems.map(\.id)) { _ in
            if selectedDetailItem == nil {
                selectedDetailItemID = nil
            }
        }
        .onAppear {
            isSearchFocused = true
        }
        .onExitCommand {
            WindowRouter.shared.toggleLibraryWindow()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("ScapLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(appState.appName)
                    .font(.system(size: 22, weight: .semibold))

                Text(appState.statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            primaryToolbar
        }
    }

    private var primaryToolbar: some View {
        HStack(spacing: 8) {
            Button {
                appState.importFiles()
            } label: {
                Label("Import", systemImage: "tray.and.arrow.down")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.borderedProminent)

            Menu {
                Button {
                    appState.useScapFolderForSystemScreenshots()
                } label: {
                    Label("Use for Screenshots", systemImage: "camera.viewfinder")
                }

                Button {
                    appState.chooseWatchedFolder()
                } label: {
                    Label("Choose Folder", systemImage: "folder.badge.gearshape")
                }

                Button {
                    appState.refreshLibrary()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Divider()

                Button {
                    WindowRouter.shared.showSettingsWindow()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.bordered)
            .help("More")
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search screenshots, recordings, text, names or paths", text: $appState.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 18, weight: .medium))
                .focused($isSearchFocused)
                .onSubmit {
                    openCurrentResult()
                }

            Button {
                appState.saveCurrentSearch()
            } label: {
                Image(systemName: appState.isCurrentSearchSaved ? "bookmark.fill" : "bookmark")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(appState.isCurrentSearchSaved ? Color.accentColor : .secondary)
            .help("Save this search")
            .disabled(!appState.hasActiveSearch || appState.isCurrentSearchSaved)
            .opacity(appState.hasActiveSearch ? 1 : 0.35)

            Button {
                appState.clearSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Clear search")
            .disabled(!appState.hasActiveSearch)
            .opacity(appState.hasActiveSearch ? 1 : 0.35)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSearchFocused ? Color.accentColor.opacity(0.75) : Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private var searchTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                filterChips

                Spacer(minLength: 0)
            }

            if !appState.savedSearches.isEmpty {
                savedSearchChips
            }

            ViewThatFits(in: .horizontal) {
                searchToolRow

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        viewModePicker
                        sortPicker
                    }

                    topSelectionControls
                }
            }
        }
    }

    private var searchToolRow: some View {
        HStack(spacing: 8) {
            viewModePicker
            sortPicker

            Spacer(minLength: 12)

            topSelectionControls
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var savedSearchChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                ForEach(appState.savedSearches, id: \.self) { query in
                    HStack(spacing: 4) {
                        Button {
                            appState.applySavedSearch(query)
                        } label: {
                            Text(query)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)

                        Button {
                            appState.removeSavedSearch(query)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Remove saved search")
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            appState.searchQuery.localizedCaseInsensitiveCompare(query) == .orderedSame
                                ? Color.accentColor.opacity(0.18)
                                : Color(nsColor: .controlBackgroundColor)
                        )
                    )
                }
            }
        }
    }

    private var filterChips: some View {
        HStack(spacing: 6) {
            ForEach(LibraryFilterMode.allCases) { mode in
                Button {
                    filterMode = mode
                } label: {
                    Text(mode.title)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(minWidth: 74, minHeight: 30)
                        .padding(.horizontal, 8)
                        .background(filterChipBackground(for: mode))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(filterMode == mode ? Color.accentColor.opacity(0.35) : Color(nsColor: .separatorColor), lineWidth: 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(filterMode == mode ? Color.accentColor : Color.primary)
                .onHover { isHovering in
                    hoveredFilterMode = isHovering ? mode : (hoveredFilterMode == mode ? nil : hoveredFilterMode)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func filterChipBackground(for mode: LibraryFilterMode) -> Color {
        if filterMode == mode {
            return Color.accentColor.opacity(0.13)
        }

        if hoveredFilterMode == mode {
            return Color(nsColor: .controlAccentColor).opacity(0.07)
        }

        return Color(nsColor: .controlBackgroundColor)
    }

    private var resultCountText: String {
        if visibleItems.count == appState.libraryItems.count, !appState.hasActiveSearch, !hasActiveFilters {
            return "\(visibleItems.count) indexed"
        }

        return "\(visibleItems.count) of \(appState.libraryItems.count) shown"
    }

    private var sourcePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(sourceTitle, systemImage: "folder")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Text("\(appState.libraryItems.count) files")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Text(sourceSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    appState.revealWatchedFolder()
                } label: {
                    Label("Reveal", systemImage: "finder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private var sourceTitle: String {
        appState.watchedFolderURL == nil ? "No screenshot folder" : appState.watchedFolderName
    }

    private var sourceSubtitle: String {
        appState.watchedFolderURL == nil
            ? "Choose a folder or import files to start."
            : "Watching screenshot and recording files."
    }

    private func projectColumn(availableHeight: CGFloat) -> some View {
        Group {
            if isProjectSidebarCollapsed {
                Button {
                    withAnimation(sidebarMotion) {
                        isProjectSidebarCollapsed = false
                    }
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .padding(.vertical, 10)
                    .frame(width: 48)
                    .frame(height: availableHeight, alignment: .top)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 5, y: 0)
                }
                .buttonStyle(.plain)
                .help("Show projects")
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
            } else {
                projectSidebar(availableHeight: availableHeight)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(sidebarMotion, value: isProjectSidebarCollapsed)
    }

    private func projectSidebar(availableHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                Spacer()

                Button {
                    withAnimation(sidebarMotion) {
                        isProjectSidebarCollapsed = true
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 1)
                }
                .help("Hide sidebar")
            }

            Button {
                createDefaultProject()
            } label: {
                Text("Add new project")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    projectButton(title: "All", systemImage: "tray.full", id: allProjectsFilter, count: appState.libraryItems.count)
                    projectButton(title: "Unassigned", systemImage: "tray", id: unassignedProjectFilter, count: unassignedItemCount)

                    if !appState.projectNames.isEmpty {
                        Divider()
                            .padding(.vertical, 2)
                    }

                    ForEach(appState.projectNames, id: \.self) { project in
                        projectSection(project)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.automatic)
            .frame(maxHeight: .infinity, alignment: .top)

            Spacer(minLength: 8)
        }
        .padding(12)
        .frame(width: 192, alignment: .topLeading)
        .frame(height: availableHeight, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor).opacity(0.92),
                    Color(nsColor: .controlBackgroundColor).opacity(0.68)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 8, y: 0)
        .shadow(color: Color.accentColor.opacity(0.035), radius: 10, x: 3, y: 0)
    }

    private func projectSection(_ project: String) -> some View {
        let isExpanded = expandedProjectIDs.contains(project)

        return VStack(alignment: .leading, spacing: 4) {
            projectButton(
                title: project,
                systemImage: isExpanded ? "folder.fill" : "folder",
                id: project,
                count: projectItemCount(project),
                isExpandable: true
            )

            if isExpanded {
                projectPreviewList(for: project)
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .move(edge: .top))
                                .combined(with: .scale(scale: 0.98, anchor: .top)),
                            removal: .opacity
                                .combined(with: .move(edge: .top))
                                .combined(with: .scale(scale: 0.98, anchor: .top))
                        )
                    )
            }
        }
        .animation(sidebarMotion, value: expandedProjectIDs)
    }

    @ViewBuilder
    private func projectButton(title: String, systemImage: String, id: String, count: Int, isExpandable: Bool = false) -> some View {
        let isExpanded = expandedProjectIDs.contains(id)
        let isRenaming = renamingProjectID == id

        let projectRow = HStack(spacing: 7) {
            if isExpandable {
                Button {
                    guard !isRenaming else {
                        return
                    }

                    toggleProjectExpansion(id)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: 24)
                            .rotationEffect(.degrees(isExpanded ? 0 : -2))

                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(projectColor(for: title))
                            .frame(width: 16)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isExpanded ? "Collapse project preview" : "Expand project preview")
            }

            Button {
                guard !isRenaming else {
                    return
                }

                withAnimation(fastMotion) {
                    selectedProjectFilter = id
                }
            } label: {
                HStack(spacing: 7) {
                    if !isExpandable {
                        Image(systemName: systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 16)
                    }

                    if isRenaming {
                        TextField("Project name", text: $projectRenameDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .focused($isProjectRenameFocused)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.accentColor.opacity(0.75))
                                    .frame(height: 1)
                            }
                            .onSubmit {
                                commitProjectRename(id)
                            }
                            .onExitCommand {
                                cancelProjectRename()
                            }
                    } else {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .onTapGesture(count: 2) {
                                beginProjectRename(id)
                            }
                    }

                    Spacer(minLength: 0)

                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(isExpandable ? "Open \(title)" : "Show \(title)")
            .contextMenu {
                if isExpandable {
                    Button("Rename") {
                        beginProjectRename(id)
                    }
                }
            }

            if isExpandable {
                projectColorMenu(for: title)
                    .frame(width: 20, height: 28)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        .background(projectRowBackground(for: id))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(dropTargetProjectID == id ? Color.accentColor.opacity(0.75) : Color.clear, lineWidth: 1)
        }
        .scaleEffect(dropTargetProjectID == id ? 1.015 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .onHover { isHovering in
            withAnimation(fastMotion) {
                hoveredProjectID = isHovering ? id : (hoveredProjectID == id ? nil : hoveredProjectID)
            }
        }
        .animation(fastMotion, value: hoveredProjectID)
        .animation(fastMotion, value: dropTargetProjectID)

        if id == allProjectsFilter {
            projectRow
        } else {
            projectRow
                .onDrop(
                    of: projectDropTypes,
                    isTargeted: projectDropTargetBinding(for: id)
                ) { providers in
                    assignDroppedItems(from: providers, to: id)
                }
        }
    }

    private func projectPreviewList(for project: String) -> some View {
        let items = projectItems(project)
        let previewItems = Array(items.prefix(projectPreviewLimit))
        let hiddenCount = max(items.count - previewItems.count, 0)
        let color = projectColor(for: project)

        return VStack(alignment: .leading, spacing: 3) {
            if previewItems.isEmpty {
                Text("No files yet")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 31)
                    .padding(.vertical, 4)
            } else {
                ForEach(previewItems) { item in
                    projectPreviewRow(item)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if hiddenCount > 0 {
                    Text("+ \(hiddenCount) more")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 31)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 5)
        .background(color.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.28))
                .frame(width: 2)
        }
        .padding(.bottom, 4)
    }

    private func projectPreviewRow(_ item: PocketItem) -> some View {
        Button {
            selectedDetailItemID = item.id
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.kind.systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)

                Text(appState.displayName(for: item))
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.leading, 25)
            .padding(.trailing, 7)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectedDetailItemID == item.id ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(appState.displayName(for: item))
        .animation(fastMotion, value: selectedDetailItemID)
    }

    private func projectColorMenu(for project: String) -> some View {
        Menu {
            ForEach(projectColorOptions, id: \.name) { option in
                Button {
                    appState.setProjectColor(option.name, for: project)
                } label: {
                    Label(option.name, systemImage: appState.projectColorName(for: project) == option.name ? "checkmark.circle.fill" : "circle.fill")
                }
            }
        } label: {
            Circle()
                .fill(projectColor(for: project))
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .stroke(Color.primary.opacity(0.16), lineWidth: 1)
                }
                .frame(width: 18, height: 18)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Project color")
    }

    private var projectColorOptions: [(name: String, color: Color)] {
        [
            ("Blue", .blue),
            ("Mint", .mint),
            ("Orange", .orange),
            ("Purple", .purple),
            ("Pink", .pink),
            ("Teal", .teal),
            ("Yellow", .yellow),
            ("Gray", .gray)
        ]
    }

    private func projectColor(for project: String) -> Color {
        let colorName = appState.projectColorName(for: project)
        return projectColorOptions.first { $0.name == colorName }?.color ?? .blue
    }

    private func projectRowBackground(for id: String) -> Color {
        if dropTargetProjectID == id {
            return Color.accentColor.opacity(0.2)
        }

        if selectedProjectFilter == id {
            return Color.accentColor.opacity(0.13)
        }

        if hoveredProjectID == id {
            return Color(nsColor: .controlAccentColor).opacity(0.07)
        }

        return Color.clear
    }

    private func projectDropTargetBinding(for id: String) -> Binding<Bool> {
        Binding {
            dropTargetProjectID == id
        } set: { isTargeted in
            if isTargeted {
                dropTargetProjectID = id
            } else if dropTargetProjectID == id {
                dropTargetProjectID = nil
            }
        }
    }

    private var unassignedItemCount: Int {
        appState.libraryItems.filter { appState.metadata(for: $0).project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private func projectItemCount(_ project: String) -> Int {
        projectItems(project).count
    }

    private func projectItems(_ project: String) -> [PocketItem] {
        appState.libraryItems.filter { appState.metadata(for: $0).project.localizedCaseInsensitiveCompare(project) == .orderedSame }
    }

    private func toggleProjectExpansion(_ id: String) {
        withAnimation(sidebarMotion) {
            if expandedProjectIDs.contains(id) {
                expandedProjectIDs.remove(id)
            } else {
                expandedProjectIDs.insert(id)
            }
        }
    }

    private func beginProjectRename(_ id: String) {
        projectRenameDraft = id
        renamingProjectID = id

        DispatchQueue.main.async {
            isProjectRenameFocused = true
        }
    }

    private func commitProjectRename(_ id: String) {
        let newName = projectRenameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else {
            cancelProjectRename()
            return
        }

        appState.renameProject(from: id, to: newName)

        if selectedProjectFilter.localizedCaseInsensitiveCompare(id) == .orderedSame {
            selectedProjectFilter = newName
        }

        if expandedProjectIDs.remove(id) != nil {
            expandedProjectIDs.insert(newName)
        }

        renamingProjectID = nil
        projectRenameDraft = ""
    }

    private func cancelProjectRename() {
        renamingProjectID = nil
        projectRenameDraft = ""
    }

    private func createDefaultProject() {
        let projectName = nextDefaultProjectName()

        appState.createProject(named: projectName)
        selectedProjectFilter = projectName
        expandedProjectIDs.insert(projectName)
        beginProjectRename(projectName)
    }

    private func nextDefaultProjectName() -> String {
        let baseName = "New folder"
        let existingNames = Set(appState.projectNames.map { $0.lowercased() })

        guard existingNames.contains(baseName.lowercased()) else {
            return baseName
        }

        var index = 2
        while existingNames.contains("\(baseName) \(index)".lowercased()) {
            index += 1
        }

        return "\(baseName) \(index)"
    }

    private func createProject() {
        let projectName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectName.isEmpty else {
            return
        }

        appState.createProject(named: projectName)
        selectedProjectFilter = projectName
        newProjectName = ""
    }

    private func filterProject(_ items: [PocketItem]) -> [PocketItem] {
        switch selectedProjectFilter {
        case allProjectsFilter:
            return items
        case unassignedProjectFilter:
            return items.filter { appState.metadata(for: $0).project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        default:
            return items.filter { appState.metadata(for: $0).project.localizedCaseInsensitiveCompare(selectedProjectFilter) == .orderedSame }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Choose where screenshots land.", systemImage: "tray")
                .font(.system(size: 16, weight: .semibold))

            Text(appState.emptyStateMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    appState.useScapFolderForSystemScreenshots()
                } label: {
                    Label("Use Scap Folder", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    appState.importFiles()
                } label: {
                    Label("Import Files", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var noResultsState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("No matching items.", systemImage: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))

            Text(noResultsMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Button {
                appState.clearSearch()
                filterMode = .all
                selectedProjectFilter = allProjectsFilter
            } label: {
                Label("Clear Search and Filters", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var noResultsMessage: String {
        let query = appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if !query.isEmpty, hasActiveFilters {
            return "No files match \"\(query)\" with the current filter."
        }

        if !query.isEmpty {
            return "No files match \"\(query)\"."
        }

        return "No files match the current filter."
    }

    @ViewBuilder
    private var libraryContent: some View {
        switch displayMode {
        case .grid:
            libraryGrid
        case .list:
            libraryList
        case .previewList:
            previewList
        }
    }

    private var libraryGrid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(visibleItems) { item in
                libraryCard(item)
            }
        }
    }

    private var libraryList: some View {
        LazyVStack(alignment: .leading, spacing: 6) {
            ForEach(visibleItems) { item in
                compactRow(item)
            }
        }
    }

    private var previewList: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(visibleItems) { item in
                previewRow(item)
            }
        }
    }

    @ViewBuilder
    private var stickyActionBar: some View {
        if isSelectionMode {
            Divider()

            selectionActionBar
        }
    }

    private var selectionActionBar: some View {
        // Wrap to two rows when narrow instead of scrolling horizontally (which used to hide
        // "Create Board" off the right edge with no visible scrollbar).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                selectionCountLabel
                selectVisibleButton
                createBoardButton
                bulkTagButton
                deleteSelectedButton
                doneSelectionButton
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    selectionCountLabel
                    createBoardButton
                    bulkTagButton
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    selectVisibleButton
                    deleteSelectedButton
                    doneSelectionButton
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var selectionCountLabel: some View {
        Text("\(selectedItems.count) selected")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selectedItems.isEmpty ? .secondary : .primary)
            .frame(minWidth: 86, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var selectVisibleButton: some View {
        Button {
            selectVisibleItems()
        } label: {
            Label(allVisibleItemsSelected ? "Clear Visible" : "Select Visible", systemImage: allVisibleItemsSelected ? "circle" : "checklist.checked")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
        .disabled(visibleItems.isEmpty)
    }

    private var createBoardButton: some View {
        Button {
            boardEditorPayload = BoardEditorPayload(items: Array(selectedScreenshotItems.prefix(12)))
        } label: {
            Label("Create Board", systemImage: "rectangle.stack.badge.plus")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
        .disabled(selectedScreenshotItems.count < 2)
        .help("Create a moodboard from selected screenshots (needs 2+)")
    }

    private var bulkTagButton: some View {
        Button {
            bulkTagDraft = ""
            isBulkTagPopoverPresented = true
        } label: {
            Label("Add Tags", systemImage: "tag")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
        .disabled(selectedItems.isEmpty)
        .help("Add tags to all selected items")
        .popover(isPresented: $isBulkTagPopoverPresented, arrowEdge: .top) {
            bulkTagPopover
        }
    }

    private var deleteSelectedButton: some View {
        Button(role: .destructive) {
            isShowingBulkDeleteAlert = true
        } label: {
            Label("Delete Selected", systemImage: "trash")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
        .disabled(selectedItems.isEmpty)
    }

    private var doneSelectionButton: some View {
        Button {
            exitSelectionMode()
        } label: {
            Label("Done", systemImage: "checkmark")
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
    }

    private var bulkTagPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add tags to \(selectedItems.count) item\(selectedItems.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold))

            TextField("ui, invoice, research", text: $bulkTagDraft)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit(applyBulkTags)

            Text("Comma-separated. Existing tags are kept; duplicates are skipped.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { isBulkTagPopoverPresented = false }
                Button("Add Tags", action: applyBulkTags)
                    .buttonStyle(.borderedProminent)
                    .disabled(bulkTagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
    }

    private func applyBulkTags() {
        let text = bulkTagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appState.addTags(text, to: selectedItems)
        bulkTagDraft = ""
        isBulkTagPopoverPresented = false
    }

    private var topSelectionControls: some View {
        HStack(spacing: 8) {
            if isSelectionMode {
                Text("\(selectedItems.count) selected")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selectedItems.isEmpty ? .secondary : .primary)

                Button {
                    selectVisibleItems()
                } label: {
                    Label(allVisibleItemsSelected ? "Clear" : "Select All", systemImage: allVisibleItemsSelected ? "circle" : "checklist.checked")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(visibleItems.isEmpty)

                Button {
                    boardEditorPayload = BoardEditorPayload(items: Array(selectedScreenshotItems.prefix(12)))
                } label: {
                    Label("Create Board", systemImage: "rectangle.stack.badge.plus")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(selectedScreenshotItems.count < 2)
                .help("Create a moodboard from selected screenshots (needs 2+)")

                Button {
                    exitSelectionMode()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button {
                    isSelectionMode = true
                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(visibleItems.isEmpty)

                Text("\(visibleItems.count) visible")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $sortMode) {
            ForEach(LibrarySortMode.allCases) { mode in
                Text(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 126)
    }

    private var viewModePicker: some View {
        Picker("View", selection: $displayMode) {
            ForEach(LibraryDisplayMode.allCases) { mode in
                Image(systemName: mode.systemImage)
                    .tag(mode)
                    .help(mode.title)
                    .accessibilityLabel(mode.title)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 132)
    }

    private func detailPanel(for item: PocketItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Details")
                        .font(.system(size: 15, weight: .semibold))

                    Text(item.kind.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    metadataDraft.isPinned.toggle()
                    saveDetailDraft(for: item)
                } label: {
                    Image(systemName: metadataDraft.isPinned ? "pin.fill" : "pin")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(metadataDraft.isPinned ? "Unpin" : "Pin")

                Button {
                    selectedDetailItemID = nil
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Close details")
            }

            detailMediaView(for: item)

            detailField("Title", text: $metadataDraft.title, prompt: item.name)
            detailProjectField
            detailField("Category", text: $metadataDraft.category, prompt: "Bug, inspiration, receipt...")
            detailField("Tags", text: $metadataDraft.tags, prompt: "ui, invoice, research")

            VStack(alignment: .leading, spacing: 6) {
                Text("Note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $metadataDraft.note)
                    .font(.system(size: 12))
                    .frame(minHeight: 86)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }
            }

            detectedTextSection(for: item)

            HStack(spacing: 8) {
                Button {
                    saveDetailDraft(for: item)
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    metadataDraft = appState.metadata(for: item)
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.bordered)
                .help("Reset changes")
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                if appState.hasBoardDocument(for: item) {
                    Button {
                        boardEditorPayload = BoardEditorPayload(editURL: item.url)
                    } label: {
                        Label("Edit Board", systemImage: "rectangle.stack.badge.plus")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(maxWidth: .infinity)
                    }
                } else if item.kind == .screenshot {
                    Button {
                        annotationItem = item
                    } label: {
                        Label("Annotate", systemImage: "pencil.and.outline")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(maxWidth: .infinity)
                    }
                }

                Button {
                    appState.openItem(item)
                } label: {
                    Label("Open", systemImage: "arrow.up.right.square")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    appState.revealItem(item)
                } label: {
                    Label("Reveal", systemImage: "finder")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity)
                }

                Button(role: .destructive) {
                    pendingDeletion = item
                    isShowingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)

            Text(item.url.path)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(3)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 328, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func detailMediaView(for item: PocketItem) -> some View {
        if item.kind == .recording {
            RecordingPlayerView(url: item.url)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
        } else if let image = detailImage, image.size.width > 0, image.size.height > 0 {
            let boxes = appState.textBoxes(for: item)
            let query = appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let isSearching = !query.isEmpty
            // While searching, draw only matching boxes (cheap); otherwise all when toggled on.
            let foldedQuery = AppState.searchFold(query)
            let visibleBoxes = isSearching
                ? boxes.filter { AppState.searchFold($0.text).contains(foldedQuery) }
                : (highlightDetectedText ? boxes : [])

            VStack(alignment: .leading, spacing: 6) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 168)
                    // The overlay is sized to the image's fitted frame, so normalized boxes
                    // map straight onto it — no letterboxing math, no greedy GeometryReader.
                    .overlay {
                        GeometryReader { geo in
                            ForEach(Array(visibleBoxes.enumerated()), id: \.offset) { _, box in
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill((isSearching ? Color.orange : Color.yellow).opacity(isSearching ? 0.35 : 0.20))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                                            .stroke(isSearching ? Color.orange : Color.yellow.opacity(0.7), lineWidth: isSearching ? 1.5 : 1)
                                    }
                                    .frame(width: box.width * geo.size.width, height: box.height * geo.size.height)
                                    .position(
                                        x: (box.x + box.width / 2) * geo.size.width,
                                        y: (box.y + box.height / 2) * geo.size.height
                                    )
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                if !boxes.isEmpty {
                    Toggle(isOn: $highlightDetectedText) {
                        Label("Highlight detected text", systemImage: "text.magnifyingglass")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                }
            }
        } else {
            thumbnailView(item, height: 156, showsSelection: false)
        }
    }

    private func detectedTextSection(for item: PocketItem) -> some View {
        let metadata = appState.metadata(for: item)
        let isScanning = appState.isRecognizingText(for: item)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text("Detected Text")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if metadata.hasDetectedText {
                    Button {
                        let text = metadata.detectedText
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Label("Copy Text", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Copy the recognized text to the clipboard")
                }

                Button {
                    appState.rescanText(for: item)
                } label: {
                    Label(isScanning ? "Scanning" : "Re-scan Text", systemImage: "text.viewfinder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(item.kind != .screenshot || isScanning)
            }

            if item.kind != .screenshot {
                Text("Text recognition is available for screenshots.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else if isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Reading text locally on this Mac...")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else if metadata.hasDetectedText {
                ScrollView {
                    Text(metadata.detectedText)
                        .font(.system(size: 11))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 116)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            } else {
                Text("No readable text found yet.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func detailField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
        }
    }

    private var detailProjectField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Project")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                TextField("Client, class, product...", text: $metadataDraft.project)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))

                Menu {
                    Button {
                        metadataDraft.project = ""
                    } label: {
                        Label("No Project", systemImage: "tray")
                    }

                    if !appState.projectNames.isEmpty {
                        Divider()
                    }

                    ForEach(appState.projectNames, id: \.self) { project in
                        Button {
                            metadataDraft.project = project
                        } label: {
                            Label(project, systemImage: "folder")
                        }
                    }
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 18, height: 18)
                }
                .menuStyle(.borderlessButton)
                .help("Assign project")
            }
        }
    }

    private var allVisibleItemsSelected: Bool {
        let visibleIDs = Set(visibleItems.map(\.id))
        return !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedItemIDs)
    }

    private func libraryCard(_ item: PocketItem) -> some View {
        let isSelected = selectedItemIDs.contains(item.id)

        return VStack(alignment: .leading, spacing: 10) {
            thumbnailView(item, height: 132, showsSelection: true)

            metadataBlock(item, titleLineLimit: 2)

            if isSelectionMode {
                selectionButton(item)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(cardStrokeColor(for: item, isSelected: isSelected), lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onDrag {
            dragProvider(for: item)
        } preview: {
            dragPreview(for: item)
        }
        .onTapGesture {
            if isSelectionMode {
                toggleSelection(for: item)
            } else {
                showDetails(for: item)
            }
        }
    }

    private func compactRow(_ item: PocketItem) -> some View {
        let isSelected = selectedItemIDs.contains(item.id)

        return HStack(spacing: 10) {
            selectionMark(for: item)

            compactThumbnail(item)

            VStack(alignment: .leading, spacing: 3) {
                Text(appState.displayName(for: item))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(item.url.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Text(item.subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 170, alignment: .leading)

            Text(item.sizeText)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .frame(width: 72, alignment: .trailing)

            if !isSelectionMode {
                itemActions(item, includesDelete: true)
                    .frame(width: item.kind == .screenshot ? 330 : 235, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(isSelected ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onDrag {
            dragProvider(for: item)
        } preview: {
            dragPreview(for: item)
        }
        .onTapGesture {
            if isSelectionMode {
                toggleSelection(for: item)
            } else {
                showDetails(for: item)
            }
        }
    }

    private func compactThumbnail(_ item: PocketItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: item.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 58, height: 40)
                .clipped()

            Image(systemName: item.kind.systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .padding(4)
                .background(.black.opacity(0.58))
                .clipShape(Circle())
                .padding(3)
        }
        .frame(width: 58, height: 40)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func previewRow(_ item: PocketItem) -> some View {
        let isSelected = selectedItemIDs.contains(item.id)

        return HStack(spacing: 12) {
            thumbnailView(item, height: 92, showsSelection: false)
                .frame(width: 148)

            VStack(alignment: .leading, spacing: 5) {
                metadataBlock(item, titleLineLimit: 1)

                Text(item.url.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            if isSelectionMode {
                selectionButton(item)
                    .frame(width: 112)
            } else {
                itemActions(item, includesDelete: true)
                    .frame(width: item.kind == .screenshot ? 330 : 235, alignment: .trailing)
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.13) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(cardStrokeColor(for: item, isSelected: isSelected), lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onDrag {
            dragProvider(for: item)
        } preview: {
            dragPreview(for: item)
        }
        .onTapGesture {
            if isSelectionMode {
                toggleSelection(for: item)
            } else {
                showDetails(for: item)
            }
        }
    }

    private func thumbnailView(_ item: PocketItem, height: CGFloat, showsSelection: Bool) -> some View {
        let isSelected = selectedItemIDs.contains(item.id)

        return ZStack {
            Color(nsColor: .textBackgroundColor)

            Image(nsImage: item.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(7)

            if isSelectionMode && showsSelection {
                VStack {
                    HStack {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(isSelected ? .blue : .secondary)
                            .padding(8)

                        Spacer()
                    }

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func metadataBlock(_ item: PocketItem, titleLineLimit: Int) -> some View {
        let metadata = appState.metadata(for: item)

        return VStack(alignment: .leading, spacing: 4) {
            Text(appState.displayName(for: item))
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(titleLineLimit)
                .fixedSize(horizontal: false, vertical: true)

            if let reason = appState.searchMatchReason(for: item) {
                Label("Matched \(reason)", systemImage: "scope")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Label(item.kind.displayName, systemImage: item.kind.systemImage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if metadata.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.orange)
                        .help("Pinned")
                }

                if metadata.hasDetectedText {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .help("Text recognized")
                }

                Text(item.sizeText)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private func metadataBadges(_ metadata: PocketItemMetadata) -> some View {
        HStack(spacing: 6) {
            if !metadata.project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                badge(metadata.project, systemImage: "folder")
            }

            if !metadata.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                badge(metadata.category, systemImage: "tag")
            }

            if !metadata.tags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                badge(metadata.tags, systemImage: "number")
            }

            if metadata.hasDetectedText {
                badge("Text", systemImage: "text.viewfinder")
            }
        }
    }

    private func hasMetadataBadges(_ metadata: PocketItemMetadata) -> Bool {
        !metadata.project.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !metadata.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !metadata.tags.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || metadata.hasDetectedText
    }

    private func badge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private func cardStrokeColor(for item: PocketItem, isSelected: Bool) -> Color {
        if isSelected {
            return .accentColor
        }

        if selectedDetailItemID == item.id {
            return Color.accentColor.opacity(0.7)
        }

        return .clear
    }

    private func selectionMark(for item: PocketItem) -> some View {
        let isSelected = selectedItemIDs.contains(item.id)

        return Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isSelectionMode ? (isSelected ? .blue : .secondary) : .clear)
            .frame(width: 22)
    }

    private func selectionButton(_ item: PocketItem) -> some View {
        let isSelected = selectedItemIDs.contains(item.id)

        return Button {
            toggleSelection(for: item)
        } label: {
            Label(isSelected ? "Selected" : "Select", systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func itemActions(_ item: PocketItem, includesDelete: Bool) -> some View {
        HStack(spacing: 8) {
            if appState.hasBoardDocument(for: item) {
                Button {
                    boardEditorPayload = BoardEditorPayload(editURL: item.url)
                } label: {
                    Label("Edit Board", systemImage: "rectangle.stack.badge.plus")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .help("Reopen and rearrange this board")
            } else if item.kind == .screenshot {
                Button {
                    annotationItem = item
                } label: {
                    Label("Annotate", systemImage: "pencil.and.outline")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .help("Annotate screenshot")
            }

            Button {
                appState.openItem(item)
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Button {
                appState.revealItem(item)
            } label: {
                Label("Reveal", systemImage: "finder")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if includesDelete {
                Button(role: .destructive) {
                    pendingDeletion = item
                    isShowingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func toggleSelection(for item: PocketItem) {
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    private func selectVisibleItems() {
        let visibleIDs = Set(visibleItems.map(\.id))

        if visibleIDs.isSubset(of: selectedItemIDs), !visibleIDs.isEmpty {
            selectedItemIDs.subtract(visibleIDs)
        } else {
            selectedItemIDs.formUnion(visibleIDs)
        }
    }

    private func exitSelectionMode() {
        isSelectionMode = false
        selectedItemIDs.removeAll()
    }

    private func showDetails(for item: PocketItem) {
        selectedDetailItemID = item.id
        metadataDraft = appState.metadata(for: item)
    }

    private func loadDetailDraft() {
        guard let selectedDetailItem else {
            metadataDraft = PocketItemMetadata()
            detailImage = nil
            return
        }

        metadataDraft = appState.metadata(for: selectedDetailItem)
        detailImage = (selectedDetailItem.kind == .screenshot || selectedDetailItem.kind == .board)
            ? NSImage(contentsOf: selectedDetailItem.url)
            : nil
        // Ensure older screenshots gain word boxes so the highlight overlay can appear.
        appState.backfillTextBoxesIfNeeded(for: selectedDetailItem)
    }

    private func saveDetailDraft(for item: PocketItem) {
        appState.updateMetadata(metadataDraft, for: item)
    }

    private func openCurrentResult() {
        guard let firstItem = visibleItems.first else {
            return
        }

        if selectedDetailItemID == firstItem.id {
            appState.openItem(firstItem)
        } else {
            showDetails(for: firstItem)
        }
    }

    private func dragProvider(for item: PocketItem) -> NSItemProvider {
        let items = draggedItems(for: item)

        // Register the actual file so dropping into Finder, Slack, Mail, etc. attaches the
        // real image/recording — not just a text path. (SwiftUI's onDrag carries one
        // provider, so multi-select drags out the primary file.)
        let primaryURL = items.first?.url ?? item.url
        let provider = NSItemProvider(contentsOf: primaryURL) ?? NSItemProvider()
        provider.suggestedName = items.count > 1
            ? "\(items.count) Scap files"
            : appState.displayName(for: item)

        return provider
    }

    private func dragPreview(for item: PocketItem) -> some View {
        let items = draggedItems(for: item)

        return HStack(spacing: 10) {
            Image(nsImage: item.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 54, height: 38)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.65), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(items.count == 1 ? appState.displayName(for: item) : "\(items.count) files")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Text(items.count == 1 ? item.kind.displayName : "Move to project")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)
    }

    private func assignDroppedItems(from providers: [NSItemProvider], to projectID: String) -> Bool {
        var acceptedDrop = false
        let targetProject = projectID == unassignedProjectFilter ? nil : projectID
        let group = DispatchGroup()
        let lock = NSLock()
        var droppedPaths = Set<String>()
        var droppedFileURLs = [URL]()

        func registerPath(_ path: String) {
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPath.isEmpty else {
                return
            }

            lock.lock()
            droppedPaths.insert(trimmedPath)
            droppedFileURLs.append(URL(fileURLWithPath: trimmedPath))
            lock.unlock()
        }

        func registerTextPayload(_ payload: String) {
            payload
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .forEach { value in
                    if let url = URL(string: value), url.isFileURL {
                        registerPath(url.path)
                    } else {
                        registerPath(value)
                    }
                }
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                acceptedDrop = true
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let url = fileURL(from: item) {
                        registerPath(url.path)
                    }
                    group.leave()
                }
                continue
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                acceptedDrop = true
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    if let url = fileURL(from: item) {
                        registerPath(url.path)
                    }
                    group.leave()
                }
                continue
            }

            guard provider.canLoadObject(ofClass: NSString.self) else {
                continue
            }

            acceptedDrop = true
            group.enter()
            provider.loadObject(ofClass: NSString.self) { object, _ in
                if let payload = object as? String {
                    registerTextPayload(payload)
                }
                group.leave()
            }
        }

        guard acceptedDrop else {
            return false
        }

        group.notify(queue: .main) {
            let currentItemsByPath = Dictionary(uniqueKeysWithValues: appState.libraryItems.map { ($0.url.path, $0) })
            let existingItems = droppedPaths.compactMap { currentItemsByPath[$0] }
            let existingPaths = Set(existingItems.map(\.url.path))
            let newFileURLs = droppedFileURLs.filter { !existingPaths.contains($0.path) }

            if !existingItems.isEmpty {
                appState.assignItems(existingItems, toProject: targetProject)
            }

            if !newFileURLs.isEmpty {
                appState.importDroppedFiles(newFileURLs, toProject: targetProject)
            }

            if let selectedDetailItem, existingPaths.contains(selectedDetailItem.url.path) {
                metadataDraft = appState.metadata(for: selectedDetailItem)
            }

            dropTargetProjectID = nil
        }

        return true
    }

    private var projectDropTypes: [UTType] {
        [.fileURL, .url, .plainText]
    }

    private func draggedItems(for item: PocketItem) -> [PocketItem] {
        guard selectedItemIDs.contains(item.id) else {
            return [item]
        }

        let selectedVisibleItems = visibleItems.filter { selectedItemIDs.contains($0.id) }
        return selectedVisibleItems.isEmpty ? [item] : selectedVisibleItems
    }

    private func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL, url.isFileURL {
            return url
        }

        if let url = item as? NSURL, url.isFileURL {
            return url as URL
        }

        if let data = item as? Data,
           let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if let url = URL(string: value), url.isFileURL {
                return url
            }

            if value.hasPrefix("/") {
                return URL(fileURLWithPath: value)
            }
        }

        if let value = item as? String {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmedValue), url.isFileURL {
                return url
            }

            if trimmedValue.hasPrefix("/") {
                return URL(fileURLWithPath: trimmedValue)
            }
        }

        return nil
    }

    private func filterItems(_ items: [PocketItem]) -> [PocketItem] {
        switch filterMode {
        case .all:
            return items
        case .screenshots:
            return items.filter { $0.kind == .screenshot }
        case .recordings:
            return items.filter { $0.kind == .recording }
        case .pinned:
            return items.filter { appState.metadata(for: $0).isPinned }
        case .text:
            return items.filter { appState.metadata(for: $0).hasDetectedText }
        }
    }

    private func sortItems(_ items: [PocketItem]) -> [PocketItem] {
        switch sortMode {
        case .relevance:
            return items
        case .newest:
            return items.sorted { $0.modifiedAt > $1.modifiedAt }
        case .oldest:
            return items.sorted { $0.modifiedAt < $1.modifiedAt }
        case .name:
            return items.sorted {
                appState.displayName(for: $0).localizedCaseInsensitiveCompare(appState.displayName(for: $1)) == .orderedAscending
            }
        }
    }
}
