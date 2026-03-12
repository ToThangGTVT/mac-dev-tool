import SwiftUI
import AppKit

// MARK: - VibrancyKiller
// NSViewRepresentable có kích thước 0x0, chỉ để leo lên view hierarchy
// và tắt NSVisualEffectView của NavigationSplitView detail pane

struct VibrancyKiller: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            killVibrancy(in: v)
        }
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            killVibrancy(in: nsView)
        }
    }

    private func killVibrancy(in view: NSView) {
        var current: NSView? = view
        while let v = current {
            if let effect = v as? NSVisualEffectView {
                effect.material     = .windowBackground
                effect.blendingMode = .withinWindow
                effect.state        = .inactive
                // Set appearance cứng — không cho inherit dark/light vibrancy
                effect.appearance   = NSAppearance(named: .aqua)
                // Layer solid background đè lên
                effect.wantsLayer   = true
                effect.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
            current = v.superview
        }
    }
}
