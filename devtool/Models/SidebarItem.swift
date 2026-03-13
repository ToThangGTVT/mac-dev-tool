import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case editor = "Notepad"
    case base64 = "Basic Hash"
    case rsaHash = "RSA Hash"
    case textCase = "Text Case"
    case regex = "Regex Tester"
    case color = "Color Picker"
    case settings = "Cài đặt"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .settings: return "gearshape"
        case .base64: return "doc.text"
        case .rsaHash: return "key"
        case .textCase: return "textformat"
        case .regex: return "magnifyingglass"
        case .color: return "paintpalette"
        case .editor: return "note.text"
        }
    }
}
