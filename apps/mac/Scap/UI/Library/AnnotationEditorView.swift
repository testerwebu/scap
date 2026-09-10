import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UniformTypeIdentifiers

private enum AnnotationTool: String, CaseIterable, Identifiable, Codable {
    case select
    case arrow
    case line
    case pen
    case rectangle
    case ellipse
    case highlight
    case text
    case number
    case blur
    case pixelate
    case crop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: "Cursor"
        case .arrow: "Arrow"
        case .line: "Line"
        case .pen: "Pen"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .highlight: "Highlight"
        case .text: "Text"
        case .number: "Number"
        case .blur: "Blur"
        case .pixelate: "Pixelate"
        case .crop: "Crop"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .arrow: "arrow.up.right"
        case .line: "line.diagonal"
        case .pen: "scribble"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .highlight: "highlighter"
        case .text: "textformat"
        case .number: "1.circle"
        case .blur: "checkerboard.rectangle"
        case .pixelate: "squareshape.split.3x3"
        case .crop: "crop"
        }
    }

    // Tools that redact a region of the underlying image.
    var isRedaction: Bool {
        self == .blur || self == .pixelate
    }
}

private enum AnnotationColor: String, CaseIterable, Identifiable, Codable {
    // A wider, deliberately distinct palette — one entry per hue, no near-duplicates.
    case red
    case orange
    case yellow
    case green
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray
    case black
    case white

    var id: String { rawValue }

    var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    // Single source of truth: the SwiftUI color is derived from the NSColor so the
    // on-screen swatch, the live preview and the exported pixels can never diverge.
    var nsColor: NSColor {
        switch self {
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .teal: .systemTeal
        case .cyan: .systemCyan
        case .blue: .systemBlue
        case .indigo: .systemIndigo
        case .purple: .systemPurple
        case .pink: .systemPink
        case .brown: .systemBrown
        case .gray: .systemGray
        case .black: .black
        case .white: .white
        }
    }

    var swiftUIColor: Color {
        Color(nsColor: nsColor)
    }
}

private enum AnnotationFontFamily: String, CaseIterable, Identifiable, Codable {
    case system
    case rounded
    case serif
    case mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .rounded: "Rounded"
        case .serif: "Serif"
        case .mono: "Mono"
        }
    }

    var swiftUIDesign: Font.Design {
        switch self {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .mono: .monospaced
        }
    }

    func nsFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        switch self {
        case .mono:
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        case .serif:
            return NSFont(name: "Times New Roman", size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
        case .system, .rounded:
            return NSFont.systemFont(ofSize: size, weight: weight)
        }
    }
}

private struct AnnotationElement: Identifiable, Equatable, Codable {
    let id: UUID
    var tool: AnnotationTool
    var start: CGPoint
    var end: CGPoint
    var text: String
    var number: Int
    var colorName: String
    var fontSizeRatio: CGFloat
    var fontFamilyName: String
    var isTextBorderVisible: Bool
    var borderColorName: String
    var isTextBackgroundVisible: Bool
    var backgroundColorName: String
    var blurStrength: CGFloat
    // Normalized freehand path for the pen tool (empty for every other tool).
    var points: [CGPoint]

    init(
        tool: AnnotationTool,
        start: CGPoint,
        end: CGPoint,
        text: String = "",
        number: Int = 0,
        color: AnnotationColor = .red,
        fontSizeRatio: CGFloat = 0.032,
        fontFamily: AnnotationFontFamily = .system,
        isTextBorderVisible: Bool = false,
        borderColor: AnnotationColor = .red,
        isTextBackgroundVisible: Bool = false,
        backgroundColor: AnnotationColor = .white,
        blurStrength: CGFloat = 0.55,
        points: [CGPoint] = []
    ) {
        self.id = UUID()
        self.tool = tool
        self.start = start
        self.end = end
        self.text = text
        self.number = number
        self.colorName = color.rawValue
        self.fontSizeRatio = fontSizeRatio
        self.fontFamilyName = fontFamily.rawValue
        self.isTextBorderVisible = isTextBorderVisible
        self.borderColorName = borderColor.rawValue
        self.isTextBackgroundVisible = isTextBackgroundVisible
        self.backgroundColorName = backgroundColor.rawValue
        self.blurStrength = blurStrength
        self.points = points
    }
}

struct AnnotationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let item: PocketItem

    @State private var selectedTool: AnnotationTool = .arrow
    @State private var elements: [AnnotationElement] = []
    @State private var undoStack: [[AnnotationElement]] = []
    @State private var redoStack: [[AnnotationElement]] = []
    @State private var selectedElementID: UUID?
    @State private var hoveredElementID: UUID?
    @State private var selectedColor: AnnotationColor = .red
    @State private var selectedBlurStrength: CGFloat = 0.55
    @State private var draftElement: AnnotationElement?
    @State private var dragBaseline: [AnnotationElement]?
    @State private var statusText = "Annotating a copy. Original stays unchanged."
    @State private var isColorPopoverPresented = false
    @State private var isBorderColorPopoverPresented = false
    @State private var isBackgroundColorPopoverPresented = false
    @FocusState private var isTextEditorFocused: Bool

    private let canvasCoordinateSpace = "annotationCanvas"

    private var sourceImage: NSImage? {
        NSImage(contentsOf: item.url)
    }

    private var selectedElement: AnnotationElement? {
        guard let selectedElementID else {
            return nil
        }

        return elements.first { $0.id == selectedElementID }
    }

    private var activeColor: AnnotationColor {
        if let selectedElement {
            return annotationColor(for: selectedElement)
        }

        return selectedColor
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            if let sourceImage {
                editorCanvas(sourceImage)
            } else {
                unavailableState
            }

            Divider()

            footer
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onExitCommand {
            // Esc first finishes the current annotation, only then closes the editor.
            if selectedElementID != nil {
                commitSelectedAnnotation()
            } else {
                dismiss()
            }
        }
        .onDeleteCommand {
            // Never eat Backspace/Delete while a text box is selected — the text view
            // owns the key so typing/erasing works. Use the Delete button to remove it.
            guard selectedElement?.tool != .text else {
                return
            }
            deleteSelected()
        }
        .onAppear(perform: loadStoredAnnotations)
        .onDisappear(perform: persistAnnotationLayer)
        .background {
            // A selected shape/redaction can be removed with Backspace and confirmed with
            // Return. These are gated off text elements so typing into a text box still
            // erases characters and inserts newlines normally.
            if selectedElementID != nil, selectedElement?.tool != .text {
                Group {
                    Button("", action: deleteSelected)
                        .keyboardShortcut(.delete, modifiers: [])
                    Button("", action: commitSelectedAnnotation)
                        .keyboardShortcut(.return, modifiers: [])
                }
                .hidden()
            }
        }
    }

    // Restore a previously saved, editable annotation layer for this item.
    private func loadStoredAnnotations() {
        guard elements.isEmpty,
              let data = appState.annotationLayerData(for: item),
              let stored = try? JSONDecoder().decode([AnnotationElement].self, from: data) else {
            return
        }
        elements = stored
        // Start in Cursor mode so the loaded annotations can be clicked and edited right
        // away — otherwise a drawing tool would create a new shape instead of selecting.
        selectedTool = .select
        statusText = "Loaded your saved annotations — click any one to edit it."
    }

    // Persist the editable layer on the source item so it can be reopened and changed.
    private func persistAnnotationLayer() {
        if elements.isEmpty {
            appState.setAnnotationLayerData(nil, for: item)
        } else if let data = try? JSONEncoder().encode(elements) {
            appState.setAnnotationLayerData(data, for: item)
        }
    }

    private var toolbar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                toolPicker

                colorControl

                Spacer(minLength: 8)

                if selectedElementID != nil {
                    Button {
                        commitSelectedAnnotation()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("Confirm annotation (⌘↩)")
                }
            }

            HStack(spacing: 16) {
                editActionButtons
                Spacer(minLength: 16)
                outputActionButtons
            }

            contextualControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var toolPicker: some View {
        HStack(spacing: 2) {
            ForEach(AnnotationTool.allCases) { tool in
                toolButton(tool)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func toolButton(_ tool: AnnotationTool) -> some View {
        let isActive = selectedTool == tool
        return Button {
            selectTool(tool)
        } label: {
            Image(systemName: tool.systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .frame(width: 32, height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? Color.accentColor : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tool.title)
    }

    @ViewBuilder
    private var colorControl: some View {
        // Redaction tools have no color, so the palette simply steps aside.
        if !isRedactionContext {
            colorPalette
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    // True when the active tool or the selected element redacts (blur/pixelate).
    private var isRedactionContext: Bool {
        selectedTool.isRedaction || (selectedElement?.tool.isRedaction ?? false)
    }

    private func selectTool(_ tool: AnnotationTool) {
        selectedTool = tool
        selectedElementID = nil
        isTextEditorFocused = false
        switch tool {
        case .blur:
            statusText = "Drag over an area to blur it. Higher strength blurs more — it never darkens."
        case .pixelate:
            statusText = "Drag over an area to pixelate it. Higher strength uses bigger blocks."
        case .text:
            statusText = "Click where you want text, then just start typing."
        case .number:
            statusText = "Click to drop a numbered step. It auto-increments."
        case .pen:
            statusText = "Drag to draw freehand."
        case .crop:
            statusText = "Drag the area to keep. Only that region is exported."
        case .select:
            statusText = "Click an annotation to move, resize or restyle it."
        case .arrow, .line, .rectangle, .ellipse, .highlight:
            statusText = "Drag on the image to draw."
        }
    }

    // A single, constant-height slot for the context-sensitive controls. Keeping its
    // height fixed means selecting/placing text never grows the toolbar — which is what
    // used to shrink the canvas and make a freshly placed text box appear to jump.
    private var contextualControls: some View {
        ZStack(alignment: .topLeading) {
            // Invisible sizer: reserves the height of the tallest control set.
            ZStack(alignment: .topLeading) {
                textControls
                blurControls
            }
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            if selectedElement?.tool == .text {
                textControls
            } else if isRedactionContext {
                blurControls
            } else {
                contextualHint
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var contextualHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "cursorarrow.rays")
            Text("Draw with a tool, or click an annotation to change its color and style.")
            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .padding(.vertical, 6)
    }

    private var editActionButtons: some View {
        HStack(spacing: 6) {
            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(undoStack.isEmpty)
            .keyboardShortcut("z", modifiers: .command)
            .help("Undo (⌘Z)")

            Button {
                redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(redoStack.isEmpty)
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .help("Redo (⇧⌘Z)")

            Button(role: .destructive) {
                deleteSelected()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(selectedElementID == nil)
            .help("Delete selected annotation")
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var outputActionButtons: some View {
        HStack(spacing: 8) {
            Button("Cancel") {
                dismiss()
            }
            .fixedSize(horizontal: true, vertical: false)

            Button {
                copyAnnotatedImage()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .disabled(sourceImage == nil)

            Button {
                exportAnnotatedImage()
            } label: {
                Label("Export", systemImage: "square.and.arrow.down")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .disabled(sourceImage == nil)

            Button {
                saveAnnotatedCopy()
            } label: {
                Label(elements.isEmpty ? "Save Clean Copy" : "Save Copy", systemImage: "checkmark")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .buttonStyle(.borderedProminent)
            .disabled(sourceImage == nil)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var textControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                textTypographyControls
                Divider().frame(height: 22)
                textStyleControls
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 10) {
                textTypographyControls
                textStyleControls
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var textTypographyControls: some View {
        HStack(spacing: 10) {
            Label("Type", systemImage: "textformat")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)

            Picker("Font", selection: textFontFamilyBinding) {
                ForEach(AnnotationFontFamily.allCases) { family in
                    Text(family.title)
                        .tag(family.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 236)

            HStack(spacing: 6) {
                Text("Size")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)

                Button {
                    adjustTextSize(by: -0.004)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Slider(value: textFontSizeBinding, in: 0.018...0.075, step: 0.002)
                    .frame(width: 130)

                Button {
                    adjustTextSize(by: 0.004)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Text("\(Int(textFontSizeBinding.wrappedValue * 1000)) pt")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }

        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var borderColor: AnnotationColor {
        AnnotationColor(rawValue: textBorderColorBinding.wrappedValue) ?? .red
    }

    private var textStyleControls: some View {
        HStack(spacing: 14) {
            styleColorControl(
                name: "Border",
                isOn: textBorderVisibleBinding,
                current: borderColor,
                isPresented: $isBorderColorPopoverPresented
            ) { color in
                textBorderColorBinding.wrappedValue = color.rawValue
            }

            styleColorControl(
                name: "Fill",
                isOn: textBackgroundVisibleBinding,
                current: backgroundColor,
                isPresented: $isBackgroundColorPopoverPresented
            ) { color in
                textBackgroundColorBinding.wrappedValue = color.rawValue
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // Compact "checkbox + color swatch" control reused for Border and Fill.
    private func styleColorControl(
        name: String,
        isOn: Binding<Bool>,
        current: AnnotationColor,
        isPresented: Binding<Bool>,
        apply: @escaping (AnnotationColor) -> Void
    ) -> some View {
        HStack(spacing: 7) {
            Toggle(name, isOn: isOn)
                .toggleStyle(.checkbox)
                .font(.system(size: 12, weight: .semibold))
                .fixedSize(horizontal: true, vertical: false)

            Button {
                isPresented.wrappedValue.toggle()
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(current.swiftUIColor)
                        .frame(width: 13, height: 13)
                        .overlay { Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 1) }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!isOn.wrappedValue)
            .help("\(name) color")
            .popover(isPresented: isPresented, arrowEdge: .bottom) {
                colorSwatchGrid(title: "\(name) color", current: current) { color in
                    apply(color)
                    isPresented.wrappedValue = false
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var redactionLabel: String {
        let isPixelate = selectedElement?.tool == .pixelate || (selectedElement == nil && selectedTool == .pixelate)
        return isPixelate ? "Pixelate" : "Blur"
    }

    private var blurControls: some View {
        HStack(spacing: 10) {
            Label(redactionLabel, systemImage: "circle.lefthalf.filled")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: 6) {
                Text("Strength")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)

                Image(systemName: "drop")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                Slider(value: blurStrengthBinding, in: 0.15...1.0, step: 0.05)
                    .frame(width: 200)

                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                Text("\(Int(blurStrengthBinding.wrappedValue * 100))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var textFontSizeBinding: Binding<CGFloat> {
        Binding {
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return 0.032
            }

            return elements[index].fontSizeRatio
        } set: { newValue in
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return
            }

            elements[index].fontSizeRatio = min(0.075, max(0.018, newValue))
        }
    }

    private var textFontFamilyBinding: Binding<String> {
        Binding {
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return AnnotationFontFamily.system.rawValue
            }

            return elements[index].fontFamilyName
        } set: { newValue in
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return
            }

            elements[index].fontFamilyName = newValue
        }
    }

    private var textBorderVisibleBinding: Binding<Bool> {
        Binding {
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return true
            }

            return elements[index].isTextBorderVisible
        } set: { newValue in
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return
            }

            elements[index].isTextBorderVisible = newValue
        }
    }

    private var textBorderColorBinding: Binding<String> {
        Binding {
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return selectedColor.rawValue
            }

            return elements[index].borderColorName
        } set: { newValue in
            guard let color = AnnotationColor(rawValue: newValue) else {
                return
            }

            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                selectedColor = color
                return
            }

            elements[index].borderColorName = color.rawValue
        }
    }

    private var textBackgroundVisibleBinding: Binding<Bool> {
        Binding {
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return false
            }

            return elements[index].isTextBackgroundVisible
        } set: { newValue in
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return
            }

            elements[index].isTextBackgroundVisible = newValue
        }
    }

    private var textBackgroundColorBinding: Binding<String> {
        Binding {
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return AnnotationColor.white.rawValue
            }

            return elements[index].backgroundColorName
        } set: { newValue in
            guard AnnotationColor(rawValue: newValue) != nil,
                  let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool == .text else {
                return
            }

            elements[index].backgroundColorName = newValue
        }
    }

    private var backgroundColor: AnnotationColor {
        AnnotationColor(rawValue: textBackgroundColorBinding.wrappedValue) ?? .white
    }

    private var blurStrengthBinding: Binding<CGFloat> {
        Binding {
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool.isRedaction else {
                return selectedBlurStrength
            }

            return elements[index].blurStrength
        } set: { newValue in
            let clamped = min(1.0, max(0.15, newValue))
            guard let selectedElementID,
                  let index = elements.firstIndex(where: { $0.id == selectedElementID }),
                  elements[index].tool.isRedaction else {
                selectedBlurStrength = clamped
                return
            }

            elements[index].blurStrength = clamped
        }
    }

    private func adjustTextSize(by delta: CGFloat) {
        textFontSizeBinding.wrappedValue = min(0.075, max(0.018, textFontSizeBinding.wrappedValue + delta))
    }

    private var colorPaletteTitle: String {
        selectedElement?.tool == .text ? "Text color" : "Color"
    }

    private var colorPalette: some View {
        Button {
            isColorPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Circle()
                    .fill(activeColor.swiftUIColor)
                    .frame(width: 14, height: 14)
                    .overlay { Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 1) }
                Text(colorPaletteTitle)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("Choose \(colorPaletteTitle.lowercased())")
        .popover(isPresented: $isColorPopoverPresented, arrowEdge: .bottom) {
            colorSwatchGrid(title: colorPaletteTitle, current: activeColor) { color in
                applyColor(color)
                isColorPopoverPresented = false
            }
        }
    }

    private func colorSwatchGrid(
        title: String,
        current: AnnotationColor,
        apply: @escaping (AnnotationColor) -> Void
    ) -> some View {
        let columns = Array(repeating: GridItem(.fixed(24), spacing: 10), count: 5)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AnnotationColor.allCases) { color in
                    Button {
                        apply(color)
                    } label: {
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 22, height: 22)
                            .overlay {
                                Circle()
                                    .stroke(color == current ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: color == current ? 3 : 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .help(color.title)
                }
            }
        }
        .padding(12)
        .frame(width: 202)
    }

    private func editorCanvas(_ sourceImage: NSImage) -> some View {
        GeometryReader { geometry in
            let imageRect = aspectFitRect(imageSize: sourceImage.size, in: geometry.size)

            ZStack {
                Color(nsColor: .underPageBackgroundColor)

                ZStack {
                    Image(nsImage: sourceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageRect.width, height: imageRect.height)
                        .position(x: imageRect.midX, y: imageRect.midY)

                    drawingSurface(in: imageRect, canvasSize: geometry.size)

                    ForEach(elements) { element in
                        annotationView(element, in: imageRect, sourceImage: sourceImage)
                    }

                    if let draftElement {
                        annotationView(draftElement, in: imageRect, sourceImage: sourceImage)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .coordinateSpace(name: canvasCoordinateSpace)
            }
        }
    }

    private func drawingSurface(in imageRect: CGRect, canvasSize: CGSize) -> some View {
        Rectangle()
            .fill(.clear)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .position(x: canvasSize.width / 2, y: canvasSize.height / 2)
            .contentShape(Rectangle())
            // A single click: place a text box or a number instantly, or clear the
            // selection when the Cursor tool is active. No dragging required.
            .gesture(
                SpatialTapGesture(coordinateSpace: .named(canvasCoordinateSpace))
                    .onEnded { value in
                        switch selectedTool {
                        case .select:
                            selectedElementID = nil
                            isTextEditorFocused = false
                        case .text, .number:
                            guard imageRect.contains(value.location) else {
                                return
                            }
                            let point = normalizedPoint(value.location, in: imageRect)
                            updateDraftElement(from: point, to: point)
                            finishDraftElement()
                        case .arrow, .line, .pen, .rectangle, .ellipse, .highlight, .blur, .pixelate, .crop:
                            break
                        }
                    }
            )
            // A drag draws the size-based tools (arrow, rectangle, highlight, blur).
            // minimumDistance keeps a plain click from spawning an accidental shape.
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named(canvasCoordinateSpace))
                    .onChanged { value in
                        guard selectedTool != .select else {
                            return
                        }

                        guard imageRect.contains(value.startLocation) else {
                            draftElement = nil
                            return
                        }

                        updateDraftElement(
                            from: normalizedPoint(value.startLocation, in: imageRect),
                            to: normalizedPoint(value.location, in: imageRect)
                        )
                    }
                    .onEnded { _ in
                        if selectedTool != .select {
                            finishDraftElement()
                        }
                    }
            )
    }

    private func annotationView(_ element: AnnotationElement, in imageRect: CGRect, sourceImage: NSImage) -> some View {
        let isSelected = element.id == selectedElementID
        let isHovered = element.id == hoveredElementID
        let color = annotationColor(for: element)
        let rect = elementRect(element, in: imageRect)
        let hitRect = annotationHitRect(for: element, visibleRect: rect, in: imageRect)
        let localRect = rect.offsetBy(dx: -hitRect.minX, dy: -hitRect.minY)
        let localStart = point(element.start, in: imageRect).offsetBy(dx: -hitRect.minX, dy: -hitRect.minY)
        let localEnd = point(element.end, in: imageRect).offsetBy(dx: -hitRect.minX, dy: -hitRect.minY)

        return ZStack {
            switch element.tool {
            case .select:
                EmptyView()
            case .arrow:
                ArrowShape(start: localStart, end: localEnd)
                    .stroke(color.swiftUIColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .frame(width: hitRect.width, height: hitRect.height)

                if isSelected {
                    endpointHandle(at: localStart)
                        .gesture(reshapeArrowGesture(for: element, endpoint: .start, in: imageRect))
                    endpointHandle(at: localEnd)
                        .gesture(reshapeArrowGesture(for: element, endpoint: .end, in: imageRect))
                }
            case .line:
                LineShape(start: localStart, end: localEnd)
                    .stroke(color.swiftUIColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: hitRect.width, height: hitRect.height)

                if isSelected {
                    endpointHandle(at: localStart)
                        .gesture(reshapeArrowGesture(for: element, endpoint: .start, in: imageRect))
                    endpointHandle(at: localEnd)
                        .gesture(reshapeArrowGesture(for: element, endpoint: .end, in: imageRect))
                }
            case .pen:
                PenShape(points: element.points.map { point($0, in: imageRect).offsetBy(dx: -hitRect.minX, dy: -hitRect.minY) })
                    .stroke(color.swiftUIColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .frame(width: hitRect.width, height: hitRect.height)
            case .rectangle:
                Rectangle()
                    .stroke(color.swiftUIColor, lineWidth: 3)
                    .frame(width: localRect.width, height: localRect.height)
                    .position(x: localRect.midX, y: localRect.midY)
            case .ellipse:
                Ellipse()
                    .stroke(color.swiftUIColor, lineWidth: 3)
                    .frame(width: localRect.width, height: localRect.height)
                    .position(x: localRect.midX, y: localRect.midY)
            case .highlight:
                Rectangle()
                    .fill(color.swiftUIColor.opacity(color == .black ? 0.18 : 0.32))
                    .frame(width: localRect.width, height: localRect.height)
                    .position(x: localRect.midX, y: localRect.midY)
            case .text:
                let fontSize = textDisplayFontSize(for: element, in: imageRect)
                let fontFamily = annotationFontFamily(for: element)
                let borderColor = annotationBorderColor(for: element)
                let backgroundColor = annotationBackgroundColor(for: element)
                let boxWidth = max(96, localRect.width)
                let boxHeight = max(44, localRect.height)
                // Same NSTextView for display and editing, so clicking never nudges the text.
                EditableAnnotationText(
                    text: textBinding(for: element.id) ?? .constant(element.text),
                    font: fontFamily.nsFont(size: fontSize, weight: .semibold),
                    textColor: color.nsColor,
                    isEditing: isSelected,
                    onCommit: commitSelectedAnnotation
                )
                .frame(width: boxWidth, height: boxHeight, alignment: .topLeading)
                .background {
                    if element.isTextBackgroundVisible {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(backgroundColor.swiftUIColor)
                    }
                }
                .overlay {
                    // The only rectangle around text is the one the user opts into.
                    if element.isTextBorderVisible {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(borderColor.swiftUIColor.opacity(0.86), lineWidth: 1.5)
                    }
                }
                .position(x: localRect.midX, y: localRect.midY)
            case .number:
                Text("\(max(1, element.number))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(color.swiftUIColor)
                    .clipShape(Circle())
                    .position(x: localRect.midX, y: localRect.midY)
            case .blur:
                // A real Gaussian blur of the underlying pixels: draw a full-size copy of
                // the image, blur it on the GPU, align it exactly over the real image, then
                // mask it to this region. This matches the exported result — no color tint.
                let imageOriginX = imageRect.minX - hitRect.minX
                let imageOriginY = imageRect.minY - hitRect.minY
                Image(nsImage: sourceImage)
                    .resizable()
                    .interpolation(.low)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .blur(radius: max(2, element.blurStrength * 30), opaque: true)
                    .position(
                        x: imageOriginX + imageRect.width / 2,
                        y: imageOriginY + imageRect.height / 2
                    )
                    .mask(
                        Rectangle()
                            .frame(width: localRect.width, height: localRect.height)
                            .position(x: localRect.midX, y: localRect.midY)
                    )
            case .pixelate:
                // Real pixelation of the underlying pixels, aligned over the image and masked
                // to this region — a cached Core Image render so dragging stays responsive.
                let imageOriginX = imageRect.minX - hitRect.minX
                let imageOriginY = imageRect.minY - hitRect.minY
                Image(nsImage: PixelatePreviewCache.image(for: sourceImage, strength: element.blurStrength))
                    .resizable()
                    .interpolation(.none)
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(
                        x: imageOriginX + imageRect.width / 2,
                        y: imageOriginY + imageRect.height / 2
                    )
                    .mask(
                        Rectangle()
                            .frame(width: localRect.width, height: localRect.height)
                            .position(x: localRect.midX, y: localRect.midY)
                    )
            case .crop:
                // The crop frame: a bright dashed border marking the region to keep.
                Rectangle()
                    .stroke(.white, style: StrokeStyle(lineWidth: 2, dash: [7, 4]))
                    .frame(width: localRect.width, height: localRect.height)
                    .position(x: localRect.midX, y: localRect.midY)
                Rectangle()
                    .stroke(.black.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [7, 4], dashPhase: 7))
                    .frame(width: localRect.width, height: localRect.height)
                    .position(x: localRect.midX, y: localRect.midY)
                Label("Crop", systemImage: "crop")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.black.opacity(0.55)))
                    .position(x: localRect.minX + 26, y: localRect.minY + 12)
            }

            let isLineLike = hasEndpoints(element.tool) || element.tool == .pen

            if isSelected {
                // Text shows its selection through the move grip + resize handle only,
                // so nothing looks like a border the user didn't ask for.
                if !isLineLike, element.tool != .text {
                    Rectangle()
                        .stroke(.blue, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        .frame(width: localRect.width + 8, height: localRect.height + 8)
                        .position(x: localRect.midX, y: localRect.midY)
                }

                // Text keeps its interior free for typing, so it moves via a dedicated grip.
                if element.tool == .text {
                    moveGrip(at: CGPoint(x: localRect.minX - 8, y: localRect.minY - 8), element: element, in: imageRect)
                }

                if isResizable(element.tool) {
                    resizeHandle(at: CGPoint(x: localRect.maxX + 7, y: localRect.maxY + 7))
                        .gesture(resizeGesture(for: element, in: imageRect))
                }
            } else if isHovered, !isLineLike, element.tool != .text {
                Rectangle()
                    .stroke(.blue.opacity(0.32), lineWidth: 2)
                    .frame(width: localRect.width + 8, height: localRect.height + 8)
                    .position(x: localRect.midX, y: localRect.midY)
            }
        }
        .frame(width: hitRect.width, height: hitRect.height)
        .position(x: hitRect.midX, y: hitRect.midY)
        // While a drawing tool is active the canvas owns every drag, so existing
        // elements stay out of the way. Editing/selecting only happens with the Cursor tool.
        .allowsHitTesting(selectedTool == .select)
        .onHover { isHovering in
            guard selectedTool == .select else {
                return
            }
            hoveredElementID = isHovering ? element.id : (hoveredElementID == element.id ? nil : hoveredElementID)
        }
        // The whole body selects/moves the element EXCEPT when a text box is selected —
        // there the interior belongs to the TextEditor so the cursor and text selection work.
        .applyIf(selectedTool == .select && !(isSelected && element.tool == .text)) { view in
            view
                .contentShape(Rectangle())
                .onTapGesture {
                    selectElement(element)
                }
                .gesture(moveGesture(for: element, in: imageRect))
        }
    }

    private func selectElement(_ element: AnnotationElement) {
        selectedElementID = element.id
        if element.tool.isRedaction {
            selectedBlurStrength = element.blurStrength
        } else {
            selectedColor = annotationColor(for: element)
        }
        isTextEditorFocused = element.tool == .text
    }

    private func moveGesture(for element: AnnotationElement, in imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(canvasCoordinateSpace))
            .onChanged { value in
                if dragBaseline == nil {
                    selectElement(element)
                    isTextEditorFocused = false
                    dragBaseline = elements
                }
                moveElement(element.id, by: value.translation, in: imageRect)
            }
            .onEnded { _ in
                commitBaselineUndo()
            }
    }

    private func resizeGesture(for element: AnnotationElement, in imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(canvasCoordinateSpace))
            .onChanged { value in
                if dragBaseline == nil {
                    selectedElementID = element.id
                    isTextEditorFocused = false
                    dragBaseline = elements
                }
                resizeElement(element.id, to: normalizedPoint(value.location, in: imageRect))
            }
            .onEnded { _ in
                commitBaselineUndo()
            }
    }

    private func reshapeArrowGesture(for element: AnnotationElement, endpoint: ArrowEndpoint, in imageRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(canvasCoordinateSpace))
            .onChanged { value in
                if dragBaseline == nil {
                    selectedElementID = element.id
                    dragBaseline = elements
                }
                guard let index = elements.firstIndex(where: { $0.id == element.id }) else {
                    return
                }
                let handlePoint = normalizedPoint(value.location, in: imageRect)
                switch endpoint {
                case .start:
                    elements[index].start = handlePoint
                case .end:
                    elements[index].end = handlePoint
                }
            }
            .onEnded { _ in
                commitBaselineUndo()
            }
    }

    private func commitBaselineUndo() {
        if let dragBaseline {
            undoStack.append(dragBaseline)
            redoStack.removeAll()
        }
        dragBaseline = nil
    }

    private func isResizable(_ tool: AnnotationTool) -> Bool {
        switch tool {
        case .rectangle, .ellipse, .highlight, .blur, .pixelate, .text, .crop:
            true
        case .select, .arrow, .line, .pen, .number:
            false
        }
    }

    // Two-point tools whose endpoints can be dragged individually.
    private func hasEndpoints(_ tool: AnnotationTool) -> Bool {
        tool == .arrow || tool == .line
    }

    private func moveGrip(at point: CGPoint, element: AnnotationElement, in imageRect: CGRect) -> some View {
        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 17, height: 17)
            .background(Circle().fill(.blue))
            .overlay {
                Circle().stroke(.white, lineWidth: 1)
            }
            .position(point)
            .gesture(moveGesture(for: element, in: imageRect))
            .help("Drag to move the text box")
    }

    private var selectedTextBinding: Binding<String>? {
        guard let selectedElementID,
              let binding = textBinding(for: selectedElementID) else {
            return nil
        }

        return binding
    }

    private func textBinding(for id: UUID) -> Binding<String>? {
        guard let index = elements.firstIndex(where: { $0.id == id }),
              elements[index].tool == .text else {
            return nil
        }

        return Binding {
            elements[index].text
        } set: { newValue in
            elements[index].text = newValue
        }
    }

    private func annotationFontFamily(for element: AnnotationElement) -> AnnotationFontFamily {
        AnnotationFontFamily(rawValue: element.fontFamilyName) ?? .system
    }

    private func annotationBorderColor(for element: AnnotationElement) -> AnnotationColor {
        AnnotationColor(rawValue: element.borderColorName) ?? annotationColor(for: element)
    }

    private func annotationBackgroundColor(for element: AnnotationElement) -> AnnotationColor {
        AnnotationColor(rawValue: element.backgroundColorName) ?? .white
    }

    private func textDisplayFontSize(for element: AnnotationElement, in imageRect: CGRect) -> CGFloat {
        max(12, min(72, element.fontSizeRatio * imageRect.height))
    }

    private func applyColor(_ color: AnnotationColor) {
        selectedColor = color

        guard let selectedElementID,
              let index = elements.firstIndex(where: { $0.id == selectedElementID }) else {
            return
        }

        registerUndo()
        if !elements[index].tool.isRedaction {
            elements[index].colorName = color.rawValue
        }
        redoStack.removeAll()
        statusText = "\(elements[index].tool.title) color changed to \(color.title.lowercased())."
    }

    private func updateDraftElement(from start: CGPoint, to end: CGPoint) {
        guard selectedTool != .select else {
            return
        }

        if draftElement == nil {
            let number = nextNumber()
            let initialEnd = start == end && usesImmediateDefaultSize(selectedTool)
                ? defaultEndPoint(from: start, for: selectedTool)
                : end
            draftElement = AnnotationElement(
                tool: selectedTool,
                start: start,
                end: initialEnd,
                number: selectedTool == .number ? number : 0,
                color: selectedTool.isRedaction ? .orange : activeColor,
                borderColor: activeColor,
                blurStrength: selectedBlurStrength,
                points: selectedTool == .pen ? [start] : []
            )
            selectedElementID = nil
            isTextEditorFocused = false
        } else {
            draftElement?.end = end
            if selectedTool == .pen {
                draftElement?.points.append(end)
            }
        }
    }

    private func finishDraftElement() {
        guard var draftElement else {
            return
        }

        draftElement = normalizedDraft(draftElement)
        registerUndo()
        // Only one crop region at a time — a new one replaces the old.
        if draftElement.tool == .crop {
            elements.removeAll { $0.tool == .crop }
        }
        elements.append(draftElement)

        if draftElement.tool == .text {
            selectedElementID = draftElement.id
            selectedColor = annotationColor(for: draftElement)
            selectedTool = .select
            DispatchQueue.main.async {
                isTextEditorFocused = true
            }
        } else if draftElement.tool.isRedaction {
            // Select the redaction and drop into Cursor mode so the strength slider and the
            // resize handle act on THIS region right away — draw once, then fine-tune it.
            selectedElementID = draftElement.id
            selectedBlurStrength = draftElement.blurStrength
            selectedTool = .select
            isTextEditorFocused = false
        } else if draftElement.tool == .crop {
            // Select the crop and switch to Cursor so its edges can be adjusted immediately.
            selectedElementID = draftElement.id
            selectedTool = .select
            isTextEditorFocused = false
        } else {
            selectedElementID = nil
            isTextEditorFocused = false
        }

        self.draftElement = nil
        statusText = draftElement.tool.isRedaction
            ? "\(draftElement.tool.title) added. Drag the slider to change how strong it is."
            : "\(draftElement.tool.title) added."
        redoStack.removeAll()
    }

    private func usesImmediateDefaultSize(_ tool: AnnotationTool) -> Bool {
        switch tool {
        case .select, .arrow, .line, .pen, .rectangle, .ellipse, .highlight, .blur, .pixelate, .crop:
            false
        case .text, .number:
            true
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Label(statusText, systemImage: "lock")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(elements.count) annotation\(elements.count == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var unavailableState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("This screenshot could not be opened.")
                .font(.system(size: 15, weight: .semibold))

            Text("Try revealing the file in Finder and opening it from there.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func saveAnnotatedCopy() {
        guard let renderedImage else {
            statusText = "Could not render annotated image."
            return
        }

        if appState.saveAnnotatedCopy(renderedImage, basedOn: item) {
            persistAnnotationLayer()
            dismiss()
        } else {
            statusText = "Could not save annotated copy."
        }
    }

    private func commitSelectedAnnotation() {
        guard selectedElementID != nil else {
            return
        }

        selectedElementID = nil
        isTextEditorFocused = false
        statusText = "Annotation confirmed."
    }

    private func copyAnnotatedImage() {
        guard let renderedImage else {
            statusText = "Could not render annotated image."
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([renderedImage])
        persistAnnotationLayer()
        statusText = "Annotated image copied."
    }

    private func exportAnnotatedImage() {
        guard let renderedImage,
              let pngData = AnnotationRenderer.pngData(for: renderedImage) else {
            statusText = "Could not render annotated image."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(item.name) - Annotated.png"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try pngData.write(to: url, options: .atomic)
            persistAnnotationLayer()
            statusText = "Annotated image exported."
        } catch {
            statusText = error.localizedDescription
        }
    }

    private var renderedImage: NSImage? {
        guard let sourceImage else {
            return nil
        }

        return AnnotationRenderer.render(sourceImage: sourceImage, elements: elements)
    }

    private func registerUndo() {
        undoStack.append(elements)
    }

    private func undo() {
        guard let previous = undoStack.popLast() else {
            return
        }

        redoStack.append(elements)
        elements = previous
        selectedElementID = nil
    }

    private func redo() {
        guard let next = redoStack.popLast() else {
            return
        }

        undoStack.append(elements)
        elements = next
        selectedElementID = nil
    }

    private func deleteSelected() {
        guard let selectedElementID else {
            return
        }

        registerUndo()
        elements.removeAll { $0.id == selectedElementID }
        self.selectedElementID = nil
        redoStack.removeAll()
    }

    private func moveElement(_ id: UUID, by translation: CGSize, in imageRect: CGRect) {
        guard let baseline = dragBaseline,
              let baselineElement = baseline.first(where: { $0.id == id }),
              let index = elements.firstIndex(where: { $0.id == id }) else {
            return
        }

        let dx = translation.width / max(1, imageRect.width)
        let dy = translation.height / max(1, imageRect.height)
        elements[index].start = clampedPoint(CGPoint(x: baselineElement.start.x + dx, y: baselineElement.start.y + dy))
        elements[index].end = clampedPoint(CGPoint(x: baselineElement.end.x + dx, y: baselineElement.end.y + dy))
        // Freehand strokes carry their whole path, so shift every point too.
        if !baselineElement.points.isEmpty {
            elements[index].points = baselineElement.points.map {
                clampedPoint(CGPoint(x: $0.x + dx, y: $0.y + dy))
            }
        }
    }

    private func resizeElement(_ id: UUID, to point: CGPoint) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else {
            return
        }

        let minimum = defaultSize(for: elements[index].tool)
        let newEnd = clampedPoint(point)
        elements[index].end = CGPoint(
            x: max(0, min(1, max(elements[index].start.x + minimum.width, newEnd.x))),
            y: max(0, min(1, max(elements[index].start.y + minimum.height, newEnd.y)))
        )
    }

    private func normalizedDraft(_ element: AnnotationElement) -> AnnotationElement {
        var updated = element

        // Point-based tools (arrow, line, pen) are defined purely by the points the user
        // dragged — never snap or resize them. The per-axis minimum below only keeps BOX
        // tools from being degenerate; applying it to a line would move its endpoint.
        guard element.tool != .arrow, element.tool != .line, element.tool != .pen else {
            return updated
        }

        // Box tools are edited via a bottom-right resize handle, so keep
        // start at the top-left and end at the bottom-right regardless of drag direction.
        if isResizable(element.tool) {
            let x0 = min(updated.start.x, updated.end.x)
            let x1 = max(updated.start.x, updated.end.x)
            let y0 = min(updated.start.y, updated.end.y)
            let y1 = max(updated.start.y, updated.end.y)
            updated.start = CGPoint(x: x0, y: y0)
            updated.end = CGPoint(x: x1, y: y1)
        }

        let minSize: CGFloat = element.tool == .text || element.tool == .number ? 0.06 : 0.025
        if abs(updated.end.x - updated.start.x) < minSize {
            updated.end.x = min(1, updated.start.x + defaultSize(for: element.tool).width)
        }

        if abs(updated.end.y - updated.start.y) < minSize {
            updated.end.y = min(1, updated.start.y + defaultSize(for: element.tool).height)
        }

        return updated
    }

    private func defaultEndPoint(from point: CGPoint, for tool: AnnotationTool) -> CGPoint {
        let size = defaultSize(for: tool)
        return clampedPoint(CGPoint(x: point.x + size.width, y: point.y + size.height))
    }

    private func defaultSize(for tool: AnnotationTool) -> CGSize {
        switch tool {
        case .select, .pen:
            .zero
        case .text:
            CGSize(width: 0.18, height: 0.07)
        case .number:
            CGSize(width: 0.06, height: 0.06)
        case .arrow, .line:
            CGSize(width: 0.18, height: 0.12)
        case .rectangle, .ellipse, .highlight, .blur, .pixelate, .crop:
            CGSize(width: 0.22, height: 0.13)
        }
    }

    private func annotationColor(for element: AnnotationElement) -> AnnotationColor {
        AnnotationColor(rawValue: element.colorName) ?? .red
    }

    private func nextNumber() -> Int {
        let maxNumber = elements
            .filter { $0.tool == .number }
            .map(\.number)
            .max() ?? 0
        return maxNumber + 1
    }

    private func aspectFitRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height) * 0.92
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func normalizedPoint(_ point: CGPoint, in imageRect: CGRect) -> CGPoint {
        clampedPoint(
            CGPoint(
                x: (point.x - imageRect.minX) / max(1, imageRect.width),
                y: (point.y - imageRect.minY) / max(1, imageRect.height)
            )
        )
    }

    private func normalizedLocalPoint(_ point: CGPoint, in imageRect: CGRect) -> CGPoint {
        clampedPoint(
            CGPoint(
                x: point.x / max(1, imageRect.width),
                y: point.y / max(1, imageRect.height)
            )
        )
    }

    private func clampedPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(1, max(0, point.x)), y: min(1, max(0, point.y)))
    }

    private func point(_ point: CGPoint, in imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: imageRect.minX + point.x * imageRect.width,
            y: imageRect.minY + point.y * imageRect.height
        )
    }

    private func elementRect(_ element: AnnotationElement, in imageRect: CGRect) -> CGRect {
        // A pen stroke's bounds are the extent of its whole path.
        if element.tool == .pen, element.points.count > 1 {
            let mapped = element.points.map { point($0, in: imageRect) }
            let minX = mapped.map(\.x).min() ?? 0
            let maxX = mapped.map(\.x).max() ?? 0
            let minY = mapped.map(\.y).min() ?? 0
            let maxY = mapped.map(\.y).max() ?? 0
            return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
        }

        let start = point(element.start, in: imageRect)
        let end = point(element.end, in: imageRect)
        return CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: max(1, abs(end.x - start.x)),
            height: max(1, abs(end.y - start.y))
        )
    }

    private func annotationHitRect(for element: AnnotationElement, visibleRect: CGRect, in imageRect: CGRect) -> CGRect {
        let padding: CGFloat = hasEndpoints(element.tool) ? 22 : 12
        var hitRect = visibleRect.insetBy(dx: -padding, dy: -padding)

        let minimumSize: CGFloat = element.tool == .number ? 46 : 34
        if hitRect.width < minimumSize {
            hitRect = hitRect.insetBy(dx: -(minimumSize - hitRect.width) / 2, dy: 0)
        }

        if hitRect.height < minimumSize {
            hitRect = hitRect.insetBy(dx: 0, dy: -(minimumSize - hitRect.height) / 2)
        }

        return hitRect.intersection(imageRect.insetBy(dx: -24, dy: -24))
    }

    private func endpointHandle(at point: CGPoint) -> some View {
        Circle()
            .fill(.blue)
            .frame(width: 11, height: 11)
            .overlay {
                Circle().stroke(.white, lineWidth: 1.5)
            }
            .frame(width: 26, height: 26)
            .contentShape(Circle())
            .position(point)
            .help("Drag to reshape the arrow")
    }

    private func resizeHandle(at point: CGPoint) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(.blue)
            .frame(width: 10, height: 10)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(.white, lineWidth: 1)
            }
            .position(point)
            .help("Drag to resize text box")
    }
}

private struct ArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let length: CGFloat = 16
        let spread: CGFloat = .pi / 7
        let first = CGPoint(
            x: end.x - length * cos(angle - spread),
            y: end.y - length * sin(angle - spread)
        )
        let second = CGPoint(
            x: end.x - length * cos(angle + spread),
            y: end.y - length * sin(angle + spread)
        )

        path.move(to: first)
        path.addLine(to: end)
        path.addLine(to: second)
        return path
    }
}

private struct LineShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        return path
    }
}

private struct PenShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else {
            return path
        }
        path.move(to: first)
        for pointValue in points.dropFirst() {
            path.addLine(to: pointValue)
        }
        return path
    }
}

// Cached pixelated copies of the source image, keyed by strength, so the live preview
// can show a genuine pixelation without re-running Core Image on every drag frame.
private enum PixelatePreviewCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(for source: NSImage, strength: CGFloat) -> NSImage {
        let bucket = Int((strength * 100).rounded())
        let key = "\(ObjectIdentifier(source).hashValue)-\(bucket)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let result = AnnotationRenderer.pixelatedImage(from: source, strength: strength) ?? source
        cache.setObject(result, forKey: key)
        return result
    }
}

private enum ArrowEndpoint {
    case start
    case end
}

private extension CGPoint {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}

private extension View {
    @ViewBuilder
    func applyIf<Transformed: View>(_ condition: Bool, transform: (Self) -> Transformed) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// While displaying (not selected) the text view is transparent to clicks so the
// SwiftUI container can select it; only when editing does it capture the mouse.
private final class PassthroughTextView: NSTextView {
    var isClickThrough = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        isClickThrough ? nil : super.hitTest(point)
    }
}

// One NSTextView is used for BOTH the display and the editing state — only its
// `editable` flag flips. Because the view never gets swapped for a different one,
// the text never shifts position when you click it. No focus ring, no field chrome:
// what you see is exactly what gets rendered into the exported image.
private struct EditableAnnotationText: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont
    var textColor: NSColor
    var isEditing: Bool
    var onCommit: () -> Void = {}

    private static let placeholder = "Text"

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> PassthroughTextView {
        let textView = PassthroughTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.focusRingType = .none
        textView.isRichText = false
        textView.importsGraphics = false
        // Let ⌘Z fall through to the editor's own undo stack instead of the field editor,
        // so undo behaves consistently whether or not a text box is focused.
        textView.allowsUndo = false
        textView.textContainerInset = NSSize(width: 6, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        apply(to: textView)
        return textView
    }

    func updateNSView(_ textView: PassthroughTextView, context: Context) {
        context.coordinator.parent = self
        apply(to: textView)
        if isEditing, textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func apply(to textView: PassthroughTextView) {
        textView.font = font
        textView.insertionPointColor = textColor
        textView.isEditable = isEditing
        textView.isSelectable = isEditing
        textView.isClickThrough = !isEditing

        if isEditing {
            if textView.string != text {
                textView.string = text
            }
            textView.textColor = textColor
        } else if text.isEmpty {
            // Faint placeholder so an empty box is still visible/selectable.
            textView.string = Self.placeholder
            textView.textColor = textColor.withAlphaComponent(0.5)
        } else {
            if textView.string != text {
                textView.string = text
            }
            textView.textColor = textColor
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditableAnnotationText

        init(_ parent: EditableAnnotationText) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Enter accepts the text and finishes editing; Shift+Enter inserts a newline.
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                } else {
                    parent.onCommit()
                }
                return true
            }
            return false
        }
    }
}

private enum AnnotationRenderer {
    static func render(sourceImage: NSImage, elements: [AnnotationElement]) -> NSImage? {
        let size = sourceImage.size
        guard size.width > 0, size.height > 0 else {
            return nil
        }

        let output = NSImage(size: size)
        // Draw in a top-left (flipped) coordinate space so the exported image matches
        // the SwiftUI editor exactly. Without this every annotation — blur included —
        // renders vertically mirrored, so a blur would miss the area it covered on screen.
        output.lockFocusFlipped(true)
        sourceImage.draw(
            in: CGRect(origin: .zero, size: size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )

        for element in elements {
            draw(element, sourceImage: sourceImage, imageSize: size)
        }

        output.unlockFocus()

        // A crop keeps only its region of the finished image.
        if let crop = elements.last(where: { $0.tool == .crop }) {
            return cropped(output, to: crop) ?? output
        }

        return output
    }

    private static func cropped(_ image: NSImage, to element: AnnotationElement) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let x0 = min(element.start.x, element.end.x)
        let x1 = max(element.start.x, element.end.x)
        let y0 = min(element.start.y, element.end.y)
        let y1 = max(element.start.y, element.end.y)

        // CGImage is top-left origin, matching our normalized (top-left) coordinates.
        let cropPixels = CGRect(
            x: x0 * pixelWidth,
            y: y0 * pixelHeight,
            width: max(1, (x1 - x0) * pixelWidth),
            height: max(1, (y1 - y0) * pixelHeight)
        ).integral

        guard let sub = cgImage.cropping(to: cropPixels) else {
            return nil
        }

        let pointSize = CGSize(
            width: (x1 - x0) * image.size.width,
            height: (y1 - y0) * image.size.height
        )
        return NSImage(cgImage: sub, size: pointSize)
    }

    static func pngData(for image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    private static func draw(_ element: AnnotationElement, sourceImage: NSImage, imageSize: CGSize) {
        let rect = elementRect(element, imageSize: imageSize)
        let color = AnnotationColor(rawValue: element.colorName) ?? .red

        switch element.tool {
        case .select:
            return
        case .arrow:
            drawArrow(from: point(element.start, imageSize: imageSize), to: point(element.end, imageSize: imageSize), color: color.nsColor)
        case .line:
            color.nsColor.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 5
            path.lineCapStyle = .round
            path.move(to: point(element.start, imageSize: imageSize))
            path.line(to: point(element.end, imageSize: imageSize))
            path.stroke()
        case .pen:
            guard let first = element.points.first else { return }
            color.nsColor.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: point(first, imageSize: imageSize))
            for penPoint in element.points.dropFirst() {
                path.line(to: point(penPoint, imageSize: imageSize))
            }
            path.stroke()
        case .rectangle:
            color.nsColor.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 4
            path.stroke()
        case .ellipse:
            color.nsColor.setStroke()
            let path = NSBezierPath(ovalIn: rect)
            path.lineWidth = 4
            path.stroke()
        case .highlight:
            color.nsColor.withAlphaComponent(color == .black ? 0.18 : 0.32).setFill()
            NSBezierPath(rect: rect).fill()
        case .text:
            let text = element.text.isEmpty ? "Text" : element.text
            let family = AnnotationFontFamily(rawValue: element.fontFamilyName) ?? .system
            let fontSize = max(14, min(96, element.fontSizeRatio * imageSize.height))

            if element.isTextBackgroundVisible {
                let backgroundColor = AnnotationColor(rawValue: element.backgroundColorName) ?? .white
                backgroundColor.nsColor.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: family.nsFont(size: fontSize, weight: .semibold),
                .foregroundColor: color.nsColor
            ]
            let textRect = rect.insetBy(dx: 6, dy: 4)
            text.draw(
                with: textRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes
            )

            if element.isTextBorderVisible {
                let borderColor = AnnotationColor(rawValue: element.borderColorName) ?? color
                borderColor.nsColor.withAlphaComponent(0.86).setStroke()
                let borderPath = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
                borderPath.lineWidth = 2
                borderPath.stroke()
            }
        case .number:
            let circleSize = max(30, min(46, max(rect.width, rect.height)))
            let circleRect = CGRect(
                x: rect.midX - circleSize / 2,
                y: rect.midY - circleSize / 2,
                width: circleSize,
                height: circleSize
            )
            color.nsColor.setFill()
            NSBezierPath(ovalIn: circleRect).fill()

            let text = "\(max(1, element.number))" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: circleSize * 0.48, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: circleRect.midX - textSize.width / 2,
                y: circleRect.midY - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        case .blur:
            drawBlurredPatch(from: sourceImage, in: rect, imageSize: imageSize, strength: element.blurStrength)
        case .pixelate:
            drawPixelatedPatch(from: sourceImage, in: rect, imageSize: imageSize, strength: element.blurStrength)
        case .crop:
            // Crop is applied to the whole image after everything else is drawn.
            return
        }
    }

    private static func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor) {
        color.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: start)
        path.line(to: end)

        let angle = atan2(end.y - start.y, end.x - start.x)
        let length: CGFloat = 22
        let spread: CGFloat = .pi / 7
        let first = CGPoint(
            x: end.x - length * cos(angle - spread),
            y: end.y - length * sin(angle - spread)
        )
        let second = CGPoint(
            x: end.x - length * cos(angle + spread),
            y: end.y - length * sin(angle + spread)
        )
        path.move(to: first)
        path.line(to: end)
        path.line(to: second)
        path.stroke()
    }

    private static func drawBlurredPatch(from sourceImage: NSImage, in rect: CGRect, imageSize: CGSize, strength: CGFloat) {
        guard rect.width > 1, rect.height > 1,
              let tiffData = sourceImage.tiffRepresentation,
              let sourceCIImage = CIImage(data: tiffData) else {
            drawSoftRedaction(in: rect)
            return
        }

        let context = CIContext(options: nil)
        let inputExtent = sourceCIImage.extent
        let scaleX = inputExtent.width / max(1, imageSize.width)
        let scaleY = inputExtent.height / max(1, imageSize.height)
        let cropRect = CGRect(
            x: rect.minX * scaleX,
            y: inputExtent.height - rect.maxY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).intersection(inputExtent)

        guard !cropRect.isNull, !cropRect.isEmpty else {
            drawSoftRedaction(in: rect)
            return
        }

        // The slider only drives blur radius — no darkening tint. Radius is scaled to
        // the source resolution so the effect looks the same on small and large images.
        let base = min(inputExtent.width, inputExtent.height)
        let clampedStrength = min(1, max(0.15, strength))
        let radius = max(4, base * (0.006 + clampedStrength * 0.03))

        let filter = CIFilter.gaussianBlur()
        filter.inputImage = sourceCIImage.clampedToExtent()
        filter.radius = Float(radius)

        guard let outputImage = filter.outputImage?.cropped(to: cropRect),
              let cgImage = context.createCGImage(outputImage, from: cropRect) else {
            drawSoftRedaction(in: rect)
            return
        }

        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: cgImage, size: rect.size).draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
    }

    private static func drawPixelatedPatch(from sourceImage: NSImage, in rect: CGRect, imageSize: CGSize, strength: CGFloat) {
        guard rect.width > 1, rect.height > 1,
              let tiffData = sourceImage.tiffRepresentation,
              let sourceCIImage = CIImage(data: tiffData) else {
            drawSoftRedaction(in: rect)
            return
        }

        let context = CIContext(options: nil)
        let inputExtent = sourceCIImage.extent
        let scaleX = inputExtent.width / max(1, imageSize.width)
        let scaleY = inputExtent.height / max(1, imageSize.height)
        let cropRect = CGRect(
            x: rect.minX * scaleX,
            y: inputExtent.height - rect.maxY * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        ).intersection(inputExtent)

        guard !cropRect.isNull, !cropRect.isEmpty else {
            drawSoftRedaction(in: rect)
            return
        }

        let base = min(inputExtent.width, inputExtent.height)
        let clampedStrength = min(1, max(0.15, strength))
        let blockScale = max(6, base * (0.01 + clampedStrength * 0.06))

        let filter = CIFilter.pixellate()
        filter.inputImage = sourceCIImage.clampedToExtent()
        filter.scale = Float(blockScale)
        filter.center = CGPoint(x: cropRect.midX, y: cropRect.midY)

        guard let outputImage = filter.outputImage?.cropped(to: cropRect),
              let cgImage = context.createCGImage(outputImage, from: cropRect) else {
            drawSoftRedaction(in: rect)
            return
        }

        NSGraphicsContext.current?.imageInterpolation = .none
        NSImage(cgImage: cgImage, size: rect.size).draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
        NSGraphicsContext.current?.imageInterpolation = .high
    }

    // Produces a fully-pixelated copy of the whole image for the live preview.
    static func pixelatedImage(from source: NSImage, strength: CGFloat) -> NSImage? {
        guard let tiffData = source.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            return nil
        }

        let extent = ciImage.extent
        let base = min(extent.width, extent.height)
        let clampedStrength = min(1, max(0.15, strength))
        let blockScale = max(6, base * (0.01 + clampedStrength * 0.06))

        let filter = CIFilter.pixellate()
        filter.inputImage = ciImage.clampedToExtent()
        filter.scale = Float(blockScale)
        filter.center = CGPoint(x: extent.midX, y: extent.midY)

        let context = CIContext(options: nil)
        guard let output = filter.outputImage?.cropped(to: extent),
              let cgImage = context.createCGImage(output, from: extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: source.size)
    }

    private static func drawSoftRedaction(in rect: CGRect) {
        // Fallback only when the blur pipeline is unavailable: hide the area with a neutral fill.
        NSColor(white: 0.5, alpha: 1).setFill()
        NSBezierPath(rect: rect).fill()
    }

    private static func point(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(x: point.x * imageSize.width, y: point.y * imageSize.height)
    }

    private static func elementRect(_ element: AnnotationElement, imageSize: CGSize) -> CGRect {
        let start = point(element.start, imageSize: imageSize)
        let end = point(element.end, imageSize: imageSize)
        return CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: max(1, abs(end.x - start.x)),
            height: max(1, abs(end.y - start.y))
        )
    }
}
