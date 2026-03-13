//
// EditorAppKitViews.swift
// devtool
//

import AppKit

// MARK: - EditorScrollProxy
final class EditorScrollProxy {
    static let shared = EditorScrollProxy()
    private var scrollViews: [UUID: NSScrollView] = [:]
    private var rulers: [UUID: LineNumberRulerView] = [:]
    
    func register(_ sv: NSScrollView, ruler: LineNumberRulerView? = nil, for tabID: UUID) {
        scrollViews[tabID] = sv
        if let r = ruler {
            rulers[tabID] = r
        }
    }
    
    func scroll(toRatio ratio: CGFloat, tabID: UUID) {
        guard let sv = scrollViews[tabID],
              let dv = sv.documentView else { return }
        let maxY = max(0, dv.frame.height - sv.contentSize.height)
        let targetY = maxY * ratio
        sv.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        sv.reflectScrolledClipView(sv.contentView)
    }

    func invalidateRuler(for tabID: UUID) {
        DispatchQueue.main.async {
            if let ruler = self.rulers[tabID] {
                ruler.invalidateLineCache()
                ruler.needsDisplay = true
            }
        }
    }
}

// MARK: - SolidScrollView
final class SolidScrollView: NSScrollView {
    var adjustedContentWidth: CGFloat {
        var w = contentSize.width
        if let ruler = verticalRulerView, rulersVisible {
            let ruleW = ruler.ruleThickness
            let contentFrame = contentView.frame
            if contentFrame.minX < ruleW {
                w = contentFrame.width - (ruleW - contentFrame.minX)
            }
        }
        return w
    }
}

// MARK: - SolidTextView
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
        let origin = NSPoint(x: textContainerInset.width, y: textContainerInset.height)
        let glyphRange = lm.glyphRange(forBoundingRect: dirtyRect, in: tc)
        lm.drawBackground(forGlyphRange: glyphRange, at: origin)
        lm.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }
    
    private func drawCurrentLineHighlight() {
        guard let lm = layoutManager else { return }
        let s = string as NSString
        let len = s.length
        if len == 0 {
            let font = font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let lineHeight = lm.defaultLineHeight(for: font)
            let r = NSRect(x: 0, y: textContainerInset.height, width: bounds.width, height: lineHeight)
            currentLineColor.setFill(); r.fill(); return
        }
        
        let sel = selectedRange()
        let lineRect: NSRect
        
        if sel.location == len && lm.extraLineFragmentRect.height > 0 {
            lineRect = lm.extraLineFragmentRect
        } else {
            let safeChar = min(sel.location, len - 1)
            let glyphIndex = lm.glyphIndexForCharacter(at: safeChar)
            var effectiveRange = NSRange()
            lineRect = lm.lineFragmentRect(forGlyphAt: glyphIndex,
                                           effectiveRange: &effectiveRange,
                                           withoutAdditionalLayout: true)
        }
        
        let highlightWidth = max(bounds.width, enclosingScrollView?.contentSize.width ?? bounds.width)
        let highlightRect = NSRect(x: 0,
                                   y: lineRect.minY + textContainerInset.height,
                                   width: highlightWidth,
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
