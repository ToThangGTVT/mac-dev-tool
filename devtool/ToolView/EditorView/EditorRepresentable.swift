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
        let tc = NSTextContainer(size: NSSize(width: isTextWrapped ? 600 : 1e7, height: 1e7))
        tc.widthTracksTextView = isTextWrapped
        tc.lineFragmentPadding = 6
        lm.addTextContainer(tc)
        storage.addLayoutManager(lm)
        
        let textView = SolidTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400),
                                     textContainer: tc)
        textView.minSize = .zero
        textView.maxSize  = NSSize(width: 1e7, height: 1e7)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !isTextWrapped
        textView.autoresizingMask  = isTextWrapped ? [.width] : [.height]
        textView.isRichText  = false
        textView.allowsUndo  = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let fgColor = NSColor.labelColor
        let bgColor = NSColor.textBackgroundColor
        
        textView.font  = font
        textView.drawsBackground = true
        textView.backgroundColor = bgColor
        textView.textColor = fgColor
        textView.insertionPointColor = fgColor
        textView.selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor]
        textView.typingAttributes = [.font: font, .foregroundColor: fgColor]
        
        storage.setAttributedString(NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: fgColor]
        ))
        
        let sv = SolidScrollView()
        sv.borderType = .noBorder
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = !isTextWrapped
        sv.autohidesScrollers = true
        sv.drawsBackground = true
        sv.backgroundColor = bgColor
        sv.wantsLayer = true
        sv.layer?.masksToBounds = true
        
        let clip = FlippedClipView()
        clip.drawsBackground = true
        clip.backgroundColor = bgColor
        sv.contentView = clip
        sv.documentView = textView
        
        let ruler = LineNumberRulerView(textView: textView)
        sv.hasVerticalRuler = true
        sv.rulersVisible = true
        sv.verticalRulerView = ruler
        
        sv.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textChanged(_:)),
            name: NSText.didChangeNotification, object: textView)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrolled(_:)),
            name: NSView.boundsDidChangeNotification, object: sv.contentView)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: NSTextView.didChangeSelectionNotification, object: textView)
        
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
        guard let tv = context.coordinator.tv,
              let ruler = context.coordinator.ruler,
              let lm = context.coordinator.lm,
              let tc = context.coordinator.tc else { return }
        
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
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
        
        if isTextWrapped {
            let w = max(sv.contentSize.width - 2, 100)
            if abs(tc.containerSize.width - w) > 4 {
                tc.containerSize = NSSize(width: w, height: 1e7)
                lm.ensureLayout(for: tc); tv.sizeToFit()
            }
            tc.widthTracksTextView = true
            tv.isHorizontallyResizable = false
            tv.autoresizingMask = [.width]
        } else {
            if tc.containerSize.width != 1e7 {
                tc.containerSize = NSSize(width: 1e7, height: 1e7)
            }
            tc.widthTracksTextView = false
            tv.isHorizontallyResizable = true
            tv.autoresizingMask = [.height]
            lm.ensureLayout(for: tc); tv.sizeToFit()
        }
        
        if sv.hasHorizontalScroller != !isTextWrapped {
            sv.hasHorizontalScroller = !isTextWrapped
        }
        
        EditorScrollProxy.shared.register(sv, for: tabID)
        context.coordinator.parent = self
        tv.needsDisplay = true
        ruler.needsDisplay = true
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
            ruler?.invalidateLineCache(); ruler?.needsDisplay = true
            scheduleAutosave()
        }
        
        @objc func scrolled(_ n: Notification) { ruler?.needsDisplay = true }
        
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
