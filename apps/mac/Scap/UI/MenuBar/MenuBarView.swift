import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settingsStore: SettingsStore
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                searchField
                recentItems
                Divider()
                footer
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .scrollIndicators(.visible)
        .frame(width: 392, alignment: .topLeading)
        .frame(maxHeight: 560, alignment: .topLeading)
        .onAppear {
            isSearchFocused = true

            if appState.watchedFolderURL != nil {
                appState.refreshLibrary()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("ScapLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.appName)
                    .font(.system(size: 17, weight: .semibold))

                Text(appState.statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(appState.recentCaptureCount)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(Capsule())
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search screenshots", text: $appState.searchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSearchFocused ? Color.accentColor.opacity(0.7) : Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                appState.useScapFolderForSystemScreenshots()
            } label: {
                Label("Use for Screenshots", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                Button {
                    appState.chooseWatchedFolder()
                } label: {
                    Label("Folder", systemImage: "folder.badge.gearshape")
                        .frame(maxWidth: .infinity)
                }

                Button {
                    appState.importFiles()
                } label: {
                    Label("Import", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
    }

    private var recentItems: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    if appState.watchedFolderURL != nil {
                        appState.refreshLibrary()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appState.watchedFolderURL == nil)
            }

            VStack(alignment: .leading, spacing: 8) {
                let items = visibleMenuBarItems

                if items.isEmpty {
                    Label("Nothing here yet", systemImage: "tray")
                        .font(.system(size: 14, weight: .semibold))

                    Text("Import files or choose the screenshot folder.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Button {
                        appState.importFiles()
                    } label: {
                        Label("Import", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    ForEach(items) { item in
                        compactItemRow(item)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var recentMenuBarItems: [PocketItem] {
        Array(
            appState.libraryItems
                .sorted { $0.modifiedAt > $1.modifiedAt }
                .prefix(5)
        )
    }

    private var visibleMenuBarItems: [PocketItem] {
        let query = appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            return recentMenuBarItems
        }

        return Array(appState.filteredItems.prefix(5))
    }

    private func compactItemRow(_ item: PocketItem) -> some View {
        let metadata = appState.metadata(for: item)

        return Button {
            appState.openItem(item)
        } label: {
            HStack(spacing: 10) {
                compactThumbnail(item)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(appState.displayName(for: item))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)

                        if metadata.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(compactSubtitle(for: item, metadata: metadata))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func compactThumbnail(_ item: PocketItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: item.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 52, height: 36)
                .clipped()

            Image(systemName: item.kind.systemImage)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(3)
                .background(.black.opacity(0.62))
                .clipShape(Circle())
                .padding(3)
        }
        .frame(width: 52, height: 36)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }

    private func compactSubtitle(for item: PocketItem, metadata: PocketItemMetadata) -> String {
        let project = metadata.project.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = metadata.category.trimmingCharacters(in: .whitespacesAndNewlines)

        if !project.isEmpty, !category.isEmpty {
            return "\(project) - \(category)"
        }

        if !project.isEmpty {
            return project
        }

        if !category.isEmpty {
            return category
        }

        if metadata.hasDetectedText {
            return "Text recognized"
        }

        return item.subtitle
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                WindowRouter.shared.showLibraryWindow()
            } label: {
                Label("Library", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity)
            }

            Button {
                appState.importFiles()
            } label: {
                Image(systemName: "tray.and.arrow.down")
                    .frame(width: 18, height: 18)
            }
            .help("Import")

            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: 18, height: 18)
            }
            .help("Settings")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 18, height: 18)
            }
            .help("Quit")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func openSettings() {
        WindowRouter.shared.showSettingsWindow()
    }
}
