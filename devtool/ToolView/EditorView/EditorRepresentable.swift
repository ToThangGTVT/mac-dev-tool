//
//  EditorRepresentable.swift
//  devtool
//

import SwiftUI
import AppKit

struct EditorRepresentable: NSViewRepresentable {

    @Binding var text:            String
    @Binding var fontSize:        CGFloat
    @Binding var autosaveEnabled: Bool
    @Binding var fileURL:         URL?
    @Binding var savingState:     NotePadEditor.SavingState
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
        tv.minSize                             = .zero
        tv.maxSize                             = NSSize(width: 1e7, height: 1e7)
        tv.isVerticallyResizable               = true
        tv.isHorizontallyResizable             = false
        tv.autoresizingMask                    = [.width]
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
        tv.needsDisplay    = true
        ruler.needsDisplay = true
    }

    // MARK: - Coordinator
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
                print("SAVED \(url)")
            } catch {
                parent.lastError = "Autosave: \(error.localizedDescription)"
                parent.savingState = .error
                print("ERROR SAVE!!!")
            }
        }
    }
}
