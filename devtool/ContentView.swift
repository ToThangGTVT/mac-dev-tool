import SwiftUI
import AppKit


struct ContentView: View {
    @State private var selection: SidebarItem? = .editor

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
                case .editor:   NotePadEditor()
                case .base64:   Base64ToolView()
                case .hash:     HashToolView()
                case .rsaHash:  RSAToolView()
                case .textCase: TextCaseToolView()
                case .regex:    RegexTesterToolView()
                case .color:    ColorPickerToolView()
                case .settings: SettingsView()
                case .none:
                    Text("Chọn một mục trong sidebar")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(VibrancyKiller())
        }
        .frame(minWidth: 700, minHeight: 450)
    }
}
