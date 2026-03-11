//
//  EditorView.swift
//  devtool
//

import SwiftUI
import AppKit

// MARK: - FlippedClipView

final class FlippedClipView: NSClipView {
    override var isFlipped: Bool { true }
}

// MARK: - MiniMapEditorView

struct MiniMapEditorView: View {

    @State private var text: String = """
// Notepad++ style editor — MiniMap + Line Numbers + Auto-Save

func hello() {
    print("Hello world!")
}

for i in 1...120 {
    print("Line: \\(i)")
}
"""
    @State private var fontSize: CGFloat      = 14
    @State private var miniMapScale: CGFloat  = 0.18
    @State private var miniMapOpacity: Double = 0.35
    @State private var fileURL: URL?          = nil
    @State private var autosaveEnabled        = true
    @State private var savingState            = SavingState.idle
    @State private var lastError: String?     = nil

    enum SavingState { case idle, saving, saved, error }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                EditorRepresentable(
                    text:            $text,
                    fontSize:        $fontSize,
                    autosaveEnabled: $autosaveEnabled,
                    fileURL:         $fileURL,
                    savingState:     $savingState,
                    lastError:       $lastError
                )
                MiniMapRepresentable(
                    text:        $text,
                    fontSize:    $fontSize,
                    scaleFactor: $miniMapScale,
                    opacity:     $miniMapOpacity
                )
                .frame(width: 140)
                .border(Color.gray.opacity(0.2), width: 1)
            }
            Divider()
            statusBar
        }
        .onAppear { if fileURL == nil { fileURL = draftURL() } }
    }

    // MARK: Toolbar
    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button("New")      { text = ""; fileURL = draftURL(); savingState = .idle; lastError = nil }
                Button("Open…")    { openDoc() }
                Button("Save As…") { saveAsDoc() }
                Divider().frame(height: 22)
                Toggle("Auto-save", isOn: $autosaveEnabled)
                Divider().frame(height: 22)
                HStack {
                    Text("Font:")
                    Slider(value: $fontSize, in: 10...28).frame(width: 100)
                    Text("\(Int(fontSize))pt").frame(width: 36)
                }
                HStack {
                    Text("Map:")
                    Slider(value: $miniMapScale, in: 0.08...0.4).frame(width: 100)
                    Text(String(format: "%.2f×", miniMapScale)).frame(width: 46)
                }
                HStack {
                    Text("Opacity:")
                    Slider(value: $miniMapOpacity, in: 0.1...1.0).frame(width: 100)
                    Text(String(format: "%.2f", miniMapOpacity)).frame(width: 36)
                }
                Spacer(minLength: 16)
                statusIcon
                Text(fileLabel())
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 240)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var statusIcon: some View {
        switch savingState {
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

    private var statusBar: some View {
        HStack {
            if let e = lastError {
                Label(e, systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
            } else {
                Text("Line numbers • MiniMap • Auto-save 500ms").foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: File actions
    private func openDoc() {
        let p = NSOpenPanel()
        p.allowedFileTypes = ["txt","md","json","xml","yaml","yml","log","swift","csv"]
        p.begin { r in
            guard r == .OK, let url = p.url else { return }
            do {
                text = try String(contentsOf: url, encoding: .utf8)
                fileURL = url; savingState = .saved; lastError = nil
            } catch {
                lastError = "Open: \(error.localizedDescription)"; savingState = .error
            }
        }
    }

    private func saveAsDoc() {
        let p = NSSavePanel()
        p.allowedFileTypes = ["txt"]
        p.nameFieldStringValue = "Untitled.txt"
        p.begin { r in
            guard r == .OK, let url = p.url else { return }
            do {
                try text.data(using: .utf8)?.write(to: url, options: .atomic)
                fileURL = url; savingState = .saved; lastError = nil
            } catch {
                lastError = "Save: \(error.localizedDescription)"; savingState = .error
            }
        }
    }

    private func draftURL() -> URL {
        let fm  = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "MiniMapEditor")
            .appendingPathComponent("Drafts")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("untitled.txt")
    }

    private func fileLabel() -> String {
        guard let u = fileURL else { return "Draft" }
        return u.path.contains("/Drafts/untitled.txt") ? "Draft → untitled.txt" : u.path
    }
}

// MARK: - EditorRepresentable (trả về NSScrollView trực tiếp)

struct EditorRepresentable: NSViewRepresentable {

    @Binding var text:            String
    @Binding var fontSize:        CGFloat
    @Binding var autosaveEnabled: Bool
    @Binding var fileURL:         URL?
    @Binding var savingState:     MiniMapEditorView.SavingState
    @Binding var lastError:       String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {

        // ── 1. TextKit 1 stack thủ công ──────────────────────────────
        let storage = NSTextStorage()
        let lm      = NSLayoutManager()
        let tc      = NSTextContainer(size: NSSize(width: 600, height: 1e7))
        tc.widthTracksTextView = true
        tc.lineFragmentPadding = 6
        lm.addTextContainer(tc)
        storage.addLayoutManager(lm)

        let tv = NSTextView(
            frame: NSRect(x: 0, y: 0, width: 600, height: 400),
            textContainer: tc
        )
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

        // ── 2. Màu & font ─────────────────────────────────────────────
        let font   = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        // Dùng labelColor thay vì textColor — đậm hơn, không bị wash out
        let fgColor = NSColor.labelColor
        let bgColor = NSColor.textBackgroundColor

        tv.font                   = font
        tv.drawsBackground        = true
        tv.backgroundColor        = bgColor
        tv.textColor              = fgColor
        tv.insertionPointColor    = fgColor
        tv.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]
        tv.typingAttributes       = [.font: font, .foregroundColor: fgColor]

        // ── 3. Set text qua textStorage ───────────────────────────────
        storage.setAttributedString(NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: fgColor]
        ))

        // ── 4. ScrollView ─────────────────────────────────────────────
        let sv = NSScrollView()
        sv.borderType            = .noBorder
        sv.hasVerticalScroller   = true
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers    = true
        sv.drawsBackground       = true
        sv.backgroundColor       = .textBackgroundColor

        // FlippedClipView để fix tọa độ Y
        let clip = FlippedClipView()
        clip.drawsBackground = true
        clip.backgroundColor = .textBackgroundColor
        sv.contentView  = clip   // TRƯỚC documentView
        sv.documentView = tv

        // ── 5. Line number ruler ──────────────────────────────────────
        let ruler = LineNumberRulerView(textView: tv)
        sv.hasVerticalRuler  = true
        sv.rulersVisible     = true
        sv.verticalRulerView = ruler

        // ── 6. Notifications ──────────────────────────────────────────
        sv.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textChanged(_:)),
            name: NSText.didChangeNotification,
            object: tv
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrolled(_:)),
            name: NSView.boundsDidChangeNotification,
            object: sv.contentView
        )

        context.coordinator.tv    = tv
        context.coordinator.sv    = sv
        context.coordinator.ruler = ruler
        context.coordinator.tc    = tc
        context.coordinator.lm    = lm
        context.coordinator.parent = self

        // ── 7. First layout ───────────────────────────────────────────
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
            // Tìm và disable NSVisualEffectView cha
            var v: NSView? = sv
            while let parent = v?.superview {
                if let effect = parent as? NSVisualEffectView {
                    effect.material = .windowBackground
                    effect.blendingMode = .behindWindow
                    effect.state = .inactive
                }
                v = parent
            }
        }

        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        guard
            let tv    = context.coordinator.tv,
            let ruler = context.coordinator.ruler,
            let lm    = context.coordinator.lm,
            let tc    = context.coordinator.tc
        else { return }

        let font    = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let fgColor = NSColor.labelColor

        // Text thay đổi từ SwiftUI
        if tv.string != text {
            tv.textStorage?.setAttributedString(NSAttributedString(
                string: text,
                attributes: [.font: font, .foregroundColor: fgColor]
            ))
            lm.ensureLayout(for: tc)
            tv.sizeToFit()
            ruler.invalidateLineCache()
            ruler.needsDisplay = true
        }

        // Font size thay đổi
        if tv.font?.pointSize != fontSize {
            tv.font = font
            tv.textColor = fgColor
            tv.typingAttributes = [.font: font, .foregroundColor: fgColor]
            if let ts = tv.textStorage {
                ts.beginEditing()
                ts.addAttribute(.font, value: font,
                                range: NSRange(location: 0, length: ts.length))
                ts.addAttribute(.foregroundColor, value: fgColor,
                                range: NSRange(location: 0, length: ts.length))
                ts.endEditing()
            }
            lm.ensureLayout(for: tc)
            tv.sizeToFit()
            ruler.invalidateLineCache()
            ruler.needsDisplay = true
        }

        // containerSize update khi view resize
        let w = max(sv.contentSize.width - 2, 100)
        if abs(tc.containerSize.width - w) > 4 {
            tc.containerSize = NSSize(width: w, height: 1e7)
            lm.ensureLayout(for: tc)
            tv.sizeToFit()
        }

        context.coordinator.parent = self
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
            ruler?.invalidateLineCache()
            ruler?.needsDisplay = true
            scheduleAutosave()
        }

        @objc func scrolled(_ n: Notification) {
            ruler?.needsDisplay = true
        }

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

    func makeNSView(context: Context) -> MiniMapView {
        let mm = MiniMapView()
        mm.scaleFactor  = scaleFactor
        mm.opacityValue = opacity
        mm.currentText  = text
        mm.currentFont  = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        return mm
    }

    func updateNSView(_ mm: MiniMapView, context: Context) {
        mm.scaleFactor  = scaleFactor
        mm.opacityValue = opacity
        mm.currentText  = text
        mm.currentFont  = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
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
              let tc = tv.textContainer else { return }

        // Background
        NSColor.textBackgroundColor.withAlphaComponent(0.95).setFill()
        rect.fill()

        let visibleRect = scrollView?.contentView.bounds ?? .zero
        let gr = lm.glyphRange(forBoundingRect: visibleRect, in: tc)
        if lineStarts.isEmpty { invalidateLineCache() }

        let fSize = max((tv.font?.pointSize ?? 12) - 2, 9)
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.secondaryLabelColor,
            .font: NSFont.monospacedDigitSystemFont(ofSize: fSize, weight: .regular)
        ]

        var idx = gr.location
        let end = gr.location + gr.length
        while idx < end {
            var lr = NSRange()
            let fr = lm.lineFragmentRect(
                forGlyphAt: idx, effectiveRange: &lr, withoutAdditionalLayout: true)
            guard lr.length > 0 else { break }
            let cr = lm.characterRange(forGlyphRange: lr, actualGlyphRange: nil)
            let ln = lineIndex(for: cr.location) + 1
            let s  = "\(ln)" as NSString
            let sz = s.size(withAttributes: attrs)
            s.draw(at: NSPoint(x: ruleThickness - 6 - sz.width,
                               y: fr.minY + (fr.height - sz.height) / 2),
                   withAttributes: attrs)
            let next = NSMaxRange(lr)
            if next <= idx { break }
            idx = next
        }

        // Divider
        NSColor.separatorColor.setStroke()
        let path = NSBezierPath()
        path.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        path.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        path.lineWidth = 1
        path.stroke()

        // Dynamic width
        let digits = String(max(1, lineStarts.count)).count
        let needed = CGFloat(8 + digits * 8 + 12)
        if abs(ruleThickness - needed) > 0.5 { ruleThickness = needed }
    }

    func invalidateLineCache() {
        guard let tv = textView else { lineStarts = [0]; return }
        let s = tv.string as NSString
        var a: [Int] = [0]
        s.enumerateSubstrings(
            in: NSRange(location: 0, length: s.length),
            options: [.byLines, .substringNotRequired]
        ) { _, r, _, _ in
            let n = NSMaxRange(r); if n < s.length { a.append(n) }
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

    private var miniStorage: NSTextStorage?
    private var miniLM:      NSLayoutManager?
    private var miniTC:      NSTextContainer?

    override var isFlipped: Bool { true }

    func refresh() {
        buildStorage()
        needsDisplay = true
    }

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
            attributes: [
                .font: currentFont,
                .foregroundColor: NSColor.labelColor.withAlphaComponent(opacityValue)
            ]
        ))
        miniStorage?.endEditing()
        miniLM?.ensureLayout(for: miniTC!)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        if miniStorage == nil { buildStorage() }
        guard let lm = miniLM, let st = miniStorage else { return }

        NSGraphicsContext.current?.saveGraphicsState()
        let t = NSAffineTransform()
        t.scale(by: scaleFactor)
        t.concat()
        lm.drawBackground(forGlyphRange: NSRange(location: 0, length: st.length), at: .zero)
        lm.drawGlyphs(forGlyphRange: NSRange(location: 0, length: st.length), at: .zero)
        NSGraphicsContext.current?.restoreGraphicsState()
    }
}
