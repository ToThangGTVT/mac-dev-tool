//
//  EditorView.swift
//  devtool
//

import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

// MARK: - Tab Model

struct EditorTab: Identifiable {
    let id: UUID
    var text: String
    var fileURL: URL?
    var savingState: MiniMapEditorView.SavingState
    var lastError: String?
    var title: String {
        if let url = fileURL {
            if url.path.contains("/Drafts/") { return "Untitled" }
            return url.lastPathComponent
        }
        return "Untitled"
    }

    init(id: UUID = UUID(), text: String = "", fileURL: URL? = nil) {
        self.id          = id
        self.text        = text
        self.fileURL     = fileURL
        self.savingState = .idle
        self.lastError   = nil
    }
}

// MARK: - EditorScrollProxy

final class EditorScrollProxy {
    static let shared = EditorScrollProxy()
    // Per-tab scroll views keyed by tab ID
    private var scrollViews: [UUID: NSScrollView] = [:]

    func register(_ sv: NSScrollView, for tabID: UUID) {
        scrollViews[tabID] = sv
    }

    func scroll(toRatio ratio: CGFloat, tabID: UUID) {
        guard let sv = scrollViews[tabID],
              let dv = sv.documentView else { return }
        let maxY   = max(0, dv.frame.height - sv.contentSize.height)
        let targetY = maxY * ratio
        sv.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        sv.reflectScrolledClipView(sv.contentView)
    }
}

// MARK: - FlippedClipView

final class FlippedClipView: NSClipView {
    override var isFlipped: Bool { true }
}

final class SolidScrollView: NSScrollView {
    override var allowsVibrancy: Bool { false }
    override func tile() {
        super.tile()
        for sub in subviews {
            if String(describing: type(of: sub)).contains("ContentBackground") {
                sub.alphaValue = 0
            }
            // Ẩn scroller track để tránh render ra ngoài bounds
            if let scroller = sub as? NSScroller {
                scroller.wantsLayer     = true
                scroller.layer?.masksToBounds = true
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Clip mọi thứ vào bounds, tránh đường kẻ chảy ra ngoài
        NSBezierPath(rect: bounds).setClip()
        super.draw(dirtyRect)
    }
}

final class SolidTextView: NSTextView {
    override var allowsVibrancy: Bool { false }
    var currentLineColor: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.12)

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()
        drawCurrentLineHighlight()
        guard let lm = layoutManager, let tc = textContainer else {
            super.draw(dirtyRect); return
        }
        let origin     = NSPoint(x: textContainerInset.width, y: textContainerInset.height)
        let glyphRange = lm.glyphRange(forBoundingRect: dirtyRect, in: tc)
        lm.drawBackground(forGlyphRange: glyphRange, at: origin)
        lm.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }

    private func drawCurrentLineHighlight() {
        guard let lm = layoutManager, let tc = textContainer else { return }
        let len = (string as NSString).length
        if len == 0 {
            let r = NSRect(x: 0, y: textContainerInset.height, width: bounds.width, height: 16)
            currentLineColor.setFill(); r.fill(); return
        }
        // Dùng glyphIndex từ layoutManager — đồng bộ với ruler
        let safeChar  = min(selectedRange().location, len - 1)
        let glyphIndex = lm.glyphIndexForCharacter(at: safeChar)
        var effectiveRange = NSRange()
        let lineRect = lm.lineFragmentRect(forGlyphAt: glyphIndex,
                                           effectiveRange: &effectiveRange,
                                           withoutAdditionalLayout: true)
        let highlightRect = NSRect(x: 0,
                                   y: lineRect.minY + textContainerInset.height,
                                   width: bounds.width,
                                   height: lineRect.height)
        currentLineColor.setFill()
        highlightRect.fill()
    }

    override func setSelectedRange(_ charRange: NSRange,
                                   affinity: NSSelectionAffinity,
                                   stillSelecting: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelecting)
        needsDisplay = true
        enclosingScrollView?.verticalRulerView?.needsDisplay = true
    }
}

// MARK: - MiniMapEditorView

struct MiniMapEditorView: View {

    enum SavingState { case idle, saving, saved, error }

    @State private var tabs: [EditorTab]    = []
    @State private var activeTabID: UUID?   = nil

    @State private var fontSize: CGFloat      = 14
    @State private var miniMapScale: CGFloat  = 0.18
    @State private var miniMapOpacity: Double = 0.35
    @State private var autosaveEnabled        = true

    // Binding helpers into active tab
    private var activeIndex: Int? { tabs.firstIndex(where: { $0.id == activeTabID }) }

    var body: some View {
        VStack(spacing: 0) {
            // ── Tab bar ──────────────────────────────────────────────
            tabBar
            Divider()

            // ── Editor area ──────────────────────────────────────────
            if let idx = activeIndex {
                HStack(spacing: 0) {
                    EditorRepresentable(
                        text:            Binding(get: { tabs[idx].text },
                                                 set: { tabs[idx].text = $0 }),
                        fontSize:        $fontSize,
                        autosaveEnabled: $autosaveEnabled,
                        fileURL:         Binding(get: { tabs[idx].fileURL },
                                                 set: { tabs[idx].fileURL = $0 }),
                        savingState:     Binding(get: { tabs[idx].savingState },
                                                 set: { tabs[idx].savingState = $0 }),
                        lastError:       Binding(get: { tabs[idx].lastError },
                                                 set: { tabs[idx].lastError = $0 }),
                        tabID:           tabs[idx].id
                    )
                    MiniMapRepresentable(
                        text:        Binding(get: { tabs[idx].text },
                                             set: { tabs[idx].text = $0 }),
                        fontSize:    $fontSize,
                        scaleFactor: $miniMapScale,
                        opacity:     $miniMapOpacity,
                        onScroll:    { ratio in
                            EditorScrollProxy.shared.scroll(toRatio: ratio,
                                                            tabID: tabs[idx].id)
                        }
                    )
                    .frame(width: 140)
                    .border(Color.gray.opacity(0.2), width: 1)
                }

                Divider()
                statusBar(for: idx)

            } else {
                // No tabs open
                VStack {
                    Spacer()
                    Text("No file open")
                        .foregroundColor(.secondary)
                    Button("New Tab") { addTab() }
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar { toolbarContent }
        .onAppear { if tabs.isEmpty { addTab() } }
    }

    // MARK: Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    tabButton(tab)
                }
                // "+" button
                Button {
                    addTab()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }
        }
        .frame(height: 34)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func tabButton(_ tab: EditorTab) -> some View {
        let isActive = tab.id == activeTabID
        HStack(spacing: 4) {
            // Saving indicator dot
            Circle()
                .fill(savingColor(tab.savingState))
                .frame(width: 7, height: 7)

            Text(tab.title)
                .lineLimit(1)
                .frame(maxWidth: 140)
                .truncationMode(.middle)

            // Close button
            Button {
                closeTab(tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isActive ? 1 : 0.4)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(isActive
            ? Color(NSColor.controlBackgroundColor)
            : Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { activeTabID = tab.id }
        .contextMenu {
            Button("Close Tab")       { closeTab(tab.id) }
            Button("Close Other Tabs") { closeOtherTabs(tab.id) }
            Divider()
            Button("New Tab")         { addTab() }
        }
    }

    private func savingColor(_ state: SavingState) -> Color {
        switch state {
        case .idle:   return .gray.opacity(0.4)
        case .saving: return .blue
        case .saved:  return .green
        case .error:  return .red
        }
    }

    // MARK: Status bar

    private func statusBar(for idx: Int) -> some View {
        HStack {
            if let e = tabs[idx].lastError {
                Label(e, systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
            } else {
                Text("Line numbers • MiniMap • Auto-save 500ms").foregroundColor(.secondary)
            }
            Spacer()
            Text(fileLabel(for: tabs[idx]))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 300)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Button { openDoc() } label: {
                Label("Open", systemImage: "folder.badge.plus")
            }.help("Open file")

            Button { saveAsDoc() } label: {
                Label("Save As", systemImage: "square.and.arrow.down")
            }.help("Save As")

            Button { addTab() } label: {
                Label("New Tab", systemImage: "doc.badge.plus")
            }.help("New Tab")

            Divider()

            Toggle(isOn: $autosaveEnabled) {
                Label("Auto-save",
                      systemImage: autosaveEnabled ? "clock.badge.checkmark" : "clock.badge.xmark")
            }.help("Toggle Auto-save")

            Divider()

            HStack {
                Text("Font:")
                Slider(value: $fontSize, in: 10...28).frame(width: 80)
                Text("\(Int(fontSize))pt").frame(width: 32)
            }

            HStack {
                Text("Map:")
                Slider(value: $miniMapScale, in: 0.08...0.4).frame(width: 80)
                Text(String(format: "%.2f×", miniMapScale)).frame(width: 42)
            }

            Divider()

            // Active tab status icon
            if let idx = activeIndex {
                statusIcon(for: tabs[idx].savingState)
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for state: SavingState) -> some View {
        switch state {
        case .idle:
            Label("Idle",    systemImage: "pause.circle").foregroundColor(.secondary)
        case .saving:
            Label("Saving…", systemImage: "arrow.triangle.2.circlepath.circle").foregroundColor(.blue)
        case .saved:
            Label("Saved",   systemImage: "checkmark.circle").foregroundColor(.green)
        case .error:
            Label("Error",   systemImage: "xmark.octagon").foregroundColor(.red)
        }
    }

    // MARK: Tab management

    private func addTab(text: String = "", fileURL: URL? = nil) {
        var tab    = EditorTab(text: text, fileURL: fileURL ?? draftURL())
        tabs.append(tab)
        activeTabID = tab.id
    }

    private func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        if activeTabID == id {
            activeTabID = tabs.isEmpty ? nil : tabs[min(idx, tabs.count - 1)].id
        }
    }

    private func closeOtherTabs(_ id: UUID) {
        tabs = tabs.filter { $0.id == id }
        activeTabID = id
    }

    // MARK: File actions

    private func openDoc() {
        DispatchQueue.main.async {
            let p = NSOpenPanel()
            if #available(macOS 12.0, *) {
                p.allowedContentTypes = [UTType.plainText, UTType.json, UTType.xml, UTType.sourceCode,
                                         UTType(filenameExtension: "md")   ?? .plainText,
                                         UTType(filenameExtension: "yaml") ?? .plainText,
                                         UTType(filenameExtension: "yml")  ?? .plainText,
                                         UTType(filenameExtension: "csv")  ?? .plainText,
                                         UTType(filenameExtension: "log")  ?? .plainText]
            } else {
                p.allowedFileTypes = ["txt","md","json","xml","yaml","yml","log","swift","csv"]
            }
            p.allowsMultipleSelection = true
            p.begin { r in
                guard r == .OK else { return }
                DispatchQueue.main.async {
                    for url in p.urls {
                        if let content = try? String(contentsOf: url, encoding: .utf8) {
                            self.addTab(text: content, fileURL: url)
                        }
                    }
                }
            }
        }
    }

    private func saveAsDoc() {
        guard let idx = activeIndex else { return }
        DispatchQueue.main.async {
            let p = NSSavePanel()
            if #available(macOS 12.0, *) {
                p.allowedContentTypes = [UTType.plainText]
            } else {
                p.allowedFileTypes = ["txt"]
            }
            p.nameFieldStringValue = self.tabs[idx].title.hasSuffix(".txt")
                ? self.tabs[idx].title : "Untitled.txt"
            p.begin { r in
                guard r == .OK, let url = p.url else { return }
                do {
                    try self.tabs[idx].text.data(using: .utf8)?.write(to: url, options: .atomic)
                    DispatchQueue.main.async {
                        self.tabs[idx].fileURL     = url
                        self.tabs[idx].savingState = .saved
                        self.tabs[idx].lastError   = nil
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.tabs[idx].lastError   = "Save: \(error.localizedDescription)"
                        self.tabs[idx].savingState = .error
                    }
                }
            }
        }
    }

    private func draftURL() -> URL {
        let fm  = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "MiniMapEditor")
            .appendingPathComponent("Drafts")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // Unique filename per draft
        let name = "untitled-\(UUID().uuidString.prefix(8)).txt"
        return dir.appendingPathComponent(name)
    }

    private func fileLabel(for tab: EditorTab) -> String {
        guard let u = tab.fileURL else { return "Draft" }
        return u.path.contains("/Drafts/") ? "Draft → \(u.lastPathComponent)" : u.path
    }
}

// MARK: - EditorRepresentable

struct EditorRepresentable: NSViewRepresentable {

    @Binding var text:            String
    @Binding var fontSize:        CGFloat
    @Binding var autosaveEnabled: Bool
    @Binding var fileURL:         URL?
    @Binding var savingState:     MiniMapEditorView.SavingState
    @Binding var lastError:       String?
    let tabID: UUID

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let lm      = NSLayoutManager()
        let tc      = NSTextContainer(size: NSSize(width: 600, height: 1e7))
        tc.widthTracksTextView = true
        tc.lineFragmentPadding = 6
        lm.addTextContainer(tc)
        storage.addLayoutManager(lm)

        let tv = SolidTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400),
                               textContainer: tc)
        tv.minSize               = .zero
        tv.maxSize               = NSSize(width: 1e7, height: 1e7)
        tv.isVerticallyResizable   = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask        = [.width]
        tv.isRichText                          = false
        tv.allowsUndo                          = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled  = false
        tv.isAutomaticDataDetectionEnabled     = false
        tv.isAutomaticLinkDetectionEnabled     = false
        tv.isAutomaticTextReplacementEnabled   = false
        tv.isGrammarCheckingEnabled            = false
        tv.isContinuousSpellCheckingEnabled    = false

        let font    = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let fgColor = NSColor.labelColor
        let bgColor = NSColor.textBackgroundColor

        tv.font                   = font
        tv.drawsBackground        = true
        tv.backgroundColor        = bgColor
        tv.textColor              = fgColor
        tv.insertionPointColor    = fgColor
        tv.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]
        tv.typingAttributes       = [.font: font, .foregroundColor: fgColor]

        storage.setAttributedString(NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: fgColor]
        ))

        let sv = SolidScrollView()
        sv.borderType            = .noBorder
        sv.hasVerticalScroller   = true
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers    = true
        sv.drawsBackground       = true
        sv.backgroundColor       = bgColor
        sv.wantsLayer            = true
        sv.layer?.masksToBounds  = true

        let clip = FlippedClipView()
        clip.drawsBackground = true
        clip.backgroundColor = bgColor
        sv.contentView  = clip
        sv.documentView = tv

        let ruler = LineNumberRulerView(textView: tv)
        sv.hasVerticalRuler  = true
        sv.rulersVisible     = true
        sv.verticalRulerView = ruler

        sv.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textChanged(_:)),
            name: NSText.didChangeNotification, object: tv)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrolled(_:)),
            name: NSView.boundsDidChangeNotification, object: sv.contentView)

        context.coordinator.tv     = tv
        context.coordinator.sv     = sv
        context.coordinator.ruler  = ruler
        context.coordinator.tc     = tc
        context.coordinator.lm     = lm
        context.coordinator.parent = self

        EditorScrollProxy.shared.register(sv, for: tabID)

        DispatchQueue.main.async { [weak tv, weak sv, weak ruler] in
            guard let tv = tv, let sv = sv else { return }
            lm.ensureLayout(for: tc)
            tv.sizeToFit()
            sv.contentView.scroll(to: .zero)
            sv.reflectScrolledClipView(sv.contentView)
            ruler?.invalidateLineCache()
            ruler?.needsDisplay = true
        }

        context.coordinator.scheduleAutosave()
        DispatchQueue.main.async { [weak sv] in
            sv?.window?.appearance = NSAppearance(named: .aqua)
        }
        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        guard let tv    = context.coordinator.tv,
              let ruler = context.coordinator.ruler,
              let lm    = context.coordinator.lm,
              let tc    = context.coordinator.tc else { return }

        let font    = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let fgColor = NSColor.labelColor

        if tv.string != text {
            tv.textStorage?.setAttributedString(NSAttributedString(
                string: text, attributes: [.font: font, .foregroundColor: fgColor]))
            lm.ensureLayout(for: tc); tv.sizeToFit()
            ruler.invalidateLineCache(); ruler.needsDisplay = true
        }

        if tv.font?.pointSize != fontSize {
            tv.font = font; tv.textColor = fgColor
            tv.typingAttributes = [.font: font, .foregroundColor: fgColor]
            if let ts = tv.textStorage {
                ts.beginEditing()
                ts.addAttribute(.font, value: font,
                                range: NSRange(location: 0, length: ts.length))
                ts.addAttribute(.foregroundColor, value: fgColor,
                                range: NSRange(location: 0, length: ts.length))
                ts.endEditing()
            }
            lm.ensureLayout(for: tc); tv.sizeToFit()
            ruler.invalidateLineCache(); ruler.needsDisplay = true
        }

        let w = max(sv.contentSize.width - 2, 100)
        if abs(tc.containerSize.width - w) > 4 {
            tc.containerSize = NSSize(width: w, height: 1e7)
            lm.ensureLayout(for: tc); tv.sizeToFit()
        }

        EditorScrollProxy.shared.register(sv, for: tabID)
        context.coordinator.parent = self

        // Force redraw cả textView và ruler khi switch tab
        // để currentLine highlight sync đúng với cursor
        tv.needsDisplay = true
        ruler.needsDisplay = true
    }

    // MARK: Coordinator
    class Coordinator: NSObject {
        var parent: EditorRepresentable
        weak var tv:    NSTextView?
        weak var sv:    NSScrollView?
        weak var ruler: LineNumberRulerView?
        var tc: NSTextContainer?
        var lm: NSLayoutManager?
        private var debounce: DispatchWorkItem?

        init(_ p: EditorRepresentable) { parent = p }

        @objc func textChanged(_ n: Notification) {
            guard let tv = tv else { return }
            if parent.text != tv.string { parent.text = tv.string }
            ruler?.invalidateLineCache(); ruler?.needsDisplay = true
            scheduleAutosave()
        }

        @objc func scrolled(_ n: Notification) { ruler?.needsDisplay = true }

        func scheduleAutosave() {
            debounce?.cancel()
            guard parent.autosaveEnabled else { return }
            let w = DispatchWorkItem { [weak self] in self?.save() }
            debounce = w
            parent.savingState = .saving
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: w)
        }

        private func save() {
            guard let url = parent.fileURL else {
                parent.lastError = "No file URL"; parent.savingState = .error; return
            }
            do {
                try (parent.text.data(using: .utf8) ?? Data()).write(to: url, options: .atomic)
                parent.lastError = nil; parent.savingState = .saved
            } catch {
                parent.lastError = "Autosave: \(error.localizedDescription)"
                parent.savingState = .error
            }
        }
    }
}

// MARK: - MiniMapRepresentable

struct MiniMapRepresentable: NSViewRepresentable {
    @Binding var text:        String
    @Binding var fontSize:    CGFloat
    @Binding var scaleFactor: CGFloat
    @Binding var opacity:     Double
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> MiniMapView {
        let mm = MiniMapView()
        mm.scaleFactor  = scaleFactor
        mm.opacityValue = opacity
        mm.currentText  = text
        mm.currentFont  = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        mm.onScroll     = onScroll
        return mm
    }

    func updateNSView(_ mm: MiniMapView, context: Context) {
        mm.scaleFactor  = scaleFactor
        mm.opacityValue = opacity
        mm.currentText  = text
        mm.currentFont  = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        mm.onScroll     = onScroll
        mm.refresh()
    }
}

// MARK: - Line Number Ruler

final class LineNumberRulerView: NSRulerView {

    weak var textView: NSTextView?
    private var lineStarts: [Int] = [0]

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView    = textView
        ruleThickness = 44
        invalidateLineCache()
    }
    required init(coder: NSCoder) { super.init(coder: coder) }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let tv = textView,
              let lm = tv.layoutManager,
              let tc = tv.textContainer,
              let sv = scrollView else { return }

        // ── Background ────────────────────────────────────────────────
        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        // ── Update thickness BEFORE drawing so layout is stable ───────
        if lineStarts.isEmpty { invalidateLineCache() }
        let digits = String(max(1, lineStarts.count)).count
        let needed = CGFloat(8 + digits * 8 + 12)
        if abs(ruleThickness - needed) > 0.5 {
            ruleThickness = needed
            // Thickness changed — AppKit will call draw again, skip this pass
            return
        }

        let clipBounds  = sv.contentView.bounds
        let visibleInTV = sv.contentView.convert(clipBounds, to: tv)
        let gr          = lm.glyphRange(forBoundingRect: visibleInTV, in: tc)

        let fSize       = max((tv.font?.pointSize ?? 12) - 2, 9)
        let cursorIndex = tv.selectedRange().location
        let strLen      = tv.string.count
        // Tính currentLine từ layoutManager để đồng bộ với SolidTextView
        let currentLine: Int
        if strLen == 0 {
            currentLine = 1
        } else {
            let safeChar  = min(cursorIndex, strLen - 1)
            let glyphIdx  = lm.glyphIndexForCharacter(at: safeChar)
            var glyphRange = NSRange()
            lm.lineFragmentRect(forGlyphAt: glyphIdx,
                                effectiveRange: &glyphRange,
                                withoutAdditionalLayout: true)
            let charRange = lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            currentLine   = lineIndex(for: charRange.location) + 1
        }

        var idx = gr.location
        let end = NSMaxRange(gr)
        guard end > idx || tv.string.isEmpty else {
            drawSeparator(); return
        }

        while idx < end {
            var lr = NSRange()
            let fr = lm.lineFragmentRect(forGlyphAt: idx, effectiveRange: &lr,
                                         withoutAdditionalLayout: true)
            guard lr.length > 0 else { break }
            let cr        = lm.characterRange(forGlyphRange: lr, actualGlyphRange: nil)
            let ln        = lineIndex(for: cr.location) + 1
            let frInRuler = tv.convert(fr, to: self)
            let isCurrent = (ln == currentLine)

            if isCurrent {
                let hr = NSRect(x: 0, y: frInRuler.minY,
                                width: bounds.width - 1, height: frInRuler.height)
                NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
                hr.fill()
            }

            let lineColor: NSColor = isCurrent ? .labelColor : .secondaryLabelColor
            let lineFont = isCurrent
                ? NSFont.monospacedDigitSystemFont(ofSize: fSize, weight: .semibold)
                : NSFont.monospacedDigitSystemFont(ofSize: fSize, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: lineColor, .font: lineFont]
            let s  = "\(ln)" as NSString
            let sz = s.size(withAttributes: attrs)
            s.draw(at: NSPoint(x: ruleThickness - 6 - sz.width,
                               y: frInRuler.minY + (frInRuler.height - sz.height) / 2),
                   withAttributes: attrs)

            let next = NSMaxRange(lr)
            if next <= idx { break }
            idx = next
        }

        drawSeparator()
    }

    private func drawSeparator() {
        // Vẽ đường kẻ sát mép PHẢI của ruler (ngay trước editor)
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        path.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        path.lineWidth = 1
        path.stroke()
    }

    func invalidateLineCache() {
        guard let tv = textView else { lineStarts = [0]; return }
        let s = tv.string as NSString
        var a: [Int] = [0]
        var pos = 0
        while pos < s.length {
            let range   = s.lineRange(for: NSRange(location: pos, length: 0))
            let nextPos = NSMaxRange(range)
            if nextPos < s.length { a.append(nextPos) }
            if nextPos <= pos { break }
            pos = nextPos
        }
        lineStarts = a.isEmpty ? [0] : a
    }

    private func lineIndex(for loc: Int) -> Int {
        var lo = 0, hi = lineStarts.count - 1, ans = 0
        while lo <= hi {
            let mid = (lo + hi) / 2
            if lineStarts[mid] <= loc { ans = mid; lo = mid + 1 } else { hi = mid - 1 }
        }
        return ans
    }
}

// MARK: - MiniMap View

final class MiniMapView: NSView {

    var scaleFactor:  CGFloat = 0.18
    var opacityValue: Double  = 0.35
    var currentText:  String  = ""
    var currentFont:  NSFont  = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    var onScroll: ((CGFloat) -> Void)?

    private var miniStorage: NSTextStorage?
    private var miniLM:      NSLayoutManager?
    private var miniTC:      NSTextContainer?

    override var isFlipped:            Bool { true  }
    override var allowsVibrancy:       Bool { false }
    override var acceptsFirstResponder: Bool { true  }

    func refresh() { buildStorage(); needsDisplay = true }

    private func buildStorage() {
        let w = max(bounds.width / scaleFactor, 200)
        if miniStorage == nil {
            let st = NSTextStorage()
            let lm = NSLayoutManager()
            let tc = NSTextContainer(size: NSSize(width: w, height: 1e7))
            tc.lineFragmentPadding = 0
            lm.addTextContainer(tc)
            st.addLayoutManager(lm)
            miniStorage = st; miniLM = lm; miniTC = tc
        }
        miniTC?.containerSize = NSSize(width: w, height: 1e7)
        miniStorage?.beginEditing()
        miniStorage?.setAttributedString(NSAttributedString(
            string: currentText,
            attributes: [.font: currentFont,
                         .foregroundColor: NSColor.labelColor.withAlphaComponent(opacityValue)]))
        miniStorage?.endEditing()
        miniLM?.ensureLayout(for: miniTC!)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        bounds.fill()
        if miniStorage == nil { buildStorage() }
        guard let lm = miniLM, let st = miniStorage else { return }
        NSGraphicsContext.current?.saveGraphicsState()
        let t = NSAffineTransform(); t.scale(by: scaleFactor); t.concat()
        lm.drawBackground(forGlyphRange: NSRange(location: 0, length: st.length), at: .zero)
        lm.drawGlyphs(forGlyphRange: NSRange(location: 0, length: st.length), at: .zero)
        NSGraphicsContext.current?.restoreGraphicsState()
        NSColor.separatorColor.withAlphaComponent(0.4).setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0.5, y: 0))
        path.line(to: NSPoint(x: 0.5, y: bounds.height))
        path.lineWidth = 1; path.stroke()
    }

    override func mouseDown(with event: NSEvent)    { scrollEditor(to: event) }
    override func mouseDragged(with event: NSEvent) { scrollEditor(to: event) }

    private func scrollEditor(to event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        guard let lm = miniLM, let tc = miniTC else { return }
        let usedHeight = lm.usedRect(for: tc).height * scaleFactor
        guard usedHeight > 0 else { return }
        onScroll?(max(0, min(1, pt.y / usedHeight)))
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
