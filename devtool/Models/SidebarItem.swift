import Foundation

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
