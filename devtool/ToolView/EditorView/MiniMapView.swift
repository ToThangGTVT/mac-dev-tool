//
//  MiniMapView.swift
//  devtool
//

import SwiftUI
import AppKit

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

// MARK: - MiniMapView

final class MiniMapView: NSView {

    var scaleFactor:  CGFloat = 0.18
    var opacityValue: Double  = 0.35
    var currentText:  String  = ""
    var currentFont:  NSFont  = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    var onScroll: ((CGFloat) -> Void)?

    private var miniStorage: NSTextStorage?
    private var miniLM:      NSLayoutManager?
    private var miniTC:      NSTextContainer?

    override var isFlipped:             Bool { true  }
    override var allowsVibrancy:        Bool { false }
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
