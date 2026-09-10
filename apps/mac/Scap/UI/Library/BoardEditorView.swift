import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum BoardAspect: String, CaseIterable, Identifiable {
    case wide
    case standard
    case square
    case portrait

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wide: "16:9"
        case .standard: "4:3"
        case .square: "1:1"
        case .portrait: "3:4"
        }
    }

    // width / height
    var ratio: CGFloat {
        switch self {
        case .wide: 16.0 / 9.0
        case .standard: 4.0 / 3.0
        case .square: 1
        case .portrait: 3.0 / 4.0
        }
    }
}

private enum BoardBackground: String, CaseIterable, Identifiable {
    case transparent
    case light
    case dark
    case slate
    case sand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transparent: "None"
        case .light: "Light"
        case .dark: "Dark"
        case .slate: "Slate"
        case .sand: "Sand"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .transparent: .clear
        case .light: NSColor(calibratedRed: 0.94, green: 0.95, blue: 0.96, alpha: 1)
        case .dark: NSColor(calibratedRed: 0.10, green: 0.105, blue: 0.115, alpha: 1)
        case .slate: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.27, alpha: 1)
        case .sand: NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.86, alpha: 1)
        }
    }

    var isDark: Bool {
        self == .dark || self == .slate
    }
}

private enum BoardArrangement {
    case grid
    case rows
    case columns
    case scatter
}

// One screenshot placed on the board. Position/size are normalized [0,1] to the board;
// height is derived from the image's aspect so nothing is ever distorted.
private struct BoardPlacement: Identifiable {
    let id = UUID()
    let sourcePath: String
    let displayName: String
    let image: NSImage
    let imageAspect: CGFloat // width / height
    var centerX: CGFloat
    var centerY: CGFloat
    var widthFraction: CGFloat
    var caption: String = ""
}

struct BoardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var placements: [BoardPlacement]
    @State private var title = "Untitled Board"
    @State private var aspect: BoardAspect = .wide
    // Default to a contrasting dark background: most screenshots are near-white, so a light
    // board makes them (and the tile) look empty. On slate, white screenshots clearly pop.
    @State private var background: BoardBackground = .slate
    @State private var hasRoundedCorners = true
    @State private var hasShadow = true
    @State private var showsTitle = false
    @State private var selectedID: UUID?
    @State private var dragBaseline: [BoardPlacement]?
    @State private var statusText = "Drag to arrange. Originals stay untouched."

    private let boardWidthPx: CGFloat = 1600
    private let canvasSpace = "boardCanvas"
    private let editingURL: URL?
    private let sourceItemsForNewBoard: [PocketItem]

    // New board from a library selection.
    init(items: [PocketItem]) {
        editingURL = nil
        sourceItemsForNewBoard = Array(items.prefix(12))
        let loaded: [BoardPlacement] = items.prefix(12).compactMap { item in
            guard let image = NSImage(contentsOf: item.url), image.size.width > 0, image.size.height > 0 else {
                return nil
            }
            return BoardPlacement(
                sourcePath: item.url.path,
                displayName: item.name,
                image: image,
                imageAspect: image.size.width / image.size.height,
                centerX: 0.5,
                centerY: 0.5,
                widthFraction: 0.3
            )
        }
        _placements = State(initialValue: loaded)
    }

    // Reopen a previously saved board to keep editing it.
    init(editingBoardAt url: URL, document: StoredBoardDocument) {
        editingURL = url
        sourceItemsForNewBoard = []
        let loaded: [BoardPlacement] = document.placements.compactMap { placement in
            guard let image = NSImage(contentsOfFile: placement.sourcePath), image.size.width > 0, image.size.height > 0 else {
                return nil
            }
            return BoardPlacement(
                sourcePath: placement.sourcePath,
                displayName: (placement.sourcePath as NSString).lastPathComponent,
                image: image,
                imageAspect: image.size.width / image.size.height,
                centerX: placement.centerX,
                centerY: placement.centerY,
                widthFraction: placement.widthFraction,
                caption: placement.caption
            )
        }
        _placements = State(initialValue: loaded)
        _title = State(initialValue: document.title)
        _aspect = State(initialValue: BoardAspect(rawValue: document.aspect) ?? .wide)
        _background = State(initialValue: BoardBackground(rawValue: document.background) ?? .light)
        _hasRoundedCorners = State(initialValue: document.hasRoundedCorners)
        _hasShadow = State(initialValue: document.hasShadow)
        _showsTitle = State(initialValue: document.showsTitle)
    }

    private var boardAspectRatio: CGFloat { aspect.ratio }

    private var selectedPlacement: BoardPlacement? {
        guard let selectedID else { return nil }
        return placements.first { $0.id == selectedID }
    }

    var body: some View {
        HStack(spacing: 0) {
            controls

            Divider()

            canvas
        }
        .frame(minWidth: 940, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if editingURL == nil, placements.allSatisfy({ $0.centerX == 0.5 && $0.centerY == 0.5 }) {
                arrange(.grid)
            }
        }
        .onExitCommand {
            if selectedID != nil {
                selectedID = nil
            } else {
                dismiss()
            }
        }
        .onDeleteCommand(perform: deleteSelected)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(editingURL == nil ? "Moodboard" : "Edit Board")
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(placements.count) screenshot\(placements.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Board title", text: $title)
                .textFieldStyle(.roundedBorder)

            Toggle("Show title on board", isOn: $showsTitle)
                .toggleStyle(.checkbox)
                .font(.system(size: 12))

            labeledControl("Canvas") {
                Picker("", selection: $aspect) {
                    ForEach(BoardAspect.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            labeledControl("Background") {
                Picker("", selection: $background) {
                    ForEach(BoardBackground.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            labeledControl("Arrange") {
                HStack(spacing: 6) {
                    arrangeButton("Grid", "square.grid.2x2", .grid)
                    arrangeButton("Rows", "rectangle.split.3x1", .rows)
                    arrangeButton("Columns", "rectangle.split.1x2", .columns)
                    arrangeButton("Scatter", "sparkles", .scatter)
                }
            }

            HStack(spacing: 14) {
                Toggle("Rounded", isOn: $hasRoundedCorners)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                Toggle("Shadow", isOn: $hasShadow)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
            }

            Divider()

            selectedInspector

            Spacer(minLength: 8)

            Text(statusText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            actionButtons
        }
        .padding(16)
        .frame(width: 340, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.7))
    }

    @ViewBuilder
    private var selectedInspector: some View {
        if let selected = selectedPlacement {
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected image")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(selected.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                TextField("Caption (optional)", text: captionBinding(for: selected.id))
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 6) {
                    Button {
                        bringToFront(selected.id)
                    } label: {
                        Label("To Front", systemImage: "square.3.layers.3d.top.filled")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button(role: .destructive) {
                        deleteSelected()
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        } else {
            Text("Click an image on the canvas to caption, reorder or resize it.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button("Cancel") { dismiss() }

            Spacer()

            Button {
                copyBoard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(placements.isEmpty)

            Button {
                exportBoard()
            } label: {
                Label("Export", systemImage: "square.and.arrow.down")
            }
            .disabled(placements.isEmpty)

            Button {
                saveBoard()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .disabled(placements.isEmpty)
        }
    }

    private func labeledControl<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func arrangeButton(_ title: String, _ icon: String, _ mode: BoardArrangement) -> some View {
        Button {
            arrange(mode)
        } label: {
            Label(title, systemImage: icon)
                .labelStyle(.iconOnly)
                .frame(width: 22, height: 18)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(title)
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geometry in
            let boardRect = aspectFitRect(
                imageSize: CGSize(width: boardAspectRatio, height: 1),
                in: geometry.size,
                inset: 36
            )

            ZStack {
                Color(nsColor: .underPageBackgroundColor)

                ZStack {
                    // Board surface.
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(boardFillColor)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        }
                        .frame(width: boardRect.width, height: boardRect.height)
                        .position(x: boardRect.midX, y: boardRect.midY)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedID = nil }

                    if showsTitle, !title.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(title)
                            .font(.system(size: max(11, boardRect.width * 0.028), weight: .bold))
                            .foregroundStyle(background.isDark ? .white : .black)
                            .position(
                                x: boardRect.minX + boardRect.width * 0.5,
                                y: boardRect.minY + boardRect.height * 0.06
                            )
                    }

                    ForEach(placements) { placement in
                        placementView(placement, in: boardRect)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .coordinateSpace(name: canvasSpace)
                .clipped()
            }
        }
    }

    private var boardFillColor: Color {
        background == .transparent ? Color(nsColor: .textBackgroundColor).opacity(0.35) : Color(nsColor: background.nsColor)
    }

    private func placementView(_ placement: BoardPlacement, in boardRect: CGRect) -> some View {
        let rect = placementRect(placement, in: boardRect)
        let isSelected = placement.id == selectedID
        let captionHeight: CGFloat = placement.caption.isEmpty ? 0 : max(14, rect.width * 0.06)

        return ZStack(alignment: .top) {
            VStack(spacing: 4) {
                Image(nsImage: placement.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: rect.width, height: rect.height)
                    .clipShape(RoundedRectangle(cornerRadius: hasRoundedCorners ? max(3, rect.width * 0.03) : 0, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: hasRoundedCorners ? max(3, rect.width * 0.03) : 0, style: .continuous)
                            .stroke(.black.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(hasShadow ? 0.28 : 0), radius: hasShadow ? 9 : 0, x: 0, y: hasShadow ? 4 : 0)

                if !placement.caption.isEmpty {
                    Text(placement.caption)
                        .font(.system(size: max(8, rect.width * 0.05), weight: .medium))
                        .foregroundStyle(background.isDark ? .white : .black)
                        .lineLimit(1)
                        .frame(width: rect.width, height: captionHeight)
                }
            }

            if isSelected {
                RoundedRectangle(cornerRadius: hasRoundedCorners ? max(3, rect.width * 0.03) : 2, style: .continuous)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .frame(width: rect.width + 4, height: rect.height + 4)
                    .offset(y: -2)

                resizeHandle(at: CGPoint(x: rect.width + 4, y: rect.height + 4), placement: placement, in: boardRect)
            }
        }
        .frame(width: rect.width, height: rect.height + captionHeight, alignment: .top)
        .position(x: rect.midX, y: rect.midY + captionHeight / 2)
        .onTapGesture { selectedID = placement.id }
        .gesture(moveGesture(for: placement, in: boardRect))
    }

    private func resizeHandle(at point: CGPoint, placement: BoardPlacement, in boardRect: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.accentColor)
            .frame(width: 14, height: 14)
            .overlay { RoundedRectangle(cornerRadius: 3).stroke(.white, lineWidth: 1.5) }
            .position(point)
            .gesture(resizeGesture(for: placement, in: boardRect))
            .help("Drag to resize")
    }

    private func moveGesture(for placement: BoardPlacement, in boardRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(canvasSpace))
            .onChanged { value in
                if dragBaseline == nil {
                    selectedID = placement.id
                    dragBaseline = placements
                }
                guard let index = placements.firstIndex(where: { $0.id == placement.id }),
                      let base = dragBaseline?.first(where: { $0.id == placement.id }) else { return }
                let dx = value.translation.width / max(1, boardRect.width)
                let dy = value.translation.height / max(1, boardRect.height)
                placements[index].centerX = min(1.2, max(-0.2, base.centerX + dx))
                placements[index].centerY = min(1.2, max(-0.2, base.centerY + dy))
            }
            .onEnded { _ in dragBaseline = nil }
    }

    private func resizeGesture(for placement: BoardPlacement, in boardRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(canvasSpace))
            .onChanged { value in
                guard let index = placements.firstIndex(where: { $0.id == placement.id }) else { return }
                selectedID = placement.id
                // New width from pointer position relative to the image's left edge.
                let leftX = boardRect.minX + (placement.centerX * boardRect.width) - (placement.widthFraction * boardRect.width) / 2
                let newWidthPx = value.location.x - leftX
                let newFraction = newWidthPx / max(1, boardRect.width)
                placements[index].widthFraction = min(1.0, max(0.08, newFraction))
            }
    }

    // Board-space rect (in canvas view coordinates) for a placement's IMAGE only.
    private func placementRect(_ placement: BoardPlacement, in boardRect: CGRect) -> CGRect {
        let w = placement.widthFraction * boardRect.width
        let h = w / placement.imageAspect
        let cx = boardRect.minX + placement.centerX * boardRect.width
        let cy = boardRect.minY + placement.centerY * boardRect.height
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    private func captionBinding(for id: UUID) -> Binding<String> {
        Binding {
            placements.first(where: { $0.id == id })?.caption ?? ""
        } set: { newValue in
            guard let index = placements.firstIndex(where: { $0.id == id }) else { return }
            placements[index].caption = newValue
        }
    }

    // MARK: - Actions

    private func deleteSelected() {
        guard let selectedID else { return }
        placements.removeAll { $0.id == selectedID }
        self.selectedID = nil
    }

    private func bringToFront(_ id: UUID) {
        guard let index = placements.firstIndex(where: { $0.id == id }) else { return }
        let moved = placements.remove(at: index)
        placements.append(moved)
    }

    private func arrange(_ mode: BoardArrangement) {
        guard !placements.isEmpty else { return }
        let count = placements.count
        let margin: CGFloat = 0.05
        let gap: CGFloat = 0.03
        let boardAspectRatio = self.boardAspectRatio

        func heightFraction(width: CGFloat, aspect: CGFloat) -> CGFloat {
            width * boardAspectRatio / aspect
        }

        let columns: Int
        switch mode {
        case .rows: columns = count
        case .columns: columns = 1
        case .grid, .scatter: columns = count <= 4 ? 2 : (count <= 9 ? 3 : 4)
        }
        let rows = Int(ceil(Double(count) / Double(columns)))

        let cellW = (1 - 2 * margin - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let cellH = (1 - 2 * margin - CGFloat(rows - 1) * gap) / CGFloat(max(1, rows))

        for i in placements.indices {
            let col = i % columns
            let row = i / columns
            let aspectValue = placements[i].imageAspect

            // Fit the image inside the cell without distortion.
            var width = cellW
            if heightFraction(width: width, aspect: aspectValue) > cellH {
                width = cellH * aspectValue / boardAspectRatio
            }

            var cx = margin + cellW / 2 + CGFloat(col) * (cellW + gap)
            var cy = margin + cellH / 2 + CGFloat(row) * (cellH + gap)

            if mode == .scatter {
                cx += CGFloat.random(in: -gap...gap)
                cy += CGFloat.random(in: -gap...gap)
                width *= CGFloat.random(in: 0.88...1.05)
            }

            placements[i].widthFraction = min(1, max(0.08, width))
            placements[i].centerX = cx
            placements[i].centerY = cy
        }

        selectedID = nil
        statusText = "Arranged \(count) screenshot\(count == 1 ? "" : "s"). Drag any to fine-tune."
    }

    private var renderedBoard: NSImage? {
        BoardRenderer.render(
            placements: placements,
            boardWidth: boardWidthPx,
            aspectRatio: boardAspectRatio,
            background: background,
            hasRoundedCorners: hasRoundedCorners,
            hasShadow: hasShadow,
            title: showsTitle ? title : nil
        )
    }

    private func currentDocument() -> StoredBoardDocument {
        StoredBoardDocument(
            title: title,
            aspect: aspect.rawValue,
            background: background.rawValue,
            hasRoundedCorners: hasRoundedCorners,
            hasShadow: hasShadow,
            showsTitle: showsTitle,
            placements: placements.map {
                StoredBoardPlacement(
                    sourcePath: $0.sourcePath,
                    caption: $0.caption,
                    centerX: $0.centerX,
                    centerY: $0.centerY,
                    widthFraction: $0.widthFraction
                )
            }
        )
    }

    private func saveBoard() {
        guard let renderedBoard else {
            statusText = "Could not render board."
            return
        }

        if let editingURL {
            // Editing an existing board: overwrite it in place and keep the layout editable.
            if appState.updateBoardImage(renderedBoard, at: editingURL) {
                appState.setBoardDocument(currentDocument(), forPath: editingURL.path)
                dismiss()
            } else {
                statusText = "Could not update board."
            }
        } else if let url = appState.saveBoard(renderedBoard, title: title, sourceItems: sourceItemsForNewBoard) {
            appState.setBoardDocument(currentDocument(), forPath: url.path)
            dismiss()
        } else {
            statusText = "Could not save board."
        }
    }

    private func copyBoard() {
        guard let renderedBoard else {
            statusText = "Could not render board."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([renderedBoard])
        statusText = "Board copied."
    }

    private func exportBoard() {
        guard let renderedBoard, let pngData = BoardRenderer.pngData(for: renderedBoard) else {
            statusText = "Could not render board."
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        let safeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        panel.nameFieldStringValue = "\(safeTitle.isEmpty ? "Untitled Board" : safeTitle).png"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try pngData.write(to: url, options: .atomic)
            statusText = "Board exported."
        } catch {
            statusText = error.localizedDescription
        }
    }

    private func aspectFitRect(imageSize: CGSize, in container: CGSize, inset: CGFloat) -> CGRect {
        let available = CGSize(width: max(1, container.width - inset * 2), height: max(1, container.height - inset * 2))
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(available.width / imageSize.width, available.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

private enum BoardRenderer {
    static func render(
        placements: [BoardPlacement],
        boardWidth: CGFloat,
        aspectRatio: CGFloat,
        background: BoardBackground,
        hasRoundedCorners: Bool,
        hasShadow: Bool,
        title: String?
    ) -> NSImage? {
        guard !placements.isEmpty else { return nil }

        let boardHeight = boardWidth / aspectRatio
        let size = CGSize(width: boardWidth, height: boardHeight)

        let output = NSImage(size: size)
        output.lockFocusFlipped(true)

        if background != .transparent {
            background.nsColor.setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        }

        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: boardWidth * 0.028, weight: .bold),
                .foregroundColor: background.isDark ? NSColor.white : NSColor.black
            ]
            let text = title as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (boardWidth - textSize.width) / 2, y: boardHeight * 0.03), withAttributes: attributes)
        }

        for placement in placements {
            let w = placement.widthFraction * boardWidth
            let h = w / placement.imageAspect
            let cx = placement.centerX * boardWidth
            let cy = placement.centerY * boardHeight
            let rect = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
            drawImage(placement.image, in: rect, hasRoundedCorners: hasRoundedCorners, hasShadow: hasShadow, cornerRadius: max(3, w * 0.03))

            if !placement.caption.isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: max(11, w * 0.05), weight: .medium),
                    .foregroundColor: background.isDark ? NSColor.white : NSColor.black
                ]
                let caption = placement.caption as NSString
                let captionSize = caption.size(withAttributes: attributes)
                caption.draw(
                    at: CGPoint(x: rect.midX - captionSize.width / 2, y: rect.maxY + max(4, w * 0.015)),
                    withAttributes: attributes
                )
            }
        }

        output.unlockFocus()
        return output
    }

    static func pngData(for image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func drawImage(_ image: NSImage, in rect: CGRect, hasRoundedCorners: Bool, hasShadow: Bool, cornerRadius: CGFloat) {
        NSGraphicsContext.saveGraphicsState()

        if hasShadow {
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 26
            shadow.shadowOffset = NSSize(width: 0, height: -10)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
            shadow.set()
        }

        if hasRoundedCorners {
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()
        }

        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()

        // Hairline border so light/white screenshots stay visible on a light board.
        let borderPath = hasRoundedCorners
            ? NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            : NSBezierPath(rect: rect)
        NSColor(white: 0, alpha: 0.18).setStroke()
        borderPath.lineWidth = max(1.5, rect.width * 0.004)
        borderPath.stroke()
    }
}
