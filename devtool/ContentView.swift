import SwiftUI
import AppKit

enum SidebarItem: String, CaseIterable, Identifiable {
    case home     = "Trang chủ"
    case profile  = "Hồ sơ"
    case settings = "Cài đặt"
    case base64   = "Base64"
    case hash     = "Hash"
    case rsaHash  = "RSA Hash"
    case textCase = "Text Case"
    case regex    = "Regex Tester"
    case color    = "Color Picker"
    case editor   = "Notepad"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home:     return "house"
        case .profile:  return "person.crop.circle"
        case .settings: return "gearshape"
        case .base64:   return "doc.text"
        case .hash:     return "number"
        case .rsaHash:  return "key"
        case .textCase: return "textformat"
        case .regex:    return "magnifyingglass"
        case .color:    return "paintpalette"
        case .editor:   return "note.text"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .home

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("Menu")
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selection {
                case .home:     HomeView()
                case .profile:  ProfileView()
                case .settings: SettingsView()
                case .base64:   Base64ToolView()
                case .hash:     HashToolView()
                case .rsaHash:  RSAToolView()
                case .textCase: TextCaseToolView()
                case .regex:    RegexTesterToolView()
                case .color:    ColorPickerToolView()
                case .editor:   MiniMapEditorView()
                case .none:
                    Text("Chọn một mục trong sidebar")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // ✅ Fix vibrancy: khi chuyển sang editor, disable NSVisualEffectView
            .background(VibrancyKiller())
        }
        .frame(minWidth: 700, minHeight: 450)
    }
}

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
