//
// EditorRepresentable.swift
// devtool
//

import SwiftUI
import AppKit

struct EditorRepresentable: NSViewRepresentable {
    
    @Binding var text: String
    @Binding var fontSize: CGFloat
    @Binding var autosaveEnabled: Bool
    @Binding var fileURL: URL?
    @Binding var savingState: NotePadEditor.SavingState
    @Binding var lastError: String?
    @Binding var isTextWrapped: Bool
    let tabID: UUID
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let lm = NSLayoutManager()
        let tc = NSTextContainer(size: NSSize(width: isTextWrapped ? 600 : CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        tc.widthTracksTextView = isTextWrapped
        tc.lineFragmentPadding = 6
        lm.addTextContainer(tc)
        storage.addLayoutManager(lm)
        
        let textView = setupTextView(with: tc, font: defaultFont, textColor: NSColor.labelColor, bgColor: NSColor.textBackgroundColor)
        storage.setAttributedString(NSAttributedString(string: text, attributes: [.font: defaultFont, .foregroundColor: NSColor.labelColor]))
        
        let sv = setupScrollView(with: textView, bgColor: NSColor.textBackgroundColor)
        let ruler = LineNumberRulerView(textView: textView)
        sv.verticalRulerView = ruler
        
        setupObservers(context: context, textView: textView, scrollView: sv)
        
        context.coordinator.tv = textView
        context.coordinator.sv = sv
        context.coordinator.ruler = ruler
        context.coordinator.tc = tc
        context.coordinator.lm = lm
        context.coordinator.parent = self
        
        EditorScrollProxy.shared.register(sv, for: tabID)
        
        DispatchQueue.main.async { [weak textView, weak sv, weak ruler] in
            guard let tv = textView, let sv = sv else { return }
            lm.ensureLayout(for: tc)
            tv.sizeToFit()
            if let docView = sv.documentView { docView.scroll(NSPoint(x: 0, y: 0)) }
            sv.reflectScrolledClipView(sv.contentView)
            
            DispatchQueue.main.async {
                tv.scrollRangeToVisible(NSRange(location: 0, length: 0))
                sv.contentView.bounds.origin = .zero
                sv.reflectScrolledClipView(sv.contentView)
            }
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
        guard let tv = context.coordinator.tv,
              let ruler = context.coordinator.ruler,
              let lm = context.coordinator.lm,
              let tc = context.coordinator.tc else { return }
        
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let fgColor = NSColor.labelColor
        
        ruler.invalidateLineCache()
        ruler.refreshRuleThickness()
        sv.tile()
        let contentWidth = (sv as? SolidScrollView)?.adjustedContentWidth ?? sv.contentSize.width
        
        if sv.hasHorizontalScroller != !isTextWrapped {
            sv.hasHorizontalScroller = !isTextWrapped
            sv.tile()
        }
        
        if isTextWrapped {
            if tc.containerSize.width != contentWidth {
                tc.containerSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
            }
            tv.isHorizontallyResizable = false
            tv.autoresizingMask = []
            if tv.frame.size.width != contentWidth {
                tv.frame.size.width = contentWidth
            }
            if tv.frame.origin != .zero {
                tv.frame.origin = .zero
            }
            tv.maxSize = NSSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
            tv.minSize = NSSize(width: 0, height: 0)
            tc.widthTracksTextView = true
        } else {
            if tc.containerSize.width != CGFloat.greatestFiniteMagnitude {
                tc.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            }
            tv.isHorizontallyResizable = true
            tv.autoresizingMask = []
            if tv.frame.origin != .zero {
                tv.frame.origin = .zero
            }
            tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            tv.minSize = NSSize(width: contentWidth, height: sv.contentSize.height)
            tc.widthTracksTextView = false
        }
        
        if tv.string != text {
            tv.textStorage?.setAttributedString(NSAttributedString(
                string: text, attributes: [.font: font, .foregroundColor: fgColor]))
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
        }
        
        lm.ensureLayout(for: tc)
        tv.sizeToFit()
        ruler.needsDisplay = true
        sv.reflectScrolledClipView(sv.contentView)
        
        EditorScrollProxy.shared.register(sv, for: tabID)
        context.coordinator.parent = self
        tv.needsDisplay = true
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject {
        var parent: EditorRepresentable
        weak var tv: NSTextView?
        weak var sv: NSScrollView?
        weak var ruler: LineNumberRulerView?
        var tc: NSTextContainer?
        var lm: NSLayoutManager?
        private var debounce: DispatchWorkItem?
        
        init(_ p: EditorRepresentable) { parent = p }
        
        @objc func textChanged(_ n: Notification) {
            guard let tv = tv else { return }
            if parent.text != tv.string { parent.text = tv.string }
            ruler?.invalidateLineCache()
            ruler?.refreshRuleThickness()
            ruler?.needsDisplay = true
            scheduleAutosave()
        }
        
        @objc func scrolled(_ n: Notification) {
            ruler?.needsDisplay = true
            guard !parent.isTextWrapped, let sv = sv, let tv = tv else { return }
            let cw = (sv as? SolidScrollView)?.adjustedContentWidth ?? sv.contentSize.width
            let newMinSize = NSSize(width: cw, height: sv.contentSize.height)
            if tv.minSize != newMinSize {
                tv.minSize = newMinSize
            }
        }
        
        @objc func selectionChanged(_ n: Notification) { ruler?.needsDisplay = true }
        
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
                print("SAVED \(url)")
            } catch {
                parent.lastError = "Autosave: \(error.localizedDescription)"
                parent.savingState = .error
                print("ERROR SAVE!!!")
            }
        }
    }
}

// MARK: - Setup Helpers
private extension EditorRepresentable {
    
    var defaultFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
    
    func setupTextView(with tc: NSTextContainer, font: NSFont, textColor: NSColor, bgColor: NSColor) -> SolidTextView {
        let textView = SolidTextView(frame: NSRect(x: 0, y: 0, width: isTextWrapped ? 600 : CGFloat.greatestFiniteMagnitude, height: 400),
                                     textContainer: tc)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !isTextWrapped
        textView.autoresizingMask = []
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        
        textView.font = font
        textView.drawsBackground = true
        textView.backgroundColor = bgColor
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]
        textView.typingAttributes = [.font: font, .foregroundColor: textColor]
        
        return textView
    }
    
    func setupScrollView(with textView: NSTextView, bgColor: NSColor) -> SolidScrollView {
        let sv = SolidScrollView()
        sv.borderType = .noBorder
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = !isTextWrapped
        sv.autohidesScrollers = true
        sv.drawsBackground = true
        sv.backgroundColor = bgColor
        sv.wantsLayer = true
        sv.layer?.masksToBounds = true
        sv.documentView = textView
        
        sv.hasVerticalRuler = true
        sv.rulersVisible = true
        sv.contentView.postsBoundsChangedNotifications = true
        
        return sv
    }
    
    func setupObservers(context: Context, textView: NSTextView, scrollView: NSScrollView) {
        let nc = NotificationCenter.default
        nc.addObserver(context.coordinator, selector: #selector(Coordinator.textChanged(_:)),
                       name: NSText.didChangeNotification, object: textView)
        nc.addObserver(context.coordinator, selector: #selector(Coordinator.scrolled(_:)),
                       name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        nc.addObserver(context.coordinator, selector: #selector(Coordinator.selectionChanged(_:)),
                       name: NSTextView.didChangeSelectionNotification, object: textView)
    }
}
