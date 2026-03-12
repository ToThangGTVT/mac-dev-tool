//
//  LineNumberRulerView.swift
//  devtool
//

import AppKit

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

        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        // Tính thickness trước để layout ổn định
        if lineStarts.isEmpty { invalidateLineCache() }
        let digits = String(max(1, lineStarts.count)).count
        let minThickness: CGFloat = 40
        let needed = max(minThickness, CGFloat(8 + digits * 8 + 12))
        
        if abs(ruleThickness - needed) > 0.5 {
            ruleThickness = needed
            return // AppKit sẽ gọi lại draw sau khi thickness thay đổi
        }

        let clipBounds  = sv.contentView.bounds
        let visibleInTV = sv.contentView.convert(clipBounds, to: tv)
        let gr          = lm.glyphRange(forBoundingRect: visibleInTV, in: tc)
        let fSize       = max((tv.font?.pointSize ?? 12) - 2, 9)

        // Tính selection range
        let selectedRange = tv.selectedRange()
        let startLine = lineIndex(for: selectedRange.location) + 1
        let endLine   = lineIndex(for: NSMaxRange(selectedRange) > selectedRange.location ? NSMaxRange(selectedRange) - 1 : selectedRange.location) + 1
        let selectedLineRange = startLine...endLine

        var idx = gr.location
        let end = NSMaxRange(gr)
        guard end > idx || tv.string.isEmpty else { drawSeparator(); return }

        var lastLineDrawn = -1

        while idx < end {
            var lr = NSRange()
            let fr = lm.lineFragmentRect(forGlyphAt: idx, effectiveRange: &lr,
                                         withoutAdditionalLayout: true)
            guard lr.length > 0 else { break }

            let cr        = lm.characterRange(forGlyphRange: lr, actualGlyphRange: nil)
            let ln        = lineIndex(for: cr.location) + 1
            let frInRuler = tv.convert(fr, to: self)
            let isSelected = selectedLineRange.contains(ln)

            if isSelected {
                let hr = NSRect(x: 0, y: frInRuler.minY,
                                width: bounds.width - 1, height: frInRuler.height)
                NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
                hr.fill()
            }

            if ln != lastLineDrawn {
                let lineColor: NSColor = isSelected ? .labelColor : .secondaryLabelColor
                let lineFont = isSelected
                    ? NSFont.monospacedDigitSystemFont(ofSize: fSize, weight: .semibold)
                    : NSFont.monospacedDigitSystemFont(ofSize: fSize, weight: .regular)
                let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: lineColor, .font: lineFont]
                let s  = "\(ln)" as NSString
                let sz = s.size(withAttributes: attrs)
                s.draw(at: NSPoint(x: ruleThickness - 6 - sz.width,
                                   y: frInRuler.minY + (frInRuler.height - sz.height) / 2),
                       withAttributes: attrs)
                lastLineDrawn = ln
            }

            let next = NSMaxRange(lr)
            if next <= idx { break }
            idx = next
        }

        // Vẽ extra line fragment (dòng trống cuối cùng)
        let extraRect = lm.extraLineFragmentRect
        if extraRect.height > 0 {
            let frInRuler = tv.convert(extraRect, to: self)
            if rect.intersects(frInRuler) {
                let ln = lineStarts.count
                let isSelected = selectedLineRange.contains(ln)
                
                if isSelected {
                    let hr = NSRect(x: 0, y: frInRuler.minY,
                                    width: bounds.width - 1, height: frInRuler.height)
                    NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
                    hr.fill()
                }
                
                if ln != lastLineDrawn {
                    let lineColor: NSColor = isSelected ? .labelColor : .secondaryLabelColor
                    let lineFont = isSelected
                        ? NSFont.monospacedDigitSystemFont(ofSize: fSize, weight: .semibold)
                        : NSFont.monospacedDigitSystemFont(ofSize: fSize, weight: .regular)
                    let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: lineColor, .font: lineFont]
                    let s  = "\(ln)" as NSString
                    let sz = s.size(withAttributes: attrs)
                    s.draw(at: NSPoint(x: ruleThickness - 6 - sz.width,
                                       y: frInRuler.minY + (frInRuler.height - sz.height) / 2),
                           withAttributes: attrs)
                }
            }
        }
        drawSeparator()
    }

    private func drawSeparator() {
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
            let range = s.lineRange(for: NSRange(location: pos, length: 0))
            let nextPos = NSMaxRange(range)
            if nextPos < s.length { a.append(nextPos) }
            if nextPos <= pos { break }
            pos = nextPos
        }
        // Nếu string kết thúc bằng \n, ta có thêm một dòng trống nữa ở cuối
        if s.length > 0 && s.substring(from: s.length - 1) == "\n" {
            a.append(s.length)
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
