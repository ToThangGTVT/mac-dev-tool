import Foundation

enum TextEncoding: String, CaseIterable, Identifiable {
    case utf8 = "UTF-8"
    case ascii = "ASCII"
    case utf16 = "UTF-16"
    
    var id: String { rawValue }
    
    var nsEncoding: String.Encoding {
        switch self {
        case .utf8:  return .utf8
        case .ascii: return .ascii
        case .utf16: return .utf16LittleEndian
        }
    }
}
