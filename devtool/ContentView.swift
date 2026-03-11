import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Trang chủ"
    case profile = "Hồ sơ"
    case settings = "Cài đặt"
    case base64 = "Base64"
    case hash = "Hash"
    case rsaHash = "RSA Hash"
    case textCase = "Text Case"
    case regex = "Regex Tester"
    case color = "Color Picker"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home:
            return "house"
        case .profile:
            return "person.crop.circle"
        case .settings:
            return "gearshape"
        case .base64:
            return "doc.text"
        case .hash:
            return "number"
        case .rsaHash:
            return "key"
        case .textCase:
            return "textformat"
        case .regex:
            return "magnifyingglass"
        case .color:
            return "paintpalette"
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
                case .home:
                    HomeView()
                case .profile:
                    ProfileView()
                case .settings:
                    SettingsView()
                case .base64:
                    Base64ToolView()
                case .hash:
                    HashToolView()
                case .rsaHash:
                    RSAToolView()
                case .textCase:
                    TextCaseToolView()
                case .regex:
                    RegexTesterToolView()
                case .color:
                    ColorPickerToolView()
                case .none:
                    Text("Chọn một mục trong sidebar")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 450)
    }
}
